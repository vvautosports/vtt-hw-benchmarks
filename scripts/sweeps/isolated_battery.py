#!/usr/bin/env python3
"""Run the 3-task battery over a spec of models, fresh server per (model, task).

Usage: python3 isolated_battery.py <spec.json> <rundir>

The bleed-protocol successor to roster_batch.py for QUALITY-grade runs: the
2026-08-27-bleed-order-test showed b10639 leaks state across requests on one
server, so every task here runs as the sole request of its own server process.
Costs one model load per task (3 loads/model); buys uncontaminated grades.
roster_batch.py remains for speed-survey runs where load cost dominates.

Spec entries: {"name", "path", "tag"?, "flags"?, "env"?} — same registry shape
as roster_batch. Battery constants unchanged: thinking / effort=low, seed 42,
max_tokens 8192. cfg = <name>__<tag>; grade with --layout cfg.
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
BASELINE_ENV = {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}
LOAD_TIMEOUT = 1500


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def launch(path, flags, logfile, env=None):
    env_prefix = ""
    if env:
        env_prefix = "env " + " ".join(f"{k}={v}" for k, v in env.items()) + " "
    cmd = (f"setsid nohup {env_prefix}unsloth run --model {path} -H 0.0.0.0 -p 8888 "
           f"{flags} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def fresh_server(path, flags, logfile, env):
    sp2.kill_serve()
    launch(path, flags, logfile, env=env)
    return sp2.wait_loaded(logfile, timeout=LOAD_TIMEOUT)


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip())
    spec = json.load(open(sys.argv[1]))
    rundir = sys.argv[2]
    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    out_path = os.path.join(rundir, "results.jsonl")
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
            log(f"=== {cfg}  flags={flags!r} env={env!r}")
            if not os.path.exists(entry["path"]):
                records.append({"model": entry["name"], "cfg": cfg, "flags": flags,
                                "env": env, "loaded": False, "error": "path missing"})
                flush()
                continue
            for task in sp1.TASKS:
                logfile = os.path.join(rundir, f"serve-{cfg}-{task}.log")
                if not fresh_server(entry["path"], flags, logfile, env):
                    log(f"{cfg}/{task}: LOAD FAILED")
                    tail = ""
                    try:
                        tail = open(logfile).read()[-1000:]
                    except OSError:
                        pass
                    records.append({"model": entry["name"], "cfg": cfg, "task": task,
                                    "flags": flags, "env": env, "loaded": False,
                                    "serve_log_tail": tail})
                    flush()
                    continue
                sp1.OUTDIR = outdir
                rec = sp1.run_one(task, sp1.TASKS[task], "thinking",
                                  sp1.PROFILES["thinking"], "low")
                rec.update({"model": entry["name"], "cfg": cfg, "flags": flags,
                            "env": env, "loaded": True, "request_index": 1,
                            "isolation": "fresh-server-per-task"})
                records.append(rec)
                flush()
                log(f"  {task}: tps={rec.get('tps_wall')} tok={rec.get('completion_tokens')} "
                    f"finish={rec.get('finish_reason')} err={rec.get('error')}")
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        launch(BASELINE, "", os.path.join(HOME, "unsloth-serve.log"), env=BASELINE_ENV)
        ok = sp2.wait_loaded(os.path.join(HOME, "unsloth-serve.log"), timeout=900)
        log(f"baseline restored healthy={ok}")
        flush()
    log("ISOLATED BATTERY COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
