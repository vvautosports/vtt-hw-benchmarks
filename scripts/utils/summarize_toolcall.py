#!/usr/bin/env python3
"""Render a graded tool-call run as a rung x case matrix.

Usage: python3 summarize_toolcall.py <run_dir> [--name results] [--markdown]

Run grade_sweep.py first -- this reads the `quality` object, it does not compute it.
Exists so the numbers quoted in a manifest or a PR comment are reproducible from the
committed run rather than retyped by hand.

Columns are the five Tier 1 cases. Rows are cfg (<model>__<rung>). Annotations:
  d<n>   chain depth reached (tc_longchain only; pass bar is 15)
  *      model emitted text-form <tool_call> that nothing promoted to structured
  !      prompt_tokens above the case ceiling -- server-side tool injection suspected
"""
import json
import os
import sys

CASES = ["tc_single", "tc_distractor", "tc_refusal", "tc_chain", "tc_longchain"]


def main(argv):
    name = "results"
    markdown = False
    args = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--name":
            i += 1
            name = argv[i]
        elif a == "--markdown":
            markdown = True
        elif a.startswith("--"):
            sys.exit(f"unknown flag: {a}")
        else:
            args.append(a)
        i += 1
    if len(args) != 1:
        sys.exit(__doc__.strip())
    run_dir = args[0]

    path = os.path.join(run_dir, f"{name}.jsonl")
    recs = [json.loads(line) for line in open(path, encoding="utf-8")]

    cfgs = []
    for r in recs:
        if r.get("cfg") and r["cfg"] not in cfgs:
            cfgs.append(r["cfg"])

    def cell(cfg, case):
        m = [r for r in recs if r.get("cfg") == cfg and r.get("task") == case]
        if not m:
            return "--"
        r = m[0]
        q = r.get("quality") or {}
        if r.get("loaded") is False:
            return "LOAD-FAIL"
        if not q.get("graded"):
            return "ungraded"
        out = "PASS" if q.get("correct") else "fail"
        if case == "tc_longchain":
            out += f"/d{r.get('chain_depth_reached')}"
        if r.get("raw_toolcall_text_detected"):
            out += "*"
        if q.get("tools_injection_suspect"):
            out += "!"
        return out

    rows = [(cfg, [cell(cfg, c) for c in CASES]) for cfg in cfgs]
    heads = [c[3:] for c in CASES]
    width = max([len(c) for c in cfgs] + [3])

    if markdown:
        print("| config | " + " | ".join(heads) + " |")
        print("|---" * (len(heads) + 1) + "|")
        for cfg, vals in rows:
            print(f"| `{cfg}` | " + " | ".join(vals) + " |")
    else:
        print(f"{'config':<{width}} " + " ".join(f"{h:>12}" for h in heads))
        for cfg, vals in rows:
            print(f"{cfg:<{width}} " + " ".join(f"{v:>12}" for v in vals))

    graded = [r for r in recs if (r.get("quality") or {}).get("graded")]
    passed = sum(1 for r in graded if r["quality"].get("correct"))
    print(f"\n{passed}/{len(graded)} cells pass across {len(cfgs)} configs.")

    # A rung axis that never separates anything is worth saying out loud rather than
    # letting a reader infer capability from it.
    by_model = {}
    for cfg in cfgs:
        model, _, rung = cfg.rpartition("__")
        by_model.setdefault(model, {})[rung] = tuple(cell(cfg, c) for c in CASES)
    split = [m for m, rungs in by_model.items() if len(set(rungs.values())) > 1]
    if split:
        print(f"Rung-sensitive models (results differ across raw/healed/full): {split}")
    else:
        print("No model differed across rungs -- expected when every model emits clean "
              "structured calls. Confirm the axis with probe_healing_axis.py before "
              "reading anything into that.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
