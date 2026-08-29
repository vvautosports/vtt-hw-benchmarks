#!/usr/bin/env python3
"""Framework (Linux) leg of the Windows-vs-Linux A/B — Nemotron-3.5 Q8, direct llama-server.

Usage: python3 ab_nemotron_framework.py <rundir>

The G1a leg already exists: 2026-08-28-g1a-coresidency phase 1 (solo) ran this exact
model on the DIRECT llama-server path, ctx 16384, thinking/low, seed 42 -> 30.88 t/s
mean over the 3-task battery. This runs the byte-identical config on the framework so
the delta is OS/driver, not serving path. Both boxes verified on the same build:
0.3.0-dev (build 10639, commit 2a36554fc), Clang 23, Linux vs Windows.

Launch flags mirror g1a_coresidency.py launch() exactly.
"""
import json
import os
import subprocess
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)
from sweep_phase1 import TASKS, PROFILES  # noqa: E402

SERVER = os.path.join(HOME, ".unsloth/llama.cpp/llama-server")
GGUF = ("/mnt/ai-models/unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF/"
        "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-UD-Q8_K_XL.gguf")
NAME = "NVIDIA-Nemotron-3.5-Lightning-30B-A3B"
PORT = 8801
CTX = 16384


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def kill_all():
    subprocess.run(["bash", "-c", "pkill -f '[l]lama-server' ; pkill -f '[u]nsloth run'"],
                   check=False)
    for _ in range(30):
        r = subprocess.run(["bash", "-c", "pgrep -f '[l]lama-server'"], check=False)
        if r.returncode != 0:
            return True
        time.sleep(2)
    subprocess.run(["bash", "-c", "pkill -9 -f '[l]lama-server'"], check=False)
    time.sleep(3)
    return False


def wait_health(port, timeout=1200):
    t0 = time.monotonic()
    while time.monotonic() - t0 < timeout:
        try:
            with urllib.request.urlopen(
                    f"http://127.0.0.1:{port}/health", timeout=5) as resp:
                if json.loads(resp.read()).get("status") == "ok":
                    return round(time.monotonic() - t0, 1)
        except Exception:
            pass
        time.sleep(5)
    return None


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__.strip())
    rundir = sys.argv[1]
    cfg = f"framework-direct__{NAME}"
    outdir = os.path.join(rundir, "outputs", cfg)
    os.makedirs(outdir, exist_ok=True)
    records = []
    try:
        kill_all()
        logfile = os.path.join(rundir, "serve.log")
        cmd = (f"setsid nohup {SERVER} -m {GGUF} --port {PORT} --host 127.0.0.1 "
               f"-c {CTX} -ngl -1 --flash-attn on --no-context-shift --jinja "
               f"--alias {NAME} > {logfile} 2>&1 < /dev/null &")
        subprocess.Popen(["bash", "-c", cmd])
        load = wait_health(PORT)
        if load is None:
            raise SystemExit("LOAD FAILED")
        log(f"loaded in {load}s")
        for task, prompt in TASKS.items():
            body = {"model": NAME, "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": 8192, "seed": 42, "reasoning_effort": "low",
                    **PROFILES["thinking"]}
            req = urllib.request.Request(
                f"http://127.0.0.1:{PORT}/v1/chat/completions",
                data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json"})
            t0 = time.monotonic()
            with urllib.request.urlopen(req, timeout=1800) as resp:
                data = json.loads(resp.read())
            wall = time.monotonic() - t0
            choice = (data.get("choices") or [{}])[0]
            msg = choice.get("message", {}) or {}
            content = msg.get("content") or ""
            reasoning = msg.get("reasoning_content") or ""
            usage = data.get("usage", {}) or {}
            timings = data.get("timings", {}) or {}
            comp = usage.get("completion_tokens")
            with open(os.path.join(outdir, f"{task}--thinking--low.txt"),
                      "w", encoding="utf-8") as f:
                if reasoning:
                    f.write("=== REASONING ===\n" + reasoning + "\n\n")
                f.write("=== CONTENT ===\n" + content + "\n\n")
            rec = {"task": task, "profile": "thinking", "effort": "low", "cfg": cfg,
                   "model": NAME, "host": "framework-linux", "ctx": CTX,
                   "wall_s": round(wall, 1),
                   "prompt_tokens": usage.get("prompt_tokens"),
                   "completion_tokens": comp,
                   "tps_wall": round(comp / wall, 2) if comp and wall > 0 else None,
                   "tps_server": timings.get("predicted_per_second"),
                   "content_chars": len(content),
                   "finish_reason": choice.get("finish_reason"), "load_s": load}
            records.append(rec)
            log(f"  {task}: tps_wall={rec['tps_wall']} tps_server={rec['tps_server']} "
                f"wall={rec['wall_s']}s")
    finally:
        kill_all()
        with open(os.path.join(rundir, "results.jsonl"), "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")
    vals = [r["tps_wall"] for r in records if r.get("tps_wall")]
    if vals:
        log(f"MEAN t/s wall: {round(sum(vals)/len(vals), 2)}  (G1a direct leg: 30.88)")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")
    log("AB FRAMEWORK LEG COMPLETE")


if __name__ == "__main__":
    main()
