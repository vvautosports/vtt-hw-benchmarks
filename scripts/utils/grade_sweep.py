#!/usr/bin/env python3
"""Annotate sweep JSONL records with programmatic quality metrics.

Usage:
  py grade_sweep.py <run_dir> <name> [--layout phase|<field>] [--check]

Reads <run_dir>/<name>.jsonl, merges a `quality` object into each record, and
rewrites the JSONL in place. --check computes everything but writes nothing and
exits non-zero if any record's quality would change: use it to prove a change to
this script did not alter the grading of an already-committed run.

Layouts
-------
--layout names the subdirectory that transcripts are grouped under:

phase (default)  <run_dir>/outputs/<name>/<task>--<profile>--<effort>.txt
                 One record per (task, profile, effort) -- the param-sweep shape,
                 where the axes are sampling profile and reasoning effort.
<field>          <run_dir>/outputs/<record[field]>/<task>--<profile>--<effort>.txt
                 Any other value is read as a RECORD FIELD NAME holding the
                 subdirectory. `model` for a roster run (axis = model, config
                 fixed); `config` for a server-config matrix such as a
                 speculation retest. Trampling is detected per (field, task).

Transcript trampling (non-phase layouts)
----------------------------------------
A run that executes the same (subdir, task) pair more than once -- e.g. a
pre-reboot and a post-reboot pass over the same roster -- overwrites the transcript
each time, so only the LAST pass that actually produced output survives on disk.
Grading every record against that single file would silently attribute one pass's
quality to another. So only the last non-error record of each (subdir, task) group
is graded; earlier ones get graded=False, reason="transcript_trampled". Their speed
numbers remain valid -- only their quality is unrecoverable.

Graders (static, deterministic -- no LLM judge):
  reasoning: last 'ANSWER: <n>' in content == 5
  code:      >= 5 doctest examples ('>>>') AND raises/mentions ValueError
  summarize: exactly 5 bullets before the TL;DR line, TL;DR present

Tool-call family. Tier 1 (saturated): tc_single, tc_distractor, tc_refusal, tc_chain,
tc_longchain. Tier 2 (discriminative): tc_parallel, tc_nested, tc_union, tc_distractor_p1,
tc_distractor_p3, tc_ambiguous, tc_coercion. These read the `=== TOOLCALLS ===` and
`=== META ===` sections that sweep_toolcall.py writes, and check them against the expectations
in <run_dir>/toolcall_cases.json (whichever cases file the driver copied in). That file is
copied into the run dir by the driver, so expectations travel WITH the run: editing the repo's
case definitions can never silently re-grade an already-committed run. Cells whose prompt_tokens
exceed the case ceiling are flagged tools_injection_suspect -- the server-side built-ins came
back on -- but are not auto-failed, since a real pass is still a real pass.

Two expectation forms beyond the single-call checks: expect.calls is a list of {name, args_match}
specs matched order-insensitively against the turn's calls (parallel cases), and any args_match
pattern may be a LIST of patterns that must all match one arg -- used to assert several substrings
inside one nested object/array argument.

Receipt family (vision track): rcpt01_diner .. rcpt05_parking. CONTENT is the schema-locked
JSON the server returned for one battery receipt image; it is graded field-by-field against
<run_dir>/receipt_truth.json (written into the run dir by scripts/sweeps/receipt_battery_gen.py,
so truth travels WITH the run like toolcall_cases.json does). Grading logic is a port of
expense-agent scripts/model_compare.py grade() -- the grader behind the banked
2026-08-27-receipt-battery-g1a run -- kept behavior-identical so future vtt vision runs stay
comparable to it: merchant fuzzy-match >= 0.7, date exact, amounts +/- 0.01,
category/card_last4/qualifier exact. Self-test (no inference host, no Pillow):
scripts/testing/test_grade_receipt.py.

Grading reads only the `=== CONTENT ===` section -- content-channel grading, which
is what catches a model writing its real answer into the reasoning stream and
leaving a summary in content. Execution-based grading (actually running generated
code) and judge-scored fidelity are workstream F -- see
docs/reference/UNSLOTH-DIRECTION.md.
"""
import json
import os
import re
import sys
from difflib import SequenceMatcher

TEXT_TASKS = ("reasoning", "code", "summarize")
TOOLCALL_TASKS = (
    # Tier 1 (saturated 90/90 -- a floor, not a ranking)
    "tc_single", "tc_distractor", "tc_refusal", "tc_chain", "tc_longchain",
    # Tier 2 -- discriminative pressure: parallel calls, nested/union schemas,
    # distractor-position rotation, tool ambiguity, argument coercion.
    "tc_parallel", "tc_nested", "tc_union",
    "tc_distractor_p1", "tc_distractor_p3", "tc_ambiguous", "tc_coercion",
)
RECEIPT_TASKS = (
    # Vision track -- one task per battery receipt image (31 gradeable fields total).
    "rcpt01_diner", "rcpt02_uber", "rcpt03_hotel", "rcpt04_flight", "rcpt05_parking",
)
TASKS = TEXT_TASKS + TOOLCALL_TASKS + RECEIPT_TASKS

SECTION_RE = re.compile(r"(?m)^=== [A-Z]+ ===\n")


def section_of(path, marker):
    """Text of one `=== MARKER ===` section, up to the next section header or EOF.

    Text-battery transcripts have REASONING then CONTENT (last), so bounding at the next
    header leaves them byte-identical. Tool-call transcripts add TOOLCALLS and META after
    CONTENT, which is why the bound is needed at all.
    """
    if not os.path.exists(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(rf"=== {marker} ===\n", text)
    if not m:
        return None
    rest = text[m.end():]
    nxt = SECTION_RE.search(rest)
    return rest[:nxt.start()] if nxt else rest


def content_of(path):
    if not os.path.exists(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"=== CONTENT ===\n", text)
    if not m:
        return text
    rest = text[m.end():]
    nxt = SECTION_RE.search(rest)
    return rest[:nxt.start()] if nxt else rest


def _json_section(path, marker, default):
    raw = section_of(path, marker)
    if not raw:
        return default
    try:
        return json.loads(raw)
    except ValueError:
        return default


def _match_pattern(val, pat):
    """One arg value matches when str(val) satisfies the pattern -- or, when pat is a list,
    EVERY pattern in it. The list form lets a single nested arg (an object or array serialised
    to str) be asserted against several independent substrings, e.g. items=["AX-19", "BX-7"]."""
    if val is None:
        return False
    pats = pat if isinstance(pat, list) else [pat]
    return all(re.search(p, str(val)) is not None for p in pats)


def _args_match(args, spec):
    """True when every (arg -> pattern) in spec matches. spec values may be str or [str]."""
    if not isinstance(args, dict):
        return False
    return all(_match_pattern(args.get(k), pat) for k, pat in spec.items())


def grade_toolcall(task, path, cases):
    """Deterministic tool-call grading against the run dir's toolcall_cases.json.

    Reads the structured `tool_calls` the server parsed, but the transcript also keeps the
    raw completion verbatim -- when a score falls far below a vendor's published BFCL-style
    claim, template/parser mismatch is the first suspect, not the model.
    """
    if not cases or task not in cases:
        return {"graded": False, "reason": "no_case_definition"}
    if not os.path.exists(path):
        return {"graded": False}
    exp = cases[task].get("expect", {})
    calls = _json_section(path, "TOOLCALLS", [])
    meta = _json_section(path, "META", {})
    content = content_of(path) or ""

    q = {
        "graded": True,
        "n_calls": len(calls),
        "chain_depth_reached": meta.get("chain_depth_reached"),
        "finish_reason": meta.get("finish_reason"),
        "raw_toolcall_text": bool(meta.get("raw_toolcall_text_detected")),
        "args_parse_failures": meta.get("args_parse_failures"),
        "prompt_tokens": meta.get("prompt_tokens"),
    }
    # Contamination check. The ceiling is PER CASE: prompt size scales with how many tool
    # schemas the case offers (5 schemas cost ~775 tokens where 1 costs ~340), so a single
    # global threshold flags the distractor case on every clean run. Flagged, not
    # auto-failed -- a real pass is still a real pass.
    pt = meta.get("prompt_tokens")
    ceiling = exp.get("max_prompt_tokens")
    q["tools_injection_suspect"] = bool(pt and ceiling and pt > ceiling)

    checks = []
    if meta.get("error"):
        q["correct"] = False
        q["reason"] = "request_error"
        return q

    if "n_calls" in exp:
        checks.append(len(calls) == exp["n_calls"])
    if "min_calls" in exp:
        checks.append(len(calls) >= exp["min_calls"])
    if "name" in exp and calls:
        checks.append(calls[0].get("name") == exp["name"])
    elif "name" in exp:
        checks.append(False)
    if "args_match" in exp:
        ok = _args_match((calls[0].get("arguments") if calls else None) or {}, exp["args_match"])
        q["args_ok"] = ok
        checks.append(ok)
    if "calls" in exp:
        # Parallel/multi-call turn: each expected spec must match a DISTINCT actual call,
        # order-insensitive. A model that emits two of the three, or repeats one, fails.
        remaining = list(range(len(calls)))
        matched = 0
        for spec in exp["calls"]:
            hit = next(
                (idx for idx in remaining
                 if (not spec.get("name") or calls[idx].get("name") == spec["name"])
                 and _args_match(calls[idx].get("arguments") or {}, spec.get("args_match", {}))),
                None)
            if hit is not None:
                remaining.remove(hit)
                matched += 1
        q["calls_matched"] = matched
        checks.append(matched == len(exp["calls"]))
    if "content_match" in exp:
        hit = re.search(exp["content_match"], content) is not None
        q["content_ok"] = hit
        checks.append(hit)
    if "pass_depth" in exp:
        depth = meta.get("chain_depth_reached") or 0
        q["pass_depth"] = exp["pass_depth"]
        checks.append(depth >= exp["pass_depth"])
    if "completion_match" in exp:
        # Recorded, NOT gated. Surviving the chain (#19513) and finishing the errand are
        # different claims; the regression bar is depth alone.
        q["completed"] = re.search(exp["completion_match"], content) is not None
    if calls:
        checks.append(not meta.get("args_parse_failures"))

    q["correct"] = bool(checks) and all(checks)
    return q


def grade_receipt(task, content, truth_all):
    """Deterministic receipt-extraction grading against the run dir's receipt_truth.json.

    Behavior-identical port of expense-agent scripts/model_compare.py grade(). CONTENT is
    the schema-locked JSON extraction for one receipt; a response that is not parseable JSON
    grades 0/N rather than graded=False -- an empty or malformed answer is a model failure
    (Muse-Glimmer's round-1 mode), not a harness gap.
    """
    if not truth_all or task not in truth_all:
        return {"graded": False, "reason": "no_truth_definition"}
    if content is None:
        return {"graded": False}
    truth = truth_all[task]
    fields = ["merchant", "date", "total", "category"] + [
        k for k in ("tax", "tip", "card_last4", "qualifier") if k in truth]
    q = {"graded": True, "fields_total": len(fields)}

    text = content.strip()
    m = re.search(r"\{.*\}", text, re.S)  # tolerate fences/prose around the JSON
    try:
        rec = json.loads(m.group(0) if m else text)
    except ValueError:
        rec = None
    q["json_ok"] = isinstance(rec, dict)
    if not q["json_ok"]:
        q.update(checks={}, fields_ok=0, correct=False)
        return q

    checks = {}
    mv = (rec.get("merchant") or "").lower()
    tv = truth["merchant"].lower()
    checks["merchant"] = bool(mv) and (
        tv in mv or mv in tv or SequenceMatcher(None, mv, tv).ratio() >= 0.7)
    checks["date"] = rec.get("date") == truth["date"]
    for amt in ("total", "tax", "tip"):
        if amt in truth:
            try:
                checks[amt] = abs(float(rec.get(amt) or 0) - truth[amt]) <= 0.01
            except (TypeError, ValueError):
                checks[amt] = False
    checks["category"] = rec.get("category") == truth["category"]
    if "card_last4" in truth:
        checks["card_last4"] = (rec.get("card_last4") or "") == truth["card_last4"]
    if "qualifier" in truth:
        checks["qualifier"] = rec.get("qualifier") == truth["qualifier"]

    q["checks"] = checks
    q["fields_ok"] = sum(checks.values())
    q["correct"] = q["fields_ok"] == q["fields_total"]
    return q


def grade(task, content, path=None, cases=None, receipt_truth=None):
    if task in TOOLCALL_TASKS:
        return grade_toolcall(task, path, cases)
    if task in RECEIPT_TASKS:
        return grade_receipt(task, content, receipt_truth)
    if content is None:
        return {"graded": False}
    q = {"graded": True}
    if task == "reasoning":
        answers = re.findall(r"ANSWER:\s*(\d+)", content)
        q["answer"] = int(answers[-1]) if answers else None
        q["correct"] = q["answer"] == 5
    elif task == "code":
        q["doctests"] = content.count(">>>")
        q["mentions_valueerror"] = "ValueError" in content
        q["correct"] = q["doctests"] >= 5 and q["mentions_valueerror"]
    elif task == "summarize":
        tldr_at = re.search(r"(?im)^\**\s*TL;?DR", content)
        before = content[:tldr_at.start()] if tldr_at else content
        q["bullets"] = len(re.findall(r"(?m)^\s*[-*\u2022]\s+", before))
        q["has_tldr"] = bool(tldr_at)
        q["correct"] = q["bullets"] == 5 and q["has_tldr"]
    return q


def survivor_indexes(records, field):
    """Indexes whose transcript is the one still on disk: last non-error per key."""
    last = {}
    for i, r in enumerate(records):
        if r.get("task") in TASKS and not r.get("error"):
            last[(r.get(field), r.get("task"))] = i
    return set(last.values())


def main(argv):
    layout = "phase"
    check = False
    args = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--check":
            check = True
        elif a.startswith("--layout"):
            if "=" in a:
                layout = a.split("=", 1)[1]
            else:
                i += 1
                if i >= len(argv):
                    sys.exit("--layout needs a value")
                layout = argv[i]
        elif a.startswith("--"):
            sys.exit(f"unknown flag: {a}")
        else:
            args.append(a)
        i += 1
    if len(args) != 2:
        sys.exit(__doc__.strip())
    run_dir, name = args

    jsonl = os.path.join(run_dir, f"{name}.jsonl")
    records = [json.loads(line) for line in open(jsonl, encoding="utf-8")]

    # Tool-call expectations travel WITH the run, not with this script, so re-grading an
    # old run can never be silently changed by an edit to the current case definitions.
    cases = None
    cases_path = os.path.join(run_dir, "toolcall_cases.json")
    if os.path.exists(cases_path):
        cases = json.load(open(cases_path, encoding="utf-8")).get("cases")

    # Receipt truth travels with the run for the same reason (receipt_battery_gen.py writes it).
    receipt_truth = None
    truth_path = os.path.join(run_dir, "receipt_truth.json")
    if os.path.exists(truth_path):
        receipt_truth = json.load(open(truth_path, encoding="utf-8"))

    if layout == "phase":
        survivors = set(range(len(records)))
    else:
        missing = [i for i, r in enumerate(records)
                   if r.get("task") in TASKS and layout not in r]
        if missing:
            sys.exit(f"--layout {layout}: records {missing[:5]} have no '{layout}' field")
        survivors = survivor_indexes(records, layout)

    passed = total = trampled = suspect = 0
    changed = []
    for i, r in enumerate(records):
        task = r.get("task")
        if task not in TASKS or r.get("error"):
            continue
        if i not in survivors:
            q = {"graded": False, "reason": "transcript_trampled"}
            trampled += 1
        else:
            sub = name if layout == "phase" else r[layout]
            path = os.path.join(
                run_dir, "outputs", sub,
                f"{task}--{r['profile']}--{r['effort']}.txt")
            q = grade(task, content_of(path), path, cases, receipt_truth)
            if q.get("graded"):
                total += 1
                passed += bool(q.get("correct"))
                suspect += bool(q.get("tools_injection_suspect"))
        if check:
            if r.get("quality") != q:
                changed.append((i, r.get("quality"), q))
        else:
            r["quality"] = q

    if check:
        for i, old, new in changed:
            print(f"  record {i}: {old} -> {new}")
        print(f"{name}: {len(changed)} record(s) would change")
        return 1 if changed else 0

    with open(jsonl, "w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")
    extra = f", {trampled} trampled" if trampled else ""
    if suspect:
        extra += f", {suspect} TOOLS-INJECTION SUSPECT (prompt_tokens > 500)"
    print(f"{name}: graded {total} records, {passed} correct{extra}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
