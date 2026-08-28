#!/usr/bin/env python3
"""Qwen3.8-Flash-Next quant ladder: UD-Q4_K_XL vs UD-IQ4_XS vs UD-Q2_K_XL.

Usage: python3 qwen38_quant_ladder.py <rundir>

First rung of the Track-2 quant axis (vendor KLD context: Q4_K_XL 93.5% same-top,
IQ4_XS 91.1%, Q2_K_XL 85.2%). Battery config: thinking / effort=low, seed 42,
max_tokens 8192 — identical to every other run. Fresh server per (quant, task)
per the bleed protocol (9 loads). On this bandwidth-bound APU the speed question
is as interesting as the quality one: smaller active bytes should mean faster.

Quant shard files are globbed (first shard *-00001-of-*.gguf) so shard counts
don't need hardcoding. cfg = Qwen3.8-Flash-Next__<quant>.
"""
import glob
import json
import os
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)

import sweep_phase1 as sp1  # noqa: E402
import sweep_phase2 as sp2  # noqa: E402

REPO_DIR = "/mnt/ai-models/unsloth/Qwen3.8-Flash-Next-GGUF"
BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
QUANTS = ["UD-Q4_K_XL", "UD-IQ4_XS", "UD-Q2_K_XL"]
LOAD_TIMEOUT = 1500
ENV = {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def first_shard(quant):
    hits = sorted(glob.glob(os.path.join(REPO_DIR, quant, "*-00001-of-*.gguf")))
    if hits:
        return hits[0]
    hits = sorted(glob.glob(os.path.join(REPO_DIR, quant, "*.gguf")))
    return hits[0] if hits else None


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

    try:
        for quant in QUANTS:
            cfg = f"Qwen3.8-Flash-Next__{quant}"
            path = first_shard(quant)
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            log(f"=== {cfg}  path={path}")
            if not path:
                records.append({"model": "Qwen3.8-Flash-Next", "cfg": cfg,
                                "loaded": False, "error": "quant files missing",
                                "env": ENV})
                flush()
                continue
            size_gb = round(sum(os.path.getsize(p) for p in
                                glob.glob(os.path.join(REPO_DIR, quant, "*.gguf"))) / 1e9)
            for task in sp1.TASKS:
                logfile = os.path.join(rundir, f"serve-{cfg}-{task}.log")
                if not fresh_server(path, logfile):
                    log(f"{cfg}/{task}: LOAD FAILED")
                    records.append({"model": "Qwen3.8-Flash-Next", "cfg": cfg,
                                    "task": task, "loaded": False, "env": ENV,
                                    "quant": quant, "size_gb": size_gb})
                    flush()
                    continue
                sp1.OUTDIR = outdir
                rec = sp1.run_one(task, sp1.TASKS[task], "thinking",
                                  sp1.PROFILES["thinking"], "low")
                rec.update({"model": "Qwen3.8-Flash-Next", "cfg": cfg, "flags": "",
                            "env": ENV, "loaded": True, "quant": quant,
                            "size_gb": size_gb, "request_index": 1,
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
    log("QUANT LADDER COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
