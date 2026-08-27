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

TASKS = ("reasoning", "code", "summarize")


def content_of(path):
    if not os.path.exists(path):
        return None
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.search(r"=== CONTENT ===\n", text)
    return text[m.end():] if m else text


def grade(task, content):
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

    if layout == "phase":
        survivors = set(range(len(records)))
    else:
        missing = [i for i, r in enumerate(records)
                   if r.get("task") in TASKS and layout not in r]
        if missing:
            sys.exit(f"--layout {layout}: records {missing[:5]} have no '{layout}' field")
        survivors = survivor_indexes(records, layout)

    passed = total = trampled = 0
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
            q = grade(task, content_of(path))
            if q.get("graded"):
                total += 1
                passed += bool(q.get("correct"))
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
    print(f"{name}: graded {total} records, {passed} correct{extra}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
