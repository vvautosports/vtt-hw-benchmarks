#!/usr/bin/env python3
"""Run the fixed 3-task battery over a list of model/flag combinations.

Usage: python3 roster_batch.py <spec.json> <rundir>

spec.json is a list of {"name", "path", "flags", "tag"} entries, plus an optional
"env" dict of environment variables prefixed onto the `unsloth run` launch (the
per-family config registry: families that need launch-env or flag workarounds
carry them in the spec, and both are recorded in every result record). First
registry entries: Nemotron's `--speculative-type off` flag, and
UNSLOTH_DISABLE_UNIFIED_MEMORY=1 — studio auto-sets GGML_CUDA_ENABLE_UNIFIED_MEMORY=1
on AMD APUs, which corrupts inference on Strix Halo under b10639-mix (slash-spam /
never-terminating reasoning; diagnosed 2026-08-27, HF unsloth/Qwen3.8-Flash-Next-GGUF
discussion #30).

Each entry gets its OWN output directory (outputs/<name>__<tag>/), which is the
fix for the transcript-trampling defect that cost us run1's quality data on
2026-08-26 and again on the roster run: two passes over the same model previously
overwrote each other's transcripts.

Battery is pinned to the 2026-08-26 param-sweep winner -- thinking / effort=low,
seed=42, max_tokens=8192 -- and reuses TASKS/run_one from sweep_phase1 verbatim so
results are directly comparable to every other run in results/sweeps/.

Restores the GLM baseline serve in a finally block, no matter what.
"""
import json
import os
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)

import sweep_phase1 as sp1  # noqa: E402
import sweep_phase2 as sp2  # noqa: E402

BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
PROFILE = "thinking"
EFFORT = "low"
LOAD_TIMEOUT = 1500          # big multi-shard models load slowly, esp. under disk contention


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def serve_argv():
    p = subprocess.run("ps -eo args | grep '[l]lama-server' | head -1",
                       shell=True, capture_output=True, text=True)
    return p.stdout.strip()


def runtime_build():
    exe = os.path.join(HOME, ".unsloth/llama.cpp/llama-server")
    try:
        p = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=60)
        return ((p.stdout or "") + (p.stderr or "")).strip().splitlines()[0]
    except Exception as e:  # noqa: BLE001
        return f"unknown ({e!r})"


def launch(path, flags, logfile, env=None):
    env_prefix = ""
    if env:
        env_prefix = "env " + " ".join(f"{k}={v}" for k, v in env.items()) + " "
    cmd = (f"setsid nohup {env_prefix}unsloth run --model {path} -H 0.0.0.0 -p 8888 "
           f"{flags} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip())
    spec = json.load(open(sys.argv[1]))
    rundir = sys.argv[2]
    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    out_path = os.path.join(rundir, "results.jsonl")
    build = runtime_build()
    log(f"build={build}  entries={len(spec)}")

    records = []

    def flush():
        with open(out_path, "w") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    try:
        for entry in spec:
            cfg = f"{entry['name']}__{entry.get('tag', 'default')}"
            flags = entry.get("flags", "")
            env = entry.get("env") or {}
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            logfile = os.path.join(rundir, f"serve-{cfg}.log")

            log(f"=== {cfg}  flags={flags!r} env={env!r}")
            if not os.path.exists(entry["path"]):
                log(f"{cfg}: PATH MISSING {entry['path']}")
                records.append({"model": entry["name"], "cfg": cfg, "flags": flags,
                                "env": env, "loaded": False, "error": "path missing",
                                "runtime_build": build})
                flush()
                continue

            sp2.kill_serve()
            launch(entry["path"], flags, logfile, env=env)
            if not sp2.wait_loaded(logfile, timeout=LOAD_TIMEOUT):
                tail = ""
                try:
                    tail = open(logfile).read()[-1500:]
                except OSError:
                    pass
                log(f"{cfg}: LOAD FAILED / timed out")
                records.append({"model": entry["name"], "cfg": cfg, "flags": flags,
                                "env": env, "loaded": False, "runtime_build": build,
                                "serve_log_tail": tail})
                flush()
                continue

            argv = serve_argv()
            log(f"{cfg}: loaded")
            sp1.OUTDIR = outdir
            for task, prompt in sp1.TASKS.items():
                rec = sp1.run_one(task, prompt, PROFILE, sp1.PROFILES[PROFILE], EFFORT)
                rec.update({"model": entry["name"], "cfg": cfg, "flags": flags,
                            "env": env, "loaded": True, "runtime_build": build,
                            "serve_argv": argv})
                records.append(rec)
                flush()
                log(f"  {task}: tps={rec.get('tps_wall')} tok={rec.get('completion_tokens')} "
                    f"err={rec.get('error')}")
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        launch(BASELINE, "", os.path.join(HOME, "unsloth-serve.log"))
        ok = sp2.wait_loaded(os.path.join(HOME, "unsloth-serve.log"), timeout=900)
        log(f"baseline restored healthy={ok}")
        flush()
    log("ROSTER BATCH COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
