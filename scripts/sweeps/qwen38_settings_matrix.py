#!/usr/bin/env python3
"""Qwen3.8-Flash-Next recommended-settings matrix (vendor doc coverage).

Usage: python3 qwen38_settings_matrix.py <rundir>

Covers the unsloth model-doc settings we had not yet graded on the fixed runtime:
the reasoning_effort ladder (doc default is xhigh; only low was graded) and the
recommended Instruct (non-thinking) sampling profile (temp 0.7 / top_p 0.80 /
top_k 20 / presence 1.5).

PROTOCOL: per the 2026-08-27-bleed-order-test finding, multi-request sessions on
b10639 are contaminated by cross-request state bleed — so every (config, task)
cell runs on a FRESH server as the sole request. 4 configs x 3 tasks = 12 loads.
max_tokens stays at the battery's 8192: whether medium/xhigh fits the budget is
itself the measurement (a cap-out means that effort level is unusable here).

cfg = Qwen3.8-Flash-Next__<config>; grade with --layout cfg as usual.
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

MODEL = "/mnt/ai-models/unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf"
BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
LOAD_TIMEOUT = 1500
ENV = {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}

THINKING = {"temperature": 1.0, "top_p": 0.95, "top_k": 20}
INSTRUCT = {"temperature": 0.7, "top_p": 0.80, "top_k": 20, "presence_penalty": 1.5}

# (config tag, profile name, sampling dict, reasoning_effort)
CONFIGS = [
    ("low", "thinking", THINKING, "low"),
    ("medium", "thinking", THINKING, "medium"),
    ("xhigh", "thinking", THINKING, "xhigh"),
    ("instruct", "instruct", INSTRUCT, "none"),
]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def launch(path, logfile):
    env_prefix = "env " + " ".join(f"{k}={v}" for k, v in ENV.items()) + " "
    cmd = (f"setsid nohup {env_prefix}unsloth run --model {path} -H 0.0.0.0 -p 8888 "
           f"> {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def fresh_server(logfile):
    sp2.kill_serve()
    launch(MODEL, logfile)
    return sp2.wait_loaded(logfile, timeout=LOAD_TIMEOUT)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__.strip())
    rundir = sys.argv[1]
    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    out_path = os.path.join(rundir, "results.jsonl")
    records = []

    def flush():
        with open(out_path, "w") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    try:
        for tag, profile_name, profile, effort in CONFIGS:
            cfg = f"Qwen3.8-Flash-Next__{tag}"
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            log(f"=== {cfg}  profile={profile_name} effort={effort}")
            for task in sp1.TASKS:
                logfile = os.path.join(rundir, f"serve-{cfg}-{task}.log")
                if not fresh_server(logfile):
                    log(f"{cfg}/{task}: LOAD FAILED")
                    records.append({"model": "Qwen3.8-Flash-Next", "cfg": cfg,
                                    "task": task, "loaded": False, "env": ENV})
                    flush()
                    continue
                sp1.OUTDIR = outdir
                rec = sp1.run_one(task, sp1.TASKS[task], profile_name, profile, effort)
                rec.update({"model": "Qwen3.8-Flash-Next", "cfg": cfg, "flags": "",
                            "env": ENV, "loaded": True, "request_index": 1,
                            "isolation": "fresh-server-per-task"})
                records.append(rec)
                flush()
                log(f"  {task}: tps={rec.get('tps_wall')} tok={rec.get('completion_tokens')} "
                    f"finish={rec.get('finish_reason')} err={rec.get('error')}")
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        launch(BASELINE, os.path.join(HOME, "unsloth-serve.log"))
        ok = sp2.wait_loaded(os.path.join(HOME, "unsloth-serve.log"), timeout=900)
        log(f"baseline restored healthy={ok}")
        flush()
    log("SETTINGS MATRIX COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
