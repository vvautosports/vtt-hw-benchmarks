#!/usr/bin/env python3
"""Self-test for the #27 metadata surface of scripts/utils/log_sweep_to_mlflow.py.

Builds children from two committed ladder rundirs (text + toolraw) exactly the way
the shim does, then asserts the pieces that feed the MLflow UI panels that used to be
empty: per-child descriptions, the parent description, the per-cell results table and
the dataset inputs. No MLflow server, no pandas, no inference host -- the shim keeps
all of this dependency-free so --dry-run works anywhere PyYAML does.

Usage: python3 scripts/testing/test_log_sweep_table.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, "scripts", "utils"))

import log_sweep_to_mlflow as shim  # noqa: E402

LADDER = os.path.join(REPO, "results", "sweeps", "2026-09-07-ladder")
TEXT = os.path.join(LADDER, "2026-09-07-ladder-UD-Q4_K_XL-text")
TOOL = os.path.join(LADDER, "2026-09-07-ladder-UD-Q4_K_XL-toolraw")

FAKE_SHA = "0123456789abcdef0123456789abcdef01234567"


def build(rundir, issue=None):
    manifest, mjson = shim.load_manifest(rundir)
    records_path = shim.resolve_records(rundir, manifest, None)
    records = shim.read_records(records_path)
    family = shim.detect_family(manifest, mjson, rundir)
    spec = shim.load_spec(rundir, manifest, None)
    ctx = {"rundir": rundir, "run_id": os.path.basename(rundir), "manifest": manifest,
           "consts": manifest.get("request_constants") or {},
           "spec_idx": shim.index_spec(spec), "models_root": "/mnt/ai-models",
           "inv": shim.load_inventory(), "lane": "bespoke",
           "track": "text" if family == "text-sweeps" else "track1",
           "tier": shim.UNAVAILABLE, "grader_version": "test",
           "records_path": records_path, "git_commit": FAKE_SHA}
    children = [shim.build_child(r, ctx) for r in records]
    experiment = "hwbench/" + family
    return (family, children, shim.results_table(children),
            shim.dataset_inputs(ctx, family, children),
            shim.parent_note(ctx, children, family, experiment, issue))


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


def test_text():
    family, children, table, datasets, note = build(TEXT, issue=23)
    check(family == "text-sweeps", family)
    check(len(children) == 3, len(children))
    for c in children:
        n = c["tags"][shim.NOTE_TAG]
        check("UD-Q4_K_XL" in n and c["name"].split("/")[1] in n, n)
        check(("pass" in n) or ("FAIL" in n), "graded cells must say pass/FAIL: " + n)
        check(c["tags"]["mlflow.source.git.commit"] == FAKE_SHA, c["tags"])
        check(c["tags"]["mlflow.source.name"].endswith("UD-Q4_K_XL-text"), c["tags"])
    check(list(table)[:len(shim.TABLE_COLUMNS)] == list(shim.TABLE_COLUMNS), list(table))
    check(all(len(v) == 3 for v in table.values()), "ragged table")
    check(set(table["task"]) == {"reasoning", "code", "summarize"}, table["task"])
    check(table["correct"] == [1.0, 1.0, 0.0], table["correct"])
    check(any(k.startswith("q_") for k in table), "no q_* columns")
    check(len(datasets) == 1 and datasets[0]["name"] == "text-battery-v1", datasets)
    check(len(datasets[0]["rows"]) == 3
          and set(datasets[0]["rows"][0]) == {"task", "prompt"}, datasets[0])
    check("Graded: 2/3 pass" in note, note)
    check(shim.FORGEJO_ISSUES + "23" in note, note)
    check(FAKE_SHA[:12] in note, note)


def test_toolcall():
    family, children, table, datasets, note = build(TOOL)
    check(family == "toolcall", family)
    check(len(children) == 7, len(children))
    check(len(table["cfg"]) == 7, table["cfg"])
    check(len(datasets) == 1 and datasets[0]["name"].startswith("toolcall-cases-v"),
          datasets)
    rows = datasets[0]["rows"]
    check(len(rows) == 7 and {"case", "kind", "intent", "prompt", "n_tools", "expect"}
          <= set(rows[0]), rows[0])
    check(datasets[0]["source"].endswith("toolcall_cases.json"), datasets[0]["source"])
    check("Graded: 6/7 pass" in note, note)
    check("Tracking:" not in note, "no issue given -> no tracking line")


def test_experiment_notes():
    for fam in ("toolcall", "text-sweeps", "agent-battery", "serving-config"):
        n = shim.experiment_note(fam)
        check(n and "#27" in n and "EVIDENCE-LAKEHOUSE" in n, fam)
    check(shim.experiment_note("misc") is None, "misc has no canned note")


if __name__ == "__main__":
    for fn in (test_text, test_toolcall, test_experiment_notes):
        fn()
        print("ok  " + fn.__name__)
    print("ALL OK")
