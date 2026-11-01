#!/usr/bin/env python3
"""Log one committed sweep directory to MLflow as a parent run + one child per record.

    log_sweep_to_mlflow.py <rundir> [options]

This is the intake shim for the evidence lakehouse (docs/reference/
EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md). It reads what the sweep drivers already
write -- a manifest, a JSONL of records, transcripts under outputs/ -- and turns
it into MLflow runs. It NEVER writes into results/, never re-grades anything, and
never needs the inference node: everything it needs is on disk.

Design points that matter
-------------------------
* **Idempotent.** Every record gets a `record_key` = sha1(run_id | model | tag |
  task | profile | effort | case). One search_runs() up front collects the keys
  already logged under this run_id; those records are skipped and the existing
  parent is reused. Re-running the shim on a logged directory creates nothing.
* **Degrade, never guess.** A fact this box cannot see -- a GGUF sha256 for a
  model that lives on the Framework's /mnt/ai-models, a grader SHA with no
  checkout in scope -- is tagged the literal string "unavailable", never omitted
  and never invented. `--refresh-tags` re-visits already-logged children and
  fills in any "unavailable" tag whose real value is now knowable (e.g. the same
  command re-run ON the node, where the model files are actually present).
* **Layered fields.** record -> manifest -> constant default. The hand-authored
  manifest.yaml wins over the machine-written manifest.auto.yaml, which wins over
  manifest.json; the record wins over all of them.
* **Two lanes, never mixed.** `--lane community` routes to its own
  `hwbench/community-<harness>` experiment so an EvalScope score can never land
  in a bespoke leaderboard.
* **Metadata beyond tags (hwbench #27).** Every run carries a `mlflow.note.content`
  description (one line per child, a sweep summary on the parent), the parent
  carries a sortable per-cell `eval_results.json` table (`mlflow.log_table`) and a
  dataset input for the prompt set / tool-case bundle it ran (`mlflow.log_input`),
  and the experiment carries a methodology note. `mlflow.source.*` tags point at
  the rundir and the git commit of the checkout it was logged from. `--refresh-tags`
  back-fills all of these on runs logged before this existed.

Options
-------
    --tracking-uri URI     default: $MLFLOW_TRACKING_URI, else http://192.168.7.241:5000
    --lane bespoke|community
    --dry-run              print what would be logged; touch nothing
    --spec PATH            spec JSON (else manifest['spec'], else inferred)
    --records NAME         records file inside the rundir (default results.jsonl)
    --models-root PATH     GGUF root for repo-id / sha / size resolution
    --with-logs            attach serve/runner logs as parent artifacts
    --forgejo-issue N      tag the parent with the tracking issue
    --refresh-tags         update "unavailable" tags on already-logged children
"""
import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

DEFAULT_TRACKING_URI = "http://192.168.7.241:5000"
UNAVAILABLE = "unavailable"
PARAM_MAX = 500

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(HERE))

# ---- manifest scalars promoted to params (§5 of the reference architecture) ---
MANIFEST_PARAMS = ("run_id", "date", "node", "hardware", "backend", "api",
                   "isolation", "axis", "driver_script", "rung", "grading")

# ---- record fields promoted to metrics -------------------------------------- #
METRIC_FIELDS = ("wall_s", "load_s", "prompt_tokens", "prompt_tokens_total",
                 "completion_tokens", "tps_wall", "tps_server", "prefill_tps",
                 "reasoning_chars", "content_chars", "turns", "n_calls",
                 "chain_depth_reached", "args_parse_failures",
                 # speculative decoding (MTP / draft) counters from llama-server timings
                 "draft_n", "draft_n_accepted", "draft_accept_rate")

# quality fields that stay flat; every other numeric/bool quality field gets q_
QUALITY_FLAT = ("correct", "n_calls", "chain_depth_reached")

SPEC_KNOWN = ("name", "path", "tag", "flags", "env")

FORGEJO_ISSUES = "https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/"
NOTE_TAG = "mlflow.note.content"
TABLE_FILE = "eval_results.json"
# per-cell table: fixed columns first, then every q_* quality metric seen
TABLE_COLUMNS = ("cfg", "task", "validity", "correct", "tps_wall", "tps_server",
                 "completion_tokens", "prompt_tokens", "wall_s", "load_s",
                 "finish_reason")
EXPERIMENT_NOTES = {
    "toolcall": (
        "Track 1 tool-calling battery (deterministic, greedy, one graded cell per "
        "fresh server). Cases live in scripts/sweeps/toolcall_cases*.json and are "
        "attached to every parent run as a dataset input; grading is "
        "scripts/utils/grade_sweep.py (static, no LLM judge). Children are cells, "
        "parents are sweeps; see docs/reference/TRACK2-HARNESS-BENCHMARKS.md and "
        "docs/reference/PERFORMANCE-SUMMARY.md."),
    "text-sweeps": (
        "Text battery (reasoning / code / summarize) from scripts/sweeps/"
        "sweep_phase1.py at the roster-baseline config (thinking, low effort, "
        "seed 42), one fresh server per model. Graded statically by "
        "scripts/utils/grade_sweep.py; t/s is wall-clock over completion tokens. "
        "Ranking tables: docs/reference/PERFORMANCE-SUMMARY.md."),
    "agent-battery": (
        "Track 2A agent-harness battery: real coding agents driven against a "
        "pinned local server (scripts/agents/). Metrics are end-to-end task "
        "wall time and pass/fail; see docs/reference/TRACK2-HARNESS-BENCHMARKS.md."),
    "serving-config": (
        "Serving-configuration A/B sweeps (cache-ram, slots, speculation). The "
        "axis is the server flag set, the workload is held constant."),
}
EXPERIMENT_NOTE_FOOTER = (
    "\n\nLogged by scripts/utils/log_sweep_to_mlflow.py from committed rundirs "
    "under results/sweeps/ (vvc/vtt-hw-benchmarks). Architecture: "
    "docs/reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md. Tags follow its section 5; "
    "descriptions, tables and dataset inputs are hwbench #27.")

QUANT_RE = re.compile(
    r"(?i)-((?:UD-)?(?:I?Q\d+(?:_[A-Z0-9]+)*)|F16|BF16|F32|MXFP4)"
    r"(?:-\d{5}-of-\d{5})?\.gguf$")
QUANT_DIR_RE = re.compile(
    r"(?i)^((?:UD-)?(?:I?Q\d+(?:_[A-Z0-9]+)*)|F16|BF16|F32|MXFP4)$")
SHA256_RE = re.compile(r"\b[0-9a-f]{64}\b")


# --------------------------------------------------------------------------- #
# small helpers
# --------------------------------------------------------------------------- #
def die(msg):
    print("ERROR: " + msg, file=sys.stderr)
    raise SystemExit(2)


def warn(msg):
    print("WARNING: " + msg, file=sys.stderr)


def load_yaml(path):
    """YAML via PyYAML -- never a hand parser. Declared in the `mlflow` extra."""
    try:
        import yaml
    except ImportError:
        die("PyYAML is required to read manifests. "
            "Install the extra:  pip install -e '.[mlflow]'")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            data = yaml.safe_load(f)
    except Exception as e:  # noqa: BLE001
        warn("could not parse " + path + ": " + repr(e))
        return {}
    return data if isinstance(data, dict) else {}


def load_json(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            data = json.load(f)
    except Exception as e:  # noqa: BLE001
        warn("could not parse " + path + ": " + repr(e))
        return {}
    return data


def as_param(v):
    if isinstance(v, (dict, list, tuple)):
        s = json.dumps(v, sort_keys=True)
    elif v is None:
        s = ""
    else:
        s = str(v)
    return s[:PARAM_MAX]


def as_metric(v):
    if isinstance(v, bool):
        return 1.0 if v else 0.0
    if isinstance(v, (int, float)):
        f = float(v)
        if f != f or f in (float("inf"), float("-inf")):
            return None
        return f
    return None


def first(*vals):
    """First value that is not None and not an empty string."""
    for v in vals:
        if v is not None and v != "":
            return v
    return None


# --------------------------------------------------------------------------- #
# manifest / spec / records
# --------------------------------------------------------------------------- #
def load_manifest(rundir):
    """manifest.auto.yaml (base) < manifest.json < manifest.yaml (wins).

    Returns (merged, manifest_json) -- the raw json is kept because the
    agent-battery family is identified by its `agents` key.
    """
    merged = {}
    auto = os.path.join(rundir, "manifest.auto.yaml")
    if os.path.exists(auto):
        merged.update(load_yaml(auto))
    mjson = {}
    jpath = os.path.join(rundir, "manifest.json")
    if os.path.exists(jpath):
        loaded = load_json(jpath)
        if isinstance(loaded, dict):
            mjson = loaded
            merged.update(mjson)
    ypath = os.path.join(rundir, "manifest.yaml")
    if os.path.exists(ypath):
        merged.update(load_yaml(ypath))
    return merged, mjson


def detect_family(manifest, mjson, dirname):
    """toolcall | text-sweeps | agent-battery | serving-config | misc."""
    driver = str(manifest.get("driver_script") or "")
    hay = driver + " " + dirname
    if re.search(r"toolcall_battery\.py|sweep_toolcall\.py", hay):
        return "toolcall"
    if re.search(r"roster_batch\.py|g1a_validation\.py|sweep_phase\d*\.py", hay):
        return "text-sweeps"
    # Dirname A/B check runs BEFORE the agents check: 2026-09-03-cacheram-ab is
    # driven by agent_task_battery.py (so its manifest.json has `agents`) but it
    # IS the serving-config A/B of §5 -- cache_ram is the axis, the agent is the
    # workload. Letting `agents` win would file it under the wrong experiment.
    base = os.path.basename(dirname)
    if re.search(r"cacheram", base, re.I) or base.endswith("-ab"):
        return "serving-config"
    if "agents" in mjson:
        return "agent-battery"
    warn("could not classify " + base + " from driver_script=" + repr(driver)
         + "; filing under hwbench/misc")
    return "misc"


def resolve_records(rundir, manifest, records_arg):
    cands = []
    if records_arg:
        cands += [records_arg, records_arg + ".jsonl"]
    else:
        cands += [str(manifest.get("records") or ""), "results.jsonl"]
    for c in cands:
        if not c:
            continue
        p = c if os.path.isabs(c) else os.path.join(rundir, c)
        if os.path.exists(p):
            return p
    die("no records file in " + rundir + " (looked for: "
        + ", ".join(x for x in cands if x) + "). "
        "This directory has no JSONL to log -- nothing to do.")


def read_records(path):
    out = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError as e:
                warn("skipping malformed line %d of %s: %s" % (n, path, e))
    return out


def load_spec(rundir, manifest, spec_arg):
    if spec_arg:
        data = load_json(spec_arg)
        return data if isinstance(data, list) else []
    ms = manifest.get("spec")
    if isinstance(ms, list):
        return ms
    for name in ("spec.json", "smoke_claude.json"):
        p = os.path.join(rundir, name)
        if os.path.exists(p):
            data = load_json(p)
            if isinstance(data, list):
                return data
    return []


def index_spec(spec):
    idx = {}
    for row in spec:
        if not isinstance(row, dict) or "name" not in row:
            continue
        idx[str(row["name"]) + "__" + str(row.get("tag", "default"))] = row
        idx.setdefault(str(row["name"]), row)
    return idx


# --------------------------------------------------------------------------- #
# model identity
# --------------------------------------------------------------------------- #
def load_inventory():
    """models-inventory.yaml -> lookup tables. Searched at the repo root and docs/."""
    for cand in (os.path.join(REPO_ROOT, "models-inventory.yaml"),
                 os.path.join(REPO_ROOT, "docs", "models-inventory.yaml"),
                 os.path.join(os.getcwd(), "models-inventory.yaml")):
        if os.path.exists(cand):
            data = load_yaml(cand)
            break
    else:
        return {"by_file": {}, "by_name": {}, "path": ""}

    by_file, by_name = {}, {}
    for value in data.values():
        if not isinstance(value, list):
            continue
        for entry in value:
            if not isinstance(entry, dict):
                continue
            hf_file = entry.get("hf_file")
            if hf_file:
                by_file.setdefault(str(hf_file), entry)
                by_file.setdefault(os.path.basename(str(hf_file)), entry)
            name = entry.get("name")
            if name:
                by_name.setdefault(str(name), entry)
            repo = str(entry.get("hf_repo") or "")
            if repo:
                stem = re.sub(r"(?i)-gguf$", "", repo.split("/")[-1])
                by_name.setdefault(stem, entry)
    return {"by_file": by_file, "by_name": by_name, "path": cand}


def split_quant(basename):
    m = QUANT_RE.search(basename)
    return m.group(1) if m else None


def hf_repo_id(model_path, models_root):
    """Path segments after --models-root as <org>/<repo>.

    Climbs one level when the GGUF's own parent dir is itself a quant token, e.g.
    .../unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q4_K_XL/x-00001-of-00004.gguf
    -> unsloth/Qwen3.8-Flash-Next-GGUF
    """
    p = str(model_path).replace("\\", "/")
    root = str(models_root).replace("\\", "/").rstrip("/")
    if not p.startswith(root + "/"):
        return None
    parts = [x for x in p[len(root) + 1:].split("/") if x]
    if len(parts) < 2:
        return None
    dirs = parts[:-1]
    if len(dirs) >= 2 and QUANT_DIR_RE.match(dirs[-1]):
        dirs = dirs[:-1]
    if len(dirs) < 2:
        return "/".join(dirs)
    return dirs[-2] + "/" + dirs[-1]


def gguf_sha256(model_path):
    """Read the etag/sha256 out of the HF download metadata sidecar.

    HF writes <local-dir>/.cache/huggingface/download/<relpath>.metadata. Both the
    file-adjacent and the repo-root form are probed because multi-part repos are
    fetched into a quant subdirectory.
    """
    p = str(model_path).replace("\\", "/")
    d = os.path.dirname(p)
    base = os.path.basename(p)
    cands = [os.path.join(d, ".cache", "huggingface", "download", base + ".metadata")]
    parent = os.path.dirname(d)
    if parent:
        cands.append(os.path.join(parent, ".cache", "huggingface", "download",
                                  os.path.basename(d), base + ".metadata"))
    for c in cands:
        if os.path.exists(c):
            try:
                with open(c, encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except OSError:
                continue
            m = SHA256_RE.search(text)
            if m:
                return m.group(0)
    return UNAVAILABLE


def model_identity(model_path, model_name, models_root, inv):
    """-> dict(model_path, hf_repo_id, gguf_file, quant, gguf_sha256,
              gguf_size_bytes, model_key). Every unknown degrades to "unavailable"."""
    path = model_path or ""
    entry = None

    # No spec row for this cfg (older runs recorded only `model`): recover the
    # path from models-inventory.yaml by model name / hf_repo stem.
    if not path and model_name:
        entry = inv["by_name"].get(str(model_name))
        if entry and entry.get("hf_repo") and entry.get("hf_file"):
            path = (str(models_root).rstrip("/") + "/" + str(entry["hf_repo"])
                    + "/" + str(entry["hf_file"]))

    if not path:
        return {"model_path": "", "hf_repo_id": UNAVAILABLE, "gguf_file": UNAVAILABLE,
                "quant": UNAVAILABLE, "gguf_sha256": UNAVAILABLE,
                "gguf_size_bytes": UNAVAILABLE,
                "model_key": str(model_name or UNAVAILABLE)}

    base = os.path.basename(path.replace("\\", "/"))
    quant = split_quant(base) or UNAVAILABLE
    repo = hf_repo_id(path, models_root) or UNAVAILABLE

    if entry is None:
        entry = inv["by_file"].get(base)
        if entry is None and repo != UNAVAILABLE:
            rel = path.replace("\\", "/").split(repo + "/", 1)
            if len(rel) == 2:
                entry = inv["by_file"].get(rel[1])

    model_key = (str(entry.get("name")) if entry and entry.get("name")
                 else repo + "#" + quant)

    try:
        size = os.path.getsize(path)
    except OSError:
        size = UNAVAILABLE

    return {"model_path": path, "hf_repo_id": repo, "gguf_file": base,
            "quant": quant, "gguf_sha256": gguf_sha256(path),
            "gguf_size_bytes": size, "model_key": model_key}


# --------------------------------------------------------------------------- #
# flags / validity / keys
# --------------------------------------------------------------------------- #
def parse_flags(flags):
    f = str(flags or "")
    ctx = re.search(r"(?:^|\s)-c\s+(\S+)", f)
    cache = re.search(r"--cache-ram(?:[= ])\s*(\S+)", f)
    par = re.search(r"--parallel(?:[= ])\s*(\S+)", f)
    return (ctx.group(1) if ctx else UNAVAILABLE,
            cache.group(1) if cache else UNAVAILABLE,
            par.group(1) if par else UNAVAILABLE)


def validity(rec):
    q = rec.get("quality") or {}
    if rec.get("loaded") is False:
        return "load_failed"
    if q.get("reason") == "transcript_trampled":
        return "trampled"
    if q.get("tools_injection_suspect"):
        return "contaminated"
    if not q or q.get("graded") is False:
        return "ungraded"
    return "ok"


def record_key(run_id, rec, tag):
    parts = [str(run_id), str(rec.get("model") or ""), str(tag or ""),
             str(rec.get("task") or ""), str(rec.get("profile") or ""),
             str(rec.get("effort") or ""), str(rec.get("case") or "")]
    return hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()


_GRADER_CACHE = {}


def grader_version():
    if "v" in _GRADER_CACHE:
        return _GRADER_CACHE["v"]
    v = UNAVAILABLE
    try:
        p = subprocess.run(
            ["git", "-C", REPO_ROOT, "log", "-1", "--format=%h", "--",
             "scripts/utils/grade_sweep.py"],
            capture_output=True, text=True, timeout=30)
        if p.returncode == 0 and p.stdout.strip():
            v = p.stdout.strip()
    except Exception:  # noqa: BLE001
        pass
    if v == UNAVAILABLE:
        # No checkout in scope (e.g. running inside a container that mounts only
        # the worktree, whose .git is a pointer file). Let the caller hoist it.
        v = os.environ.get("HWBENCH_GRADER_VERSION") or UNAVAILABLE
    _GRADER_CACHE["v"] = v
    return v


def source_git_commit(rundir):
    """Full SHA of the checkout the rundir sits in; "" when there is none."""
    try:
        p = subprocess.run(["git", "-C", rundir, "rev-parse", "HEAD"],
                           capture_output=True, text=True, timeout=30)
        if p.returncode == 0 and p.stdout.strip():
            return p.stdout.strip()
    except Exception:  # noqa: BLE001
        pass
    # Container mounts of a worktree see only a .git pointer file: let the
    # caller hoist the SHA, same as HWBENCH_GRADER_VERSION.
    return os.environ.get("HWBENCH_GIT_COMMIT", "")


def fmt_num(v, nd=1):
    if v is None:
        return "-"
    try:
        return ("%." + str(nd) + "f") % float(v)
    except (TypeError, ValueError):
        return str(v)


def rel_repo(path):
    return os.path.relpath(path, REPO_ROOT).replace("\\", "/")


# --------------------------------------------------------------------------- #
# descriptions, per-cell table, dataset inputs (hwbench #27)
# --------------------------------------------------------------------------- #
def child_note(ident, tags, metrics, task):
    """One-line description shown in the run's Description panel."""
    pieces = [str(ident["model_key"]), str(ident["quant"]), task or "-",
              tags.get("validity", UNAVAILABLE)]
    if "correct" in metrics:
        pieces.append("pass" if metrics["correct"] else "FAIL")
    if metrics.get("tps_wall") is not None:
        pieces.append(fmt_num(metrics["tps_wall"]) + " t/s")
    pieces.append(str(tags.get("runtime_build", UNAVAILABLE)) + " on "
                  + str(tags.get("host", UNAVAILABLE)))
    return " | ".join(pieces)


def results_table(children):
    """Dict-of-lists for mlflow.log_table: one row per child (cell)."""
    qcols = sorted({k for c in children for k in c["metrics"] if k.startswith("q_")})
    cols = list(TABLE_COLUMNS) + qcols
    rows = {c: [] for c in cols}
    for c in children:
        m, t, p = c["metrics"], c["tags"], c["params"]
        cfg, _, task = c["name"].partition("/")
        vals = {"cfg": cfg, "task": task or p.get("task", ""),
                "validity": t.get("validity", UNAVAILABLE),
                "finish_reason": t.get("finish_reason", UNAVAILABLE)}
        for col in cols:
            rows[col].append(vals[col] if col in vals else m.get(col))
    return rows


def parent_note(ctx, children, family, experiment, issue):
    models = sorted({c["tags"]["model_key"] for c in children})
    quants = sorted({c["tags"]["quant"] for c in children})
    graded = [c for c in children if "correct" in c["metrics"]]
    passed = sum(1 for c in graded if c["metrics"]["correct"])
    tps = sorted(c["metrics"]["tps_wall"] for c in children
                 if c["metrics"].get("tps_wall") is not None)
    bad = sorted({c["tags"]["validity"] for c in children
                  if c["tags"]["validity"] != "ok"})
    m = ctx["manifest"]
    lines = ["**" + ctx["run_id"] + "** -- " + family + " sweep, " + str(len(children))
             + " cells (" + experiment + ", lane " + ctx["lane"] + ")",
             "Models: " + ", ".join(models) + "  |  quants: " + ", ".join(quants)]
    if graded:
        lines.append("Graded: %d/%d pass" % (passed, len(graded))
                     + (" (validity: " + ", ".join(bad) + ")" if bad else ""))
    if tps:
        lines.append("tps_wall: min %s / median %s / max %s"
                     % (fmt_num(tps[0]), fmt_num(tps[len(tps) // 2]), fmt_num(tps[-1])))
    lines.append("Runtime " + str(first(m.get("runtime_build"), UNAVAILABLE))
                 + " on " + str(first(m.get("node"), UNAVAILABLE))
                 + " (" + str(first(m.get("os"), UNAVAILABLE)) + "); isolation "
                 + str(first(m.get("isolation"), UNAVAILABLE)) + "; driver "
                 + str(first(m.get("driver_script"), UNAVAILABLE)))
    lines.append("Source: " + rel_repo(ctx["rundir"])
                 + ("  @ " + ctx["git_commit"][:12] if ctx["git_commit"] else ""))
    if issue is not None:
        lines.append("Tracking: " + FORGEJO_ISSUES + str(issue))
    return "\n".join(lines)


def dataset_inputs(ctx, family, children):
    """-> list of {name, source, rows} describing the prompt set the sweep ran.

    Rows are plain dicts; log_live turns them into a pandas dataset. Nothing here
    imports mlflow or pandas so --dry-run stays dependency-free.
    """
    out = []
    rundir = ctx["rundir"]
    if family == "toolcall":
        for path in sorted(glob.glob(os.path.join(rundir, "toolcall_cases*.json"))):
            bundle = load_json(path)
            cases = bundle.get("cases") if isinstance(bundle, dict) else None
            if not isinstance(cases, dict) or not cases:
                continue
            rows = []
            for cid, case in cases.items():
                if not isinstance(case, dict):
                    continue
                rows.append({"case": str(cid), "kind": str(case.get("kind", "")),
                             "intent": str(case.get("intent", "")),
                             "prompt": str(case.get("prompt", "")),
                             "n_tools": len(case.get("tools") or []),
                             "expect": json.dumps(case.get("expect", {}),
                                                  sort_keys=True)})
            stem = os.path.splitext(os.path.basename(path))[0].replace("_", "-")
            name = stem + "-v" + str(bundle.get("version", 1))
            if ctx["tier"] != UNAVAILABLE:
                name += "-tier" + str(ctx["tier"])
            out.append({"name": name, "rows": rows, "source": rel_repo(path)})
    elif family == "text-sweeps":
        sweeps_dir = os.path.join(REPO_ROOT, "scripts", "sweeps")
        if sweeps_dir not in sys.path:
            sys.path.insert(0, sweeps_dir)
        try:
            from sweep_phase1 import TASKS  # noqa: E402
        except Exception as e:  # noqa: BLE001
            warn("text battery prompts unavailable (" + repr(e) + "); no dataset input")
            return out
        used = {c["params"].get("task") for c in children}
        rows = [{"task": str(k), "prompt": str(v)} for k, v in TASKS.items()
                if not used or k in used]
        out.append({"name": "text-battery-v1", "rows": rows,
                    "source": "scripts/sweeps/sweep_phase1.py"})
    return out


def experiment_note(family):
    body = EXPERIMENT_NOTES.get(family)
    return body + EXPERIMENT_NOTE_FOOTER if body else None


# --------------------------------------------------------------------------- #
# building one child
# --------------------------------------------------------------------------- #
def build_child(rec, ctx):
    manifest = ctx["manifest"]
    consts = ctx["consts"]
    cfg = str(rec.get("cfg") or rec.get("model") or "")
    row = ctx["spec_idx"].get(cfg) or ctx["spec_idx"].get(str(rec.get("model") or "")) or {}
    tag = first(rec.get("tag"), row.get("tag"),
                cfg.split("__", 1)[1] if "__" in cfg else None) or ""

    ident = model_identity(row.get("path"), rec.get("model"),
                           ctx["models_root"], ctx["inv"])
    flags = first(rec.get("flags"), row.get("flags"), manifest.get("flags")) or ""
    ctxlen, cache_ram, parallel = parse_flags(flags)
    env = rec.get("env") or row.get("env") or manifest.get("launch_env") or {}

    # ---------------- params ----------------
    params = {}
    for k in MANIFEST_PARAMS:
        v = manifest.get(k)
        if v is not None and not isinstance(v, (dict, list, tuple)):
            params[k] = as_param(v)
    for k, v in (consts or {}).items():
        params["request_constants." + str(k)] = as_param(v)
    if row:
        params["model_name"] = as_param(row.get("name", rec.get("model", "")))
        params["model_path"] = as_param(row.get("path", ""))
        params["tag"] = as_param(tag)
        params["flags"] = as_param(flags)
        for k, v in (row.get("env") or {}).items():
            params["env." + str(k)] = as_param(v)
        for k, v in row.items():                       # unknown spec keys pass through
            if k not in SPEC_KNOWN:
                params[str(k)] = as_param(v)
    else:
        params["model_name"] = as_param(rec.get("model", ""))
        params["model_path"] = as_param(ident["model_path"])
        params["tag"] = as_param(tag)
        params["flags"] = as_param(flags)
        for k, v in (env or {}).items():
            params["env." + str(k)] = as_param(v)
    for k in ("task", "profile", "effort", "cfg"):
        if rec.get(k) is not None:
            params[k] = as_param(rec.get(k))

    # ---------------- metrics ----------------
    metrics = {}
    for k in METRIC_FIELDS:
        m = as_metric(rec.get(k))
        if m is not None:
            metrics[k] = m
    for k, v in (rec.get("quality") or {}).items():
        m = as_metric(v)
        if m is None:
            continue
        metrics[k if k in QUALITY_FLAT else "q_" + str(k)] = m

    # ---------------- tags ----------------
    key = record_key(ctx["run_id"], rec, tag)
    src = os.path.relpath(ctx["records_path"], REPO_ROOT).replace("\\", "/")
    tags = {
        # mandatory (reference architecture §5)
        "host": str(first(rec.get("host"), manifest.get("node"), UNAVAILABLE)),
        "os": str(first(rec.get("os"), manifest.get("os"), UNAVAILABLE)),
        "runtime_build": str(first(rec.get("runtime_build"),
                                   manifest.get("runtime_build"), UNAVAILABLE)),
        "studio_version": str(first(manifest.get("studio_version"), UNAVAILABLE)),
        "model_key": str(ident["model_key"]),
        "quant": str(ident["quant"]),
        "isolation": str(first(rec.get("isolation"), manifest.get("isolation"),
                               UNAVAILABLE)),
        "lane": ctx["lane"],
        "validity": validity(rec),
        # descriptive
        "arch": str(first(manifest.get("arch"), UNAVAILABLE)),
        "backend": str(first(manifest.get("backend"), UNAVAILABLE)),
        "ctx": str(ctxlen),
        "cache_ram": str(cache_ram),
        "parallel": str(parallel),
        "flags": as_param(flags) or UNAVAILABLE,
        "env_json": json.dumps(env, sort_keys=True)[:PARAM_MAX],
        "reasoning_effort": str(first(rec.get("effort"),
                                      (consts or {}).get("reasoning_effort"),
                                      UNAVAILABLE)),
        "seed": str(first(rec.get("seed"), (consts or {}).get("seed"), UNAVAILABLE)),
        "temperature": str(first(rec.get("temperature"),
                                 (consts or {}).get("temperature"), UNAVAILABLE)),
        "top_p": str(first(rec.get("top_p"), (consts or {}).get("top_p"), UNAVAILABLE)),
        "track": ctx["track"],
        "tier": ctx["tier"],
        "finish_reason": str(first(rec.get("finish_reason"), UNAVAILABLE)),
        "grading_method": "static-deterministic",
        "grader_version": ctx["grader_version"],
        "hf_repo_id": str(ident["hf_repo_id"]),
        "gguf_file": str(ident["gguf_file"]),
        "gguf_sha256": str(ident["gguf_sha256"]),
        "gguf_size_bytes": str(ident["gguf_size_bytes"]),
        "hwbench.run_id": ctx["run_id"],
        "hwbench.record_key": key,
        "hwbench.source_path": src,
    }

    task = str(rec.get("task") or rec.get("case") or "")
    if cfg and task:
        name = cfg + "/" + task
    else:
        name = task or cfg or key[:8]

    tags[NOTE_TAG] = child_note(ident, tags, metrics, task)
    tags["mlflow.source.name"] = rel_repo(ctx["rundir"])
    tags["mlflow.source.type"] = "LOCAL"
    if ctx["git_commit"]:
        tags["mlflow.source.git.commit"] = ctx["git_commit"]

    return {"key": key, "name": name, "params": params, "metrics": metrics,
            "tags": tags, "artifacts": child_artifacts(rec, ctx, cfg, task)}


def child_artifacts(rec, ctx, cfg, task):
    rundir = ctx["rundir"]
    out = []
    for rel in (rec.get("transcript"), rec.get("diff_file")):
        if rel:
            p = os.path.join(rundir, str(rel))
            if os.path.exists(p):
                out.append(p)
    stem = (str(task) + "--" + str(rec.get("profile") or "")
            + "--" + str(rec.get("effort") or "") + ".txt")
    for sub in (cfg, str(rec.get("model") or "")):
        if not sub:
            continue
        for fname in (stem, str(task) + ".txt", str(task) + ".log"):
            p = os.path.join(rundir, "outputs", sub, fname)
            if os.path.exists(p) and p not in out:
                out.append(p)
                break
        if out:
            break
    return out


def parent_artifacts(rundir, records_path, with_logs):
    names = ["manifest.yaml", "manifest.json", "manifest.auto.yaml",
             "manifest.notes.yaml", "spec.json", "receipt_truth.json"]
    out = [os.path.join(rundir, n) for n in names
           if os.path.exists(os.path.join(rundir, n))]
    if os.path.exists(records_path):
        out.append(records_path)
    out += sorted(glob.glob(os.path.join(rundir, "toolcall_cases*.json")))
    if with_logs:
        out += sorted(glob.glob(os.path.join(rundir, "*.log")))
    seen, uniq = set(), []
    for p in out:
        ap = os.path.abspath(p)
        if ap not in seen:
            seen.add(ap)
            uniq.append(p)
    return uniq


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def build_parser():
    ap = argparse.ArgumentParser(
        prog="log-sweep-to-mlflow",
        description="Log a committed sweep directory to MLflow (parent + one child per record).")
    ap.add_argument("rundir")
    ap.add_argument("--tracking-uri")
    ap.add_argument("--lane", choices=("bespoke", "community"), default="bespoke")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--spec")
    ap.add_argument("--records")
    ap.add_argument("--models-root", default="/mnt/ai-models")
    ap.add_argument("--with-logs", action="store_true")
    ap.add_argument("--forgejo-issue", type=int)
    ap.add_argument("--refresh-tags", action="store_true")
    return ap


def main(argv=None):
    args = build_parser().parse_args(argv)
    rundir = os.path.normpath(args.rundir)
    if not os.path.isdir(rundir):
        die("not a directory: " + rundir)

    run_id = os.path.basename(rundir)
    manifest, mjson = load_manifest(rundir)
    records_path = resolve_records(rundir, manifest, args.records)
    records = read_records(records_path)
    if not records:
        die("no records parsed from " + records_path)

    family = detect_family(manifest, mjson, rundir)
    if args.lane == "community":
        harness = (os.path.splitext(os.path.basename(args.records))[0]
                   if args.records else run_id)
        experiment = "hwbench/community-" + harness
    else:
        experiment = "hwbench/" + family

    spec = load_spec(rundir, manifest, args.spec)
    consts = manifest.get("request_constants") or {}
    if not isinstance(consts, dict):
        consts = {}

    tier = UNAVAILABLE
    m = re.search(r"tier\s*([0-9]+)", run_id, re.I)
    if m:
        tier = m.group(1)
    track = {"toolcall": "track1", "agent-battery": "track2a",
             "text-sweeps": "text", "serving-config": "serving"}.get(family, UNAVAILABLE)

    ctx = {"rundir": rundir, "run_id": str(manifest.get("run_id") or run_id),
           "manifest": manifest, "consts": consts, "spec_idx": index_spec(spec),
           "models_root": args.models_root, "inv": load_inventory(),
           "lane": args.lane, "track": track, "tier": tier,
           "grader_version": grader_version(), "records_path": records_path,
           "git_commit": source_git_commit(rundir)}

    children = [build_child(r, ctx) for r in records]
    p_artifacts = parent_artifacts(rundir, records_path, args.with_logs)
    table = results_table(children)
    datasets = dataset_inputs(ctx, family, children)
    note = parent_note(ctx, children, family, experiment, args.forgejo_issue)

    if args.dry_run:
        print("experiment: " + experiment)
        print("parent:     " + ctx["run_id"] + "   (family=" + family
              + ", lane=" + args.lane + ")")
        for c in children:
            print("  child  %-72s params=%-3d metrics=%-3d tags=%-3d key=%s"
                  % (c["name"][:72], len(c["params"]), len(c["metrics"]),
                     len(c["tags"]), c["key"][:8]))
            print("         note: " + c["tags"][NOTE_TAG])
        print("parent note:\n  " + note.replace("\n", "\n  "))
        print("table:      %d rows x %d cols (%s)"
              % (len(table["cfg"]), len(table), TABLE_FILE))
        for d in datasets:
            print("dataset:    %s  (%d rows, source %s)"
                  % (d["name"], len(d["rows"]), d["source"]))
        print("totals: 1 parent, %d children, %d parent artifacts, "
              "%d child artifacts  (DRY RUN -- nothing written)"
              % (len(children), len(p_artifacts),
                 sum(len(c["artifacts"]) for c in children)))
        return 0

    return log_live(args, experiment, ctx, children, p_artifacts, family,
                    table, datasets, note)


def log_live(args, experiment, ctx, children, p_artifacts, family,
             table, datasets, note):
    try:
        import mlflow
        from mlflow.tracking import MlflowClient
    except ImportError:
        die("mlflow is not installed. Install the extra:  pip install -e '.[mlflow]'")

    def log_inputs():
        """Attach the prompt set / case bundle as dataset inputs. pandas is a
        dependency of mlflow itself, so it is only imported here."""
        if not datasets:
            return 0
        try:
            import pandas as pd
        except ImportError:
            warn("pandas missing; dataset inputs skipped")
            return 0
        for d in datasets:
            ds = mlflow.data.from_pandas(pd.DataFrame(d["rows"]), source=d["source"],
                                         name=d["name"])
            mlflow.log_input(ds, context="eval")
        return len(datasets)

    uri = args.tracking_uri or os.environ.get("MLFLOW_TRACKING_URI") or DEFAULT_TRACKING_URI
    mlflow.set_tracking_uri(uri)
    exp = mlflow.set_experiment(experiment)
    client = MlflowClient()
    run_id = ctx["run_id"]

    # ---- ONE search up front: existing parent + already-logged record keys ----
    existing = mlflow.search_runs(
        experiment_ids=[exp.experiment_id],
        filter_string="tags.hwbench.run_id = '" + run_id + "'",
        output_format="list", max_results=50000)
    parent_id, by_key = None, {}
    for r in existing:
        k = r.data.tags.get("hwbench.record_key")
        if k:
            by_key[k] = r
        elif r.info.run_name == run_id or r.data.tags.get("mlflow.runName") == run_id:
            parent_id = r.info.run_id
    if parent_id is None:
        for r in existing:                       # a parent with no record_key tag
            if not r.data.tags.get("mlflow.parentRunId"):
                parent_id = r.info.run_id
                break

    def agree(field):
        vals = {c["tags"][field] for c in children}
        return vals.pop() if len(vals) == 1 else "multi"

    p_tags = {"hwbench.run_id": run_id, "lane": args.lane, "validity": "ok",
              "host": agree("host"), "os": agree("os"),
              "runtime_build": agree("runtime_build"),
              "studio_version": agree("studio_version"),
              "isolation": agree("isolation"), "model_key": agree("model_key"),
              "quant": agree("quant"), "family": family,
              NOTE_TAG: note,
              "mlflow.source.name": children[0]["tags"]["mlflow.source.name"],
              "mlflow.source.type": "LOCAL"}
    if ctx["git_commit"]:
        p_tags["mlflow.source.git.commit"] = ctx["git_commit"]
    if args.forgejo_issue is not None:
        p_tags["forgejo_issue"] = str(args.forgejo_issue)

    # experiment-level methodology note: set once, never clobber a hand edit
    exp_note = experiment_note(family)
    if exp_note and not (exp.tags or {}).get(NOTE_TAG):
        client.set_experiment_tag(exp.experiment_id, NOTE_TAG, exp_note)

    created = skipped = refreshed = 0
    p_added = []
    if parent_id:
        parent_run = mlflow.start_run(run_id=parent_id)
    else:
        parent_run = mlflow.start_run(run_name=run_id, tags=p_tags)
    with parent_run:
        pid = parent_run.info.run_id
        if parent_id is None:
            for p in p_artifacts:
                mlflow.log_artifact(p)
            mlflow.log_table(data=table, artifact_file=TABLE_FILE)
            p_added.append("table")
            if log_inputs():
                p_added.append("datasets")
        else:
            if args.forgejo_issue is not None:
                client.set_tag(pid, "forgejo_issue", str(args.forgejo_issue))
            if args.refresh_tags:
                # back-fill the #27 metadata on a parent logged before it existed
                cur = client.get_run(pid)
                for k in (NOTE_TAG, "mlflow.source.name", "mlflow.source.type",
                          "mlflow.source.git.commit"):
                    if k in p_tags and not cur.data.tags.get(k):
                        client.set_tag(pid, k, p_tags[k])
                        p_added.append(k)
                have = {a.path for a in client.list_artifacts(pid)}
                if TABLE_FILE not in have:
                    mlflow.log_table(data=table, artifact_file=TABLE_FILE)
                    p_added.append("table")
                if not (cur.inputs and cur.inputs.dataset_inputs) and log_inputs():
                    p_added.append("datasets")

        for c in children:
            old = by_key.get(c["key"])
            if old is not None:
                skipped += 1
                if args.refresh_tags:
                    for k, v in c["tags"].items():
                        cur_v = old.data.tags.get(k)
                        # fill what is missing or was "unavailable"; never overwrite
                        if v == UNAVAILABLE or (cur_v is not None
                                                and cur_v != UNAVAILABLE):
                            continue
                        client.set_tag(old.info.run_id, k, v)
                        refreshed += 1
                continue
            tags = dict(c["tags"])
            tags["mlflow.parentRunId"] = pid
            with mlflow.start_run(run_name=c["name"], nested=True, tags=tags):
                mlflow.log_params(c["params"])
                if c["metrics"]:
                    mlflow.log_metrics(c["metrics"])
                for p in c["artifacts"]:
                    mlflow.log_artifact(p)
            created += 1

    print("tracking_uri: " + uri)
    print("experiment:   " + experiment + " (id=" + str(exp.experiment_id) + ")")
    print("parent:       " + run_id + " (run_id=" + pid + ")")
    print("children: skipped %d, created %d%s"
          % (skipped, created,
             (", tags refreshed %d" % refreshed) if args.refresh_tags else ""))
    print("parent metadata added: " + (", ".join(p_added) if p_added else "none")
          + "  (table %d rows, %d dataset input(s))" % (len(table["cfg"]), len(datasets)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
