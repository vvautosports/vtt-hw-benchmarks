#!/usr/bin/env python3
"""Discriminating test for the b10639 cross-request state-bleed hypothesis.

Usage: python3 bleed_order_test.py <rundir>

Background (2026-08-27-b10639-rebaseline-batch, caveat cross_request_bleed_hypothesis):
with the battery run in dict order (reasoning -> code -> summarize) on one loaded
server, three failures shared a phantom-prior-turn shape — MiniMax-M2.5's summarize
answer addressed parse_ranges (the PREVIOUS request's topic), and two Qwen3-family
models claimed to have already written code they never emitted.

Two variants per model, same request config as every other run (thinking / effort
low, seed 42, max_tokens 8192):

  reversed   one server, tasks in REVERSED order (summarize -> code -> reasoning).
             If bleed: failures should track POSITION/predecessor, not the task —
             e.g. a task that failed as request 2 of the forward order should pass
             as request 1 here, and failure content should reference the new
             predecessor's topic.
  isolated   fresh server (kill + relaunch) before EVERY task, run as the sole
             request. If bleed: all tasks pass; a task that still fails in
             isolation is a genuine model/template defect, not leakage.

Models: the three exhibiting the defect. cfg = <model>__<variant> so
grade_sweep.py --layout cfg grades it like any batch. Each record carries
request_index. GLM baseline restored in a finally block.
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
LOAD_TIMEOUT = 1500
ENV = {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}

MODELS = [
    ("Qwen3.6-35B-A3B-MTP",
     "/mnt/ai-models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf"),
    ("Qwen3-Coder-Next",
     "/mnt/ai-models/unsloth/Qwen3-Coder-Next-GGUF/Qwen3-Coder-Next-UD-Q8_K_XL-00001-of-00003.gguf"),
    ("MiniMax-M2.5",
     "/mnt/ai-models/unsloth/MiniMax-M2.5-GGUF/MiniMax-M2.5-UD-Q3_K_XL-00001-of-00004.gguf"),
]

REVERSED_ORDER = ["summarize", "code", "reasoning"]
FORWARD_ORDER = list(sp1.TASKS)  # reasoning, code, summarize


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def launch(path, logfile):
    env_prefix = "env " + " ".join(f"{k}={v}" for k, v in ENV.items()) + " "
    cmd = (f"setsid nohup {env_prefix}unsloth run --model {path} -H 0.0.0.0 -p 8888 "
           f"> {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def fresh_server(path, logfile):
    sp2.kill_serve()
    launch(path, logfile)
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

    def run_task(task, cfg, model_name, idx):
        rec = sp1.run_one(task, sp1.TASKS[task], PROFILE, sp1.PROFILES[PROFILE], EFFORT)
        rec.update({"model": model_name, "cfg": cfg, "flags": "", "env": ENV,
                    "loaded": True, "request_index": idx})
        records.append(rec)
        flush()
        log(f"  [{idx}] {task}: tps={rec.get('tps_wall')} tok={rec.get('completion_tokens')} "
            f"err={rec.get('error')}")

    try:
        for name, path in MODELS:
            # Variant 1: reversed order, one server
            cfg = f"{name}__reversed"
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            logfile = os.path.join(rundir, f"serve-{cfg}.log")
            log(f"=== {cfg}")
            if not fresh_server(path, logfile):
                log(f"{cfg}: LOAD FAILED")
                records.append({"model": name, "cfg": cfg, "loaded": False, "env": ENV})
                flush()
                continue
            sp1.OUTDIR = outdir
            for i, task in enumerate(REVERSED_ORDER, 1):
                run_task(task, cfg, name, i)

            # Variant 2: isolated — fresh server per task, forward task naming
            cfg = f"{name}__isolated"
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            log(f"=== {cfg}")
            for task in FORWARD_ORDER:
                logfile = os.path.join(rundir, f"serve-{cfg}-{task}.log")
                if not fresh_server(path, logfile):
                    log(f"{cfg}/{task}: LOAD FAILED")
                    records.append({"model": name, "cfg": cfg, "task": task,
                                    "loaded": False, "env": ENV})
                    flush()
                    continue
                sp1.OUTDIR = outdir
                run_task(task, cfg, name, 1)
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        launch(BASELINE, os.path.join(HOME, "unsloth-serve.log"))
        ok = sp2.wait_loaded(os.path.join(HOME, "unsloth-serve.log"), timeout=900)
        log(f"baseline restored healthy={ok}")
        flush()
    log("BLEED ORDER TEST COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
