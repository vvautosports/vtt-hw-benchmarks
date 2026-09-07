#!/usr/bin/env python3
"""Machine-written run manifests for sweep drivers. Stdlib only.

The hand-authored `manifest.yaml` in each results/sweeps/<run>/ dir carries the
NARRATIVE (why the run exists, what it proved, caveats). It is written by a human
after the fact and is frequently the only provenance a run has. This module writes
the MECHANICAL half -- host, OS, arch, runtime build, studio version, flags, spec,
request constants, timings, cell counts -- at run time, when the facts are still
available, so no future run depends on somebody remembering.

The two never collide: this module writes `manifest.auto.yaml` and NEVER touches
`manifest.yaml`. The MLflow shim (scripts/utils/log_sweep_to_mlflow.py) merges them
with the hand-authored file on top.

API
---
    m = write_start(rundir, spec, driver, argv, extra)   # -> the manifest dict
    ...run the battery, collecting `records`...
    finalize(rundir, records)                            # closes it out

`extra` supplies whatever the driver knows and this module cannot infer:
backend, api, isolation, axis, records, outputs, cases, request_constants,
grading, forgejo_issue, hardware, rung.

If <rundir>/manifest.notes.yaml exists at finalize time its RAW TEXT is appended
under a `notes:` block scalar -- never parsed, so a half-written note can never
break the emitter.
"""
import json  # noqa: F401  (kept: drivers import this module and json together)
import os
import platform
import re
import socket
import subprocess
import sys
import time

HOME = os.path.expanduser("~")

# Known-node arch map. Refined by `rocminfo` when it is available (an eGPU or a
# different box then reports its real target instead of inheriting the map).
HOST_ARCH = {
    "fedora": "gfx1151",
    "hp-g1a-windows": "gfx1151",
}

_STARTED = {}   # rundir -> manifest dict, so finalize() need not re-parse YAML


# --------------------------------------------------------------------------- #
# environment probes
# --------------------------------------------------------------------------- #
def runtime_build():
    """First line of `llama-server --version`.

    Hoisted here from roster_batch.py so every driver -- and the manifest --
    reports the build the same way. roster_batch imports it from this module.
    """
    exe = os.path.join(HOME, ".unsloth/llama.cpp/llama-server")
    try:
        p = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=60)
        return ((p.stdout or "") + (p.stderr or "")).strip().splitlines()[0]
    except Exception as e:  # noqa: BLE001
        return f"unknown ({e!r})"


def studio_version():
    try:
        p = subprocess.run(["unsloth", "--version"], capture_output=True, text=True, timeout=60)
        return ((p.stdout or "") + (p.stderr or "")).strip().splitlines()[0]
    except Exception:  # noqa: BLE001
        return ""


def detect_arch(node=None):
    node = node or socket.gethostname()
    arch = HOST_ARCH.get(node, "")
    try:
        p = subprocess.run("rocminfo | grep -m1 gfx", shell=True,
                           capture_output=True, text=True, timeout=60)
        m = re.search(r"gfx[0-9a-z]+", (p.stdout or "") + (p.stderr or ""))
        if m:
            arch = m.group(0)
    except Exception:  # noqa: BLE001
        pass
    return arch


def repo_git_sha():
    """Short SHA of the repo this driver was copied from. Blank on the nodes:
    sweep drivers execute from $HOME with no checkout, and that is not an error."""
    here = os.path.dirname(os.path.abspath(__file__))
    try:
        p = subprocess.run(["git", "-C", here, "rev-parse", "HEAD"],
                           capture_output=True, text=True, timeout=30)
        return p.stdout.strip() if p.returncode == 0 else ""
    except Exception:  # noqa: BLE001
        return ""


# --------------------------------------------------------------------------- #
# minimal YAML emitter (quoted scalars, nested lists/dicts)
# --------------------------------------------------------------------------- #
def _scalar(v):
    if v is None:
        return '""'
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v).replace("\\", "\\\\").replace('"', '\\"')
    s = s.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
    return '"' + s + '"'


def _lines(obj, indent=0):
    pad = " " * indent
    out = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, (dict, list, tuple)) and len(v) == 0:
                out.append(pad + str(k) + ": " + ("{}" if isinstance(v, dict) else "[]"))
            elif isinstance(v, (dict, list, tuple)):
                out.append(pad + str(k) + ":")
                out.extend(_lines(v, indent + 2))
            else:
                out.append(pad + str(k) + ": " + _scalar(v))
    elif isinstance(obj, (list, tuple)):
        for item in obj:
            if isinstance(item, (dict, list, tuple)) and len(item) == 0:
                out.append(pad + "- " + ("{}" if isinstance(item, dict) else "[]"))
            elif isinstance(item, dict):
                sub = _lines(item, indent + 2)
                out.append(pad + "- " + sub[0].lstrip())
                out.extend(sub[1:])
            elif isinstance(item, (list, tuple)):
                out.append(pad + "-")
                out.extend(_lines(item, indent + 2))
            else:
                out.append(pad + "- " + _scalar(item))
    return out


def dumps(obj):
    return "\n".join(_lines(obj)) + "\n"


# --------------------------------------------------------------------------- #
# manifest lifecycle
# --------------------------------------------------------------------------- #
def _auto_path(rundir):
    return os.path.join(rundir, "manifest.auto.yaml")


def _write(rundir, man, notes=None):
    os.makedirs(rundir, exist_ok=True)
    text = dumps(man)
    if notes is not None:
        body = "\n".join("  " + ln for ln in notes.replace("\r\n", "\n").split("\n"))
        text += "notes: |\n" + body + "\n"
    with open(_auto_path(rundir), "w", encoding="utf-8") as f:
        f.write(text)


def write_start(rundir, spec, driver, argv, extra=None):
    """Write manifest.auto.yaml at the START of a run and return the dict."""
    extra = dict(extra or {})
    spec = list(spec or [])
    node = socket.gethostname()

    env = {}
    for row in spec:
        for k, v in (row.get("env") or {}).items():
            env[k] = v
    flagset = []
    for row in spec:
        f = row.get("flags", "")
        if f and f not in flagset:
            flagset.append(f)

    axis = extra.get("axis", "cfg")
    records_name = extra.get("records", "results.jsonl")
    issue = extra.get("forgejo_issue") or os.environ.get("HWBENCH_FORGEJO_ISSUE", "")

    man = {
        "run_id": os.path.basename(os.path.normpath(rundir)),
        "date": time.strftime("%Y-%m-%d"),
        "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "ended_utc": "",
        "node": node,
        "os": platform.platform(),
        "arch": detect_arch(node),
        "runtime_build": runtime_build(),
        "studio_version": studio_version(),
        "python_version": platform.python_version(),
        "hardware": extra.get("hardware", ""),
        "backend": extra.get("backend", "unsloth-studio"),
        "api": extra.get("api", "/v1/chat/completions"),
        "isolation": extra.get("isolation", ""),
        "rung": extra.get("rung", ""),
        "launch_env": env,
        "flags": flagset[0] if len(flagset) == 1 else flagset,
        "driver_script": driver,
        "driver_argv": list(argv or []),
        "repo_git_sha": repo_git_sha(),
        "spec": spec,
        "request_constants": extra.get("request_constants") or {},
        "cases": extra.get("cases") or [],
        "axis": axis,
        "records": records_name,
        "outputs": extra.get("outputs", "outputs/"),
        "grading": extra.get(
            "grading",
            "py scripts/utils/grade_sweep.py " + str(rundir) + " "
            + os.path.splitext(records_name)[0] + " --layout " + axis,
        ),
        "forgejo_issue": issue,
        "cell_count": 0,
        "load_failures": 0,
    }
    _STARTED[os.path.abspath(rundir)] = man
    _write(rundir, man)
    return man


def finalize(rundir, records):
    """Close out manifest.auto.yaml: end time, cell count, load failures, notes."""
    key = os.path.abspath(rundir)
    man = _STARTED.get(key)
    if man is None:                      # separate process: rebuild what we can
        man = write_start(rundir, [], "", sys.argv)
    records = list(records or [])
    man["ended_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    man["cell_count"] = len(records)
    man["load_failures"] = sum(1 for r in records if r.get("loaded") is False)

    notes = None
    npath = os.path.join(rundir, "manifest.notes.yaml")
    if os.path.exists(npath):
        try:
            with open(npath, encoding="utf-8", errors="replace") as f:
                notes = f.read().rstrip("\n")
        except OSError:
            notes = None
    _write(rundir, man, notes=notes)
    return man


if __name__ == "__main__":       # smoke: emit a manifest for a dir given on argv
    d = sys.argv[1] if len(sys.argv) > 1 else "."
    rows = [{"name": "demo", "path": "/mnt/ai-models/org/demo-GGUF/demo-UD-Q8_K_XL.gguf",
             "tag": "raw", "flags": "-c 4096 --cache-ram 32768", "env": {"X": "1"}}]
    write_start(d, rows, "scripts/sweeps/run_manifest.py", sys.argv,
                {"isolation": "fresh-server-per-case", "request_constants": {"seed": 42}})
    finalize(d, [{"loaded": True}, {"loaded": False}])
    print(open(_auto_path(d), encoding="utf-8").read())
