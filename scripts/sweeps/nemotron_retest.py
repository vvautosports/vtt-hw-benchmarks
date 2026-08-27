#!/usr/bin/env python3
"""Nemotron-3.5-Lightning HTTP-500 retest matrix (2026-08-27).

Overnight run2 returned HTTP 500 on reasoning and code while summarize survived
but ran 45% slower AND failed its quality grade. Nemotron is the only roster
model on the MTP path: `unsloth run` auto-selected
  --parallel 4 --spec-type draft-mtp --spec-draft-n-max 2   at -c 1048576
and the Qwen MTP docs state -np > 1 is not supported with MTP.

This isolates the two suspects, one variable at a time:
  spec_off_np4  --speculative-type off --parallel 4  -> is MTP the cause?
  spec_mtp_np1  --speculative-type mtp --parallel 1  -> is the -np>1 conflict the cause?

Both pass -> the COMBINATION is at fault. Neither -> suspect the 1M context and
rerun with -c 202752 (the GLM baseline's window).

Each config gets its own output dir: no transcript trampling (the defect that
cost us run1's quality data). Restores the GLM baseline in a finally block.
"""
import json
import os
import subprocess
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)

import sweep_phase1 as sp1  # noqa: E402
import sweep_phase2 as sp2  # noqa: E402

MODEL_PATH = ("/mnt/ai-models/unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF/"
              "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-UD-Q8_K_XL.gguf")
BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"

RUNDIR = os.path.join(HOME, "nemotron-retest-2026-08-27")
OUT = os.path.join(RUNDIR, "results.jsonl")

PROFILE = "thinking"
EFFORT = "low"

CONFIGS = [
    ("spec_off_np4", "--speculative-type off --parallel 4"),
    ("spec_mtp_np1", "--speculative-type mtp --parallel 1"),
]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def serve_cmdline():
    """The llama-server argv actually in use — evidence of the flags that landed."""
    p = subprocess.run("ps -eo args | grep '[l]lama-server' | head -1",
                       shell=True, capture_output=True, text=True)
    return p.stdout.strip()


def launch(model_path, extra_flags, logfile):
    cmd = (f"setsid nohup unsloth run --model {model_path} -H 0.0.0.0 -p 8888 "
           f"{extra_flags} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def main():
    os.makedirs(RUNDIR, exist_ok=True)
    records = []
    try:
        for name, flags in CONFIGS:
            outdir = os.path.join(RUNDIR, name)
            os.makedirs(outdir, exist_ok=True)
            logfile = os.path.join(RUNDIR, f"serve-{name}.log")

            log(f"=== {name} :: {flags}")
            sp2.kill_serve()
            launch(MODEL_PATH, flags, logfile)
            if not sp2.wait_loaded(logfile, timeout=900):
                log(f"{name}: LOAD FAILED / timed out")
                records.append({"config": name, "flags": flags, "loaded": False})
                continue

            argv = serve_cmdline()
            log(f"{name}: loaded. serve argv: {argv[:400]}")
            sp1.OUTDIR = outdir

            for task, prompt in sp1.TASKS.items():
                rec = sp1.run_one(task, prompt, PROFILE, sp1.PROFILES[PROFILE], EFFORT)
                rec.update({"config": name, "flags": flags, "loaded": True,
                            "serve_argv": argv, "model": "Nemotron-3.5-Lightning-30B-A3B"})
                records.append(rec)
                log(f"  {task}: wall={rec.get('wall_s')} tok={rec.get('completion_tokens')} "
                    f"tps={rec.get('tps_wall')} err={rec.get('error')}")
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        launch(BASELINE, "", os.path.join(HOME, "unsloth-serve.log"))
        ok = sp2.wait_loaded(os.path.join(HOME, "unsloth-serve.log"), timeout=600)
        log(f"baseline restored healthy={ok}")
        with open(OUT, "w") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")
    log("NEMOTRON RETEST COMPLETE")
    with open(os.path.join(RUNDIR, "DONE"), "w") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
