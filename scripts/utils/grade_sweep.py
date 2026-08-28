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

Tool-call family (Track 1 Tier 1) -- tc_single, tc_distractor, tc_refusal, tc_chain,
tc_longchain. These read the `=== TOOLCALLS ===` and `=== META ===` sections that
sweep_toolcall.py writes, and check them against the expectations in
<run_dir>/toolcall_cases.json. That file is copied into the run dir by the driver, so
expectations travel WITH the run: editing the repo's case definitions can never silently
re-grade an already-committed run. Cells whose prompt_tokens exceed 500 are flagged
tools_injection_suspect -- the server-side built-ins came back on -- but are not
auto-failed, since a real pass is still a real pass.

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

TEXT_TASKS = ("reasoning", "code", "summarize")
TOOLCALL_TASKS = ("tc_single", "tc_distractor", "tc_refusal", "tc_chain", "tc_longchain")
TASKS = TEXT_TASKS + TOOLCALL_TASKS

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
        args = (calls[0].get("arguments") if calls else None) or {}
        ok = isinstance(args, dict)
        if ok:
            for k, pat in exp["args_match"].items():
                val = args.get(k)
                ok = ok and val is not None and re.search(pat, str(val)) is not None
        q["args_ok"] = ok
        checks.append(ok)
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


def grade(task, content, path=None, cases=None):
    if task in TOOLCALL_TASKS:
        return grade_toolcall(task, path, cases)
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
            q = grade(task, content_of(path), path, cases)
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
