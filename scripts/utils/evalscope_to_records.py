#!/usr/bin/env python3
"""Turn an EvalScope `evalscope eval` work-dir into hwbench community-lane records.

    evalscope_to_records.py <evalscope work-dir> <out rundir> [options]

This is the community-lane counterpart to `scripts/utils/log_sweep_to_mlflow.py`
(hwbench #15, docs/reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md §5-6, §9.6). It
never talks to the inference node and never re-grades anything -- it reads what
`evalscope eval --work-dir <dir>` already wrote to disk (one timestamped run
subdir per invocation, each with `configs/task_config.yaml` and
`reports/<model_id>/<dataset>.json`) and turns it into the same
task/case/model/tag/score/quality-shaped JSONL the bespoke sweep drivers write,
plus a manifest.yaml the MLflow shim can log with `--lane community`.

Layout this script expects (as written by evalscope >= 1.11):

    <work-dir>/<YYYYMMDD_HHMMSS>/configs/task_config.yaml
    <work-dir>/<YYYYMMDD_HHMMSS>/reports/<model_id>/<dataset>.json

Every timestamped subdir under <work-dir> is walked, so pointing this at the
root `eval/` directory picks up every dataset run into it (gsm8k, arc, ...)
even though each `evalscope eval` invocation makes its own timestamp dir.

One record per (dataset, subset) -- `is_aggregate` subsets (BFCL-style rollups)
are skipped so they don't double-count; a report with more than one metric gets
`::<metric>` appended to `case` to keep those distinct. `wall_s` is approximate:
the timestamp encoded in the run dir name (invocation start) subtracted from the
report JSON's own mtime (when that dataset's report was written) -- evalscope
does not persist a per-dataset wall-clock duration itself.

The handful of fields EvalScope's own config has no concept of -- this node,
this serving backend, this tracking issue -- are pilot-identity metadata, not
derived from the eval output. They default to this run's known values (2026-09-06
GLM-4.7-Flash pilot, hwbench #15) and can be overridden for a different run.
"""
import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, date

UNAVAILABLE = "unavailable"
RUN_DIR_RE = re.compile(r"^(\d{8})_(\d{6})$")

HERE = os.path.dirname(os.path.abspath(__file__))


def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    raise SystemExit(2)


def warn(msg):
    print("WARNING: " + msg, file=sys.stderr)


def load_yaml(path):
    try:
        import yaml
    except ImportError:
        die("PyYAML is required to read task_config.yaml and write manifest.yaml. "
            "Install it:  pip install pyyaml")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return yaml.safe_load(f) or {}
    except Exception as e:  # noqa: BLE001
        warn("could not parse " + path + ": " + repr(e))
        return {}


def dump_yaml(data, path):
    import yaml
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, default_flow_style=False,
                        allow_unicode=True)


def load_json(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return json.load(f)


# --------------------------------------------------------------------------- #
# discovery
# --------------------------------------------------------------------------- #
def find_run_dirs(work_dir):
    """Every immediate child of work_dir whose name matches evalscope's
    <YYYYMMDD_HHMMSS> timestamp pattern and holds a reports/ dir."""
    out = []
    if not os.path.isdir(work_dir):
        die("not a directory: " + work_dir)
    for name in sorted(os.listdir(work_dir)):
        p = os.path.join(work_dir, name)
        if not os.path.isdir(p):
            continue
        if os.path.isdir(os.path.join(p, "reports")):
            out.append((name, p))
    if not out:
        # fall back to treating work_dir itself as the single run dir (e.g. a
        # user pointed this at .../eval/20260907_022007 directly)
        if os.path.isdir(os.path.join(work_dir, "reports")):
            out.append((os.path.basename(work_dir.rstrip(os.sep)) or "run", work_dir))
    if not out:
        die("no evalscope run dirs (with a reports/ subdir) found under " + work_dir)
    return out


def run_start_ts(run_name, run_path):
    m = RUN_DIR_RE.match(run_name)
    if m:
        try:
            return datetime.strptime(run_name, "%Y%m%d_%H%M%S").timestamp()
        except ValueError:
            pass
    # fall back to the config file's own mtime (invocation start, roughly)
    cfg = os.path.join(run_path, "configs", "task_config.yaml")
    if os.path.exists(cfg):
        return os.path.getmtime(cfg)
    return None


def report_files(run_path):
    return sorted(glob.glob(os.path.join(run_path, "reports", "*", "*.json")))


# --------------------------------------------------------------------------- #
# records
# --------------------------------------------------------------------------- #
def build_records(run_name, run_path, tag, args_datasets_filter=None):
    start_ts = run_start_ts(run_name, run_path)
    cfg_path = os.path.join(run_path, "configs", "task_config.yaml")
    cfg = load_yaml(cfg_path) if os.path.exists(cfg_path) else {}

    records = []
    for rpath in report_files(run_path):
        report = load_json(rpath)
        dataset = report.get("dataset_name") or os.path.splitext(
            os.path.basename(rpath))[0]
        if args_datasets_filter and dataset not in args_datasets_filter:
            continue
        model_id = report.get("model_name") or cfg.get("model_id") or cfg.get(
            "model") or UNAVAILABLE

        wall_s = None
        if start_ts is not None:
            try:
                wall_s = round(os.path.getmtime(rpath) - start_ts, 1)
            except OSError:
                wall_s = None

        metrics = report.get("metrics") or []
        multi_metric = len(metrics) > 1
        for metric in metrics:
            identity = metric.get("identity") or {}
            metric_name = (metric.get("legacy_name") or identity.get("name")
                            or "metric")
            for category in metric.get("categories") or []:
                for subset in category.get("subsets") or []:
                    if subset.get("is_aggregate"):
                        continue
                    subset_name = subset.get("name") or "default_subset"
                    case = dataset + "/" + str(subset_name)
                    if multi_metric:
                        case += "::" + str(metric_name)
                    score = subset.get("score")
                    n = subset.get("num")
                    rec = {
                        "task": dataset,
                        "case": case,
                        "profile": "evalscope",
                        "effort": "n/a",
                        "model": model_id,
                        "tag": tag,
                        "score": score,
                        "n": n,
                        "quality": {"graded": True, "correct": None,
                                    "score": score},
                    }
                    if wall_s is not None:
                        rec["wall_s"] = wall_s
                    records.append(rec)

    return records, cfg


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def default_run_id(out_dir):
    """results/community/<run-id>/records -> <run-id>. Falls back to the
    out-dir's own basename if it isn't nested under a run-id-named parent."""
    parent = os.path.basename(os.path.dirname(os.path.normpath(out_dir)))
    return parent or os.path.basename(os.path.normpath(out_dir))


def default_date(run_id):
    m = re.match(r"^(\d{4}-\d{2}-\d{2})", run_id)
    return m.group(1) if m else date.today().isoformat()


def build_parser():
    ap = argparse.ArgumentParser(
        prog="evalscope_to_records.py",
        description="Convert an `evalscope eval` work-dir into hwbench "
                     "community-lane results.jsonl + manifest.yaml.")
    ap.add_argument("work_dir", help="evalscope --work-dir root "
                     "(the directory holding one <YYYYMMDD_HHMMSS>/ subdir "
                     "per `evalscope eval` invocation)")
    ap.add_argument("out_dir", help="destination dir for results.jsonl "
                     "and manifest.yaml")
    ap.add_argument("--run-id")
    ap.add_argument("--date")
    ap.add_argument("--node", default="kalman9-framework-01")
    ap.add_argument("--lane", default="community", choices=("bespoke", "community"))
    ap.add_argument("--harness", default="evalscope")
    ap.add_argument("--tag", default="evalscope-pilot")
    ap.add_argument("--backend", default="unsloth-studio (ROCm gfx1151)")
    ap.add_argument("--runtime-build",
                     default="version: 0.3.0-dev (build 10687, commit 92b19177a)")
    ap.add_argument("--studio-version", default="unsloth 2026.8.22")
    ap.add_argument("--forgejo-issue", type=int, default=15)
    ap.add_argument("--datasets", nargs="*", default=None,
                     help="restrict to these dataset names (default: all "
                          "datasets found under work_dir)")
    return ap


def main(argv=None):
    args = build_parser().parse_args(argv)
    work_dir = os.path.normpath(args.work_dir)
    out_dir = os.path.normpath(args.out_dir)

    run_id = args.run_id or default_run_id(out_dir)
    run_date = args.date or default_date(run_id)

    run_dirs = find_run_dirs(work_dir)

    all_records = []
    configs = []
    for run_name, run_path in run_dirs:
        recs, cfg = build_records(run_name, run_path, args.tag, args.datasets)
        if not recs:
            warn("no report JSON found in " + run_path)
            continue
        all_records.extend(recs)
        if cfg:
            configs.append(cfg)

    if not all_records:
        die("no records built from any run dir under " + work_dir)

    os.makedirs(out_dir, exist_ok=True)
    records_path = os.path.join(out_dir, "results.jsonl")
    with open(records_path, "w", encoding="utf-8") as f:
        for rec in all_records:
            f.write(json.dumps(rec, sort_keys=True) + "\n")

    # ---- manifest: EvalScope-derived facts, layered under pilot-identity ----
    models = sorted({r["model"] for r in all_records if r.get("model")})
    datasets = sorted({r["task"] for r in all_records})
    limits = sorted({cfg.get("limit") for cfg in configs if cfg.get("limit") is not None})
    apis = sorted({cfg.get("api_url") for cfg in configs if cfg.get("api_url")})
    eval_types = sorted({cfg.get("eval_type") for cfg in configs if cfg.get("eval_type")})
    versions = sorted({cfg.get("evalscope_version") for cfg in configs
                        if cfg.get("evalscope_version")})

    manifest = {
        "run_id": run_id,
        "date": run_date,
        "node": args.node,
        "backend": args.backend,
        "runtime_build": args.runtime_build,
        "studio_version": args.studio_version,
        "api": apis[0] if len(apis) == 1 else (apis or UNAVAILABLE),
        "model": models[0] if len(models) == 1 else models,
        "lane": args.lane,
        "harness": args.harness,
        "evalscope_version": versions[0] if len(versions) == 1 else (versions or UNAVAILABLE),
        "eval_type": eval_types[0] if len(eval_types) == 1 else (eval_types or UNAVAILABLE),
        "datasets": datasets,
        "limit": limits[0] if len(limits) == 1 else (limits or UNAVAILABLE),
        "records": "results.jsonl",
        "driver_script": "evalscope eval",
        "forgejo_issue": args.forgejo_issue,
        "source_work_dir": os.path.relpath(work_dir, os.getcwd()).replace("\\", "/"),
        "run_dirs": [name for name, _ in run_dirs],
    }
    dump_yaml(manifest, os.path.join(out_dir, "manifest.yaml"))

    print("records:  " + records_path + "  (" + str(len(all_records)) + " rows)")
    print("manifest: " + os.path.join(out_dir, "manifest.yaml"))
    print("datasets: " + ", ".join(datasets))
    print("run_dirs: " + ", ".join(name for name, _ in run_dirs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
