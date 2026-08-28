#!/usr/bin/env python3
"""Can one Strix Halo box host an orchestrator AND a sub-agent at the same time?

Usage: python3 coresidency_test.py <rundir> [pair.json] [--ctx 32768]

The dual-agent architecture assumes two specialised models (a thinker orchestrating, a
coder doing high-volume tool work). The open question is whether that needs two nodes.
Weights say no: GLM-4.7-Flash 33 GiB + Qwen3-Coder-30B 34 GiB = 67 GiB against ~122 GiB
usable. This measures whether it actually holds up.

Three phases:
  1. solo      -- each model alone on its own port, battery run sequentially
  2. coresident-- both loaded, battery run sequentially (memory pressure, no contention)
  3. concurrent-- both loaded, batteries run SIMULTANEOUSLY (the real question)

The t/s delta between phase 2 and 3 is the cost of co-residency under load. Phase 1 vs 2
isolates pure memory pressure from compute contention.

Deliberately bypasses `unsloth run` and drives llama-server directly, because studio binds
one model per instance. That also makes this the first harness code that talks to a plain
llama-server -- the same shim MI50 testing will need, since gfx906 has no supported ROCm
path and that box is on RADV/Vulkan.

NOTE: GGML_CUDA_ENABLE_UNIFIED_MEMORY is simply never set here. Studio sets it and needs
UNSLOTH_DISABLE_UNIFIED_MEMORY=1 to opt out; driving llama-server directly sidesteps the
whole gotcha rather than working around it.
"""
import json
import os
import subprocess
import sys
import threading
import time
import urllib.request

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)

import sweep_phase1 as sp1  # noqa: E402  (canonical TASKS + PROFILES)

SERVER = os.path.join(HOME, ".unsloth/llama.cpp/llama-server")

MODELS = [
    {"name": "GLM-4.7-Flash", "role": "orchestrator", "port": 8801,
     "path": "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"},
    {"name": "Qwen3-Coder-30B-A3B-Instruct", "role": "sub-agent", "port": 8802,
     "path": "/mnt/ai-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/"
             "Qwen3-Coder-30B-A3B-Instruct-UD-Q8_K_XL.gguf"},
]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def mem_used_gib():
    with open("/proc/meminfo") as f:
        info = {k: int(v.split()[0]) for k, v in
                (line.split(":", 1) for line in f)}
    return round((info["MemTotal"] - info["MemAvailable"]) / 1024 / 1024, 1)


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


def launch(model, ctx, logfile):
    cmd = (f"setsid nohup {SERVER} -m {model['path']} --port {model['port']} "
           f"--host 127.0.0.1 -c {ctx} -ngl -1 --flash-attn on --no-context-shift "
           f"--jinja --alias {model['name']} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


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


def run_task(port, name, task, prompt):
    """One battery request against a plain llama-server (no API key)."""
    body = {"model": name, "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 8192, "seed": 42, **sp1.PROFILES["thinking"]}
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"})
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=1200) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        return {"task": task, "error": repr(e)[:200],
                "wall_s": round(time.monotonic() - t0, 1)}
    wall = time.monotonic() - t0
    usage = data.get("usage", {}) or {}
    comp = usage.get("completion_tokens")
    return {"task": task, "wall_s": round(wall, 1),
            "prompt_tokens": usage.get("prompt_tokens"), "completion_tokens": comp,
            "tps_wall": round(comp / wall, 2) if comp and wall > 0 else None,
            "finish_reason": (data.get("choices") or [{}])[0].get("finish_reason")}


def battery(model, out):
    for task, prompt in sp1.TASKS.items():
        rec = run_task(model["port"], model["name"], task, prompt)
        rec.update({"model": model["name"], "role": model["role"]})
        out.append(rec)


def mean_tps(recs, model_name):
    vals = [r["tps_wall"] for r in recs
            if r.get("model") == model_name and r.get("tps_wall")]
    return round(sum(vals) / len(vals), 2) if vals else None


def main():
    argv = sys.argv[1:]
    ctx = 32768
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--ctx":
            i += 1
            ctx = int(argv[i])
        else:
            args.append(argv[i])
        i += 1
    if len(args) not in (1, 2):
        raise SystemExit(__doc__.strip())
    rundir = args[0]
    # Optional pair spec: [{"name","role","port","path"}, ...]. Lets the same driver test a
    # heavier orchestrator (gpt-oss-120b, 61 GiB) without duplicating the harness.
    if len(args) == 2:
        global MODELS
        MODELS = json.load(open(args[1], encoding="utf-8"))
        log(f"pair from {args[1]}: {[m['name'] for m in MODELS]}")
    os.makedirs(rundir, exist_ok=True)
    results = {"ctx": ctx, "phases": {}}

    def save():
        with open(os.path.join(rundir, "coresidency.json"), "w") as f:
            json.dump(results, f, indent=2)

    try:
        # ---- phase 1: solo ----
        log("### PHASE 1: solo")
        solo = []
        for m in MODELS:
            kill_all()
            base = mem_used_gib()
            launch(m, ctx, os.path.join(rundir, f"solo-{m['name']}.log"))
            load = wait_health(m["port"])
            if load is None:
                log(f"{m['name']}: SOLO LOAD FAILED")
                continue
            log(f"{m['name']}: loaded in {load}s, mem {base} -> {mem_used_gib()} GiB")
            battery(m, solo)
            log(f"  mean t/s {mean_tps(solo, m['name'])}")
        results["phases"]["solo"] = solo
        save()

        # ---- phase 2 + 3: both loaded ----
        log("### PHASE 2/3: loading BOTH")
        kill_all()
        before = mem_used_gib()
        loads = {}
        for m in MODELS:
            launch(m, ctx, os.path.join(rundir, f"cores-{m['name']}.log"))
            loads[m["name"]] = wait_health(m["port"])
            log(f"  {m['name']}: health={loads[m['name']]}s  mem now {mem_used_gib()} GiB")
        results["load_seconds"] = loads
        results["mem_before_gib"] = before
        results["mem_both_loaded_gib"] = mem_used_gib()

        if any(v is None for v in loads.values()):
            log("CO-RESIDENCY FAILED: not both healthy — this is the answer.")
            results["coresident"] = False
            save()
            return 0
        results["coresident"] = True
        log(f"BOTH HEALTHY. mem {before} -> {results['mem_both_loaded_gib']} GiB")

        log("### PHASE 2: co-resident, sequential")
        seq = []
        for m in MODELS:
            battery(m, seq)
            log(f"  {m['name']} mean t/s {mean_tps(seq, m['name'])}")
        results["phases"]["coresident_sequential"] = seq
        save()

        log("### PHASE 3: co-resident, CONCURRENT")
        con = []
        lock = threading.Lock()

        def worker(m):
            local = []
            battery(m, local)
            with lock:
                con.extend(local)

        threads = [threading.Thread(target=worker, args=(m,)) for m in MODELS]
        t0 = time.monotonic()
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        results["concurrent_wall_s"] = round(time.monotonic() - t0, 1)
        results["phases"]["coresident_concurrent"] = con
        save()

        log("### SUMMARY")
        for m in MODELS:
            n = m["name"]
            s, q, c = (mean_tps(solo, n), mean_tps(seq, n), mean_tps(con, n))
            pen = f"{round((c / q - 1) * 100, 1)}%" if q and c else "n/a"
            log(f"  {n:<32} solo={s} coresident={q} concurrent={c}  contention={pen}")
            results.setdefault("summary", {})[n] = {
                "solo_tps": s, "coresident_tps": q, "concurrent_tps": c,
                "contention_pct": pen}
        save()
    finally:
        log("restoring GLM baseline via studio")
        kill_all()
        subprocess.Popen(["bash", "-c",
                          "setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run "
                          "--model " + MODELS[0]["path"] + " -H 0.0.0.0 -p 8888 "
                          f"> {HOME}/unsloth-serve.log 2>&1 < /dev/null &"])
        save()
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")
    log("CO-RESIDENCY TEST COMPLETE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
