#!/usr/bin/env python3
"""Overnight roster validation — vtt-hw-benchmarks issue #10.

Runs entirely on the Framework with no Claude session: download queue models to
/mnt/ai-models, then for each: serve via `unsloth run`, arch/load check, fixed
battery at thinking/low (the sweep winner), record JSONL, kill (SIGKILL — this
llama-server ignores SIGTERM). Restores the GLM-4.7-Flash baseline serve at the
end no matter what. Results: ~/overnight-2026-08-26/results.jsonl (+ outputs/,
log). Harvest next session into results/sweeps/.
"""
import glob, json, os, re, subprocess, sys, time

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)
import sweep_phase1
from sweep_phase1 import TASKS, PROFILES, run_one
from sweep_phase2 import kill_serve, refresh_key, wait_loaded  # reuse ops helpers

RUN_DIR = os.path.join(HOME, "overnight-2026-08-26")
OUT = os.path.join(RUN_DIR, "results.jsonl")
DONE = os.path.join(RUN_DIR, "DONE")
BASELINE_LOG = os.path.join(HOME, "unsloth-serve.log")
BASELINE_MODEL = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"

# Queue per issue #10 (downloads ~226G; 529G free pre-run)
MODELS = [
    {"name": "Qwen3.8-27B", "repo": "unsloth/Qwen3.8-27B-GGUF",
     "include": "Qwen3.8-27B-UD-Q8_K_XL.gguf", "dir": "Qwen3.8-27B-GGUF"},
    {"name": "gemma-4-26B-A4B-it", "repo": "unsloth/gemma-4-26B-A4B-it-GGUF",
     "include": "*UD-Q8_K_XL*.gguf", "dir": "gemma-4-26B-A4B-it-GGUF"},
    {"name": "Nemotron-3.5-Lightning-30B-A3B",
     "repo": "unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF",
     "include": "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-UD-Q8_K_XL.gguf",
     "dir": "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF"},
    {"name": "gemma-4-31B-it", "repo": "unsloth/gemma-4-31B-it-GGUF",
     "include": "*UD-Q8_K_XL*.gguf", "dir": "gemma-4-31B-it-GGUF"},
    {"name": "MiniMax-M3", "repo": "unsloth/MiniMax-M3-GGUF",
     "include": "UD-Q3_K_XL/*", "dir": "MiniMax-M3-GGUF"},
]

log_f = None
def log(msg):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    log_f.write(line + "\n"); log_f.flush()


def download(m):
    dest = f"/mnt/ai-models/unsloth/{m['dir']}"
    cmd = [os.path.join(HOME, ".local/bin/hf"), "download", m["repo"],
           "--include", m["include"], "--local-dir", dest]
    log(f"download {m['repo']} ({m['include']}) -> {dest}")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=4 * 3600)
    if r.returncode != 0:
        log(f"DOWNLOAD FAILED {m['name']}: {r.stderr[-400:]}")
        return None
    parts = sorted(glob.glob(f"{dest}/**/*.gguf", recursive=True))
    parts = [p for p in parts if "mmproj" not in os.path.basename(p).lower()]
    return parts[0] if parts else None


def gtt_used():
    try:
        vals = [int(open(p).read()) for p in
                glob.glob("/sys/class/drm/card*/device/mem_info_gtt_used")]
        return max(vals) // (1 << 20)  # MiB
    except Exception:
        return None


def launch_model(path, logfile):
    cmd = (f"setsid nohup unsloth run --model {path} -H 0.0.0.0 -p 8888 "
           f"> {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def test_model(out, m, gguf):
    logfile = os.path.join(RUN_DIR, f"serve-{m['name']}.log")
    kill_serve()
    launch_model(gguf, logfile)
    if not wait_loaded(logfile, timeout=900):
        tail = open(logfile).read()[-500:] if os.path.exists(logfile) else ""
        out.write(json.dumps({"model": m["name"], "gguf": gguf, "loaded": False,
                              "serve_log_tail": tail}) + "\n")
        out.flush()
        log(f"{m['name']}: LOAD FAILED (arch unsupported or crash)")
        return
    sweep_phase1.MODEL = os.path.splitext(os.path.basename(gguf))[0].split("-00001")[0]
    outdir = os.path.join(RUN_DIR, "outputs", m["name"])
    os.makedirs(outdir, exist_ok=True)
    sweep_phase1.OUTDIR = outdir
    log(f"{m['name']}: loaded (gtt_used={gtt_used()}MiB), running battery")
    for task, prompt in TASKS.items():
        rec = run_one(task, prompt, "thinking", PROFILES["thinking"], "low")
        rec.update({"model": m["name"], "gguf": gguf, "loaded": True,
                    "gtt_used_mib": gtt_used()})
        out.write(json.dumps(rec) + "\n"); out.flush()
        log(f"  {task}: wall={rec.get('wall_s')} tok={rec.get('completion_tokens')} "
            f"err={rec.get('error')}")


def main():
    global log_f
    smoke = "--smoke" in sys.argv
    os.makedirs(RUN_DIR, exist_ok=True)
    log_f = open(os.path.join(RUN_DIR, "log.txt"), "a")
    if os.path.exists(DONE):
        os.remove(DONE)
    log(f"{'SMOKE' if smoke else 'overnight'} run start; cmdline GTT args active: "
        f"{'gttsize' in open('/proc/cmdline').read()}")
    try:
        with open(OUT, "a") as out:
            staged = []
            if smoke:
                # validate hf download flags/paths with a KB-sized file
                r = subprocess.run(
                    [os.path.join(HOME, ".local/bin/hf"), "download",
                     "unsloth/Qwen3.8-27B-GGUF", "--include", "config.json",
                     "--local-dir", "/mnt/ai-models/unsloth/Qwen3.8-27B-GGUF"],
                    capture_output=True, text=True, timeout=300)
                log(f"smoke download rc={r.returncode} "
                    f"ok={os.path.exists('/mnt/ai-models/unsloth/Qwen3.8-27B-GGUF/config.json')}")
                # full serve->battery->restore cycle on a small on-disk model
                staged = [({"name": "SMOKE-Qwen3.5-9B"},
                           "/mnt/ai-models/lmstudio-community/Qwen3.5-9B-GGUF/Qwen3.5-9B-Q4_K_M.gguf")]
            else:
                for m in MODELS:
                    gguf = download(m)
                    if gguf:
                        staged.append((m, gguf))
                        log(f"staged {m['name']}: {gguf}")
                log(f"downloads done: {len(staged)}/{len(MODELS)} staged")
            for m, gguf in staged:
                try:
                    test_model(out, m, gguf)
                except Exception as e:
                    log(f"{m['name']}: EXCEPTION {e!r}")
    finally:
        log("restoring GLM baseline serve")
        kill_serve()
        launch_model(BASELINE_MODEL, BASELINE_LOG)
        ok = wait_loaded(BASELINE_LOG, timeout=600)
        log(f"baseline restored healthy={ok}")
    with open(DONE, "w") as f:
        f.write("done\n")
    log("OVERNIGHT RUN COMPLETE")


if __name__ == "__main__":
    main()
