#!/usr/bin/env python3
"""Windows co-residency probe for the HP G1a: can it host two models at once?

Usage: python g1a_coresidency.py <rundir> [--ctx 16384]

Windows counterpart of coresidency_test.py (which is POSIX: pkill/setsid//proc/meminfo).
Same three phases — solo, coresident-sequential, coresident-concurrent — and the same
answer capture so correctness under contention is graded, not assumed:

  py scripts/utils/grade_sweep.py <rundir> results --layout cfg

Pair: NVIDIA-Nemotron-3.5 Q8 (36.0 GiB, thinker) + gemma-4-26B Q8 (25.7 GiB, sub-agent)
= 61.7 GiB weights against ~96 GiB Windows-visible RAM. The plan's GLM+Coder pair is not
in this box's HF cache; this is the same architectural question with local models.
NEVER attempt a heavier pair here — Windows caps usable RAM at ~96 GB.

Drives llama-server.exe (the studio's ROCm gfx1151 build) directly on 8801/8802 —
studio binds one model per instance, and a direct launch never sets
GGML_CUDA_ENABLE_UNIFIED_MEMORY, so the b10639 env gotcha does not arise at all.
"""
import ctypes
import json
import os
import subprocess
import sys
import threading
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sweep_phase1 import TASKS, PROFILES  # noqa: E402

SERVER = os.path.expanduser(r"~\.unsloth\llama.cpp\build\bin\Release\llama-server.exe")
HUB = os.path.expanduser(r"~\.cache\huggingface\hub")

MODELS = [
    {"name": "NVIDIA-Nemotron-3.5-Lightning-30B-A3B", "role": "orchestrator", "port": 8801,
     "path": os.path.join(HUB, "models--unsloth--NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF",
                          "snapshots", "f2d3fe3694501008786e81e5f20360cbf715496a",
                          "NVIDIA-Nemotron-3.5-Lightning-30B-A3B-UD-Q8_K_XL.gguf")},
    {"name": "gemma-4-26B-A4B-it", "role": "sub-agent", "port": 8802,
     "path": None},  # resolved below — snapshot hash looked up at runtime
]


def resolve_gemma():
    root = os.path.join(HUB, "models--unsloth--gemma-4-26B-A4B-it-GGUF", "snapshots")
    for snap in os.listdir(root):
        p = os.path.join(root, snap, "gemma-4-26B-A4B-it-UD-Q8_K_XL.gguf")
        if os.path.exists(p):
            return p
    raise SystemExit("gemma-4-26B Q8 gguf not found under " + root)


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def mem_used_gib():
    class MEMORYSTATUSEX(ctypes.Structure):
        _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong),
                    ("ullTotalPhys", ctypes.c_ulonglong), ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong),
                    ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong),
                    ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]
    st = MEMORYSTATUSEX()
    st.dwLength = ctypes.sizeof(st)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(st))
    return round((st.ullTotalPhys - st.ullAvailPhys) / (1024 ** 3), 1)


def kill_all():
    subprocess.run(["taskkill", "/IM", "llama-server.exe", "/F", "/T"],
                   capture_output=True, check=False)
    for _ in range(15):
        r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq llama-server.exe"],
                           capture_output=True, text=True, check=False)
        if "llama-server.exe" not in r.stdout:
            return True
        time.sleep(2)
    return False


def launch(model, ctx, logfile):
    cmd = [SERVER, "-m", model["path"], "--port", str(model["port"]),
           "--host", "127.0.0.1", "-c", str(ctx), "-ngl", "-1",
           "--flash-attn", "on", "--no-context-shift", "--jinja",
           "--alias", model["name"]]
    subprocess.Popen(cmd, stdout=open(logfile, "w", encoding="utf-8"),
                     stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                     creationflags=0x00000008 | 0x00000200)


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


def run_task(port, name, task, prompt, outdir):
    body = {"model": name, "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 8192, "seed": 42, "reasoning_effort": "low",
            **PROFILES["thinking"]}
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"})
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=1800) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        return {"task": task, "error": repr(e)[:200],
                "wall_s": round(time.monotonic() - t0, 1)}
    wall = time.monotonic() - t0
    choice = (data.get("choices") or [{}])[0]
    msg = choice.get("message", {}) or {}
    content = msg.get("content") or ""
    reasoning = msg.get("reasoning_content") or ""
    usage = data.get("usage", {}) or {}
    timings = data.get("timings", {}) or {}
    comp = usage.get("completion_tokens")
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, f"{task}--thinking--low.txt"),
              "w", encoding="utf-8") as f:
        if reasoning:
            f.write("=== REASONING ===\n" + reasoning + "\n\n")
        f.write("=== CONTENT ===\n" + content + "\n\n")
    return {"task": task, "wall_s": round(wall, 1),
            "prompt_tokens": usage.get("prompt_tokens"), "completion_tokens": comp,
            "tps_wall": round(comp / wall, 2) if comp and wall > 0 else None,
            "tps_server": timings.get("predicted_per_second"),
            "content_chars": len(content),
            "finish_reason": choice.get("finish_reason")}


def battery(model, out, phase, rundir):
    cfg = f"{phase}__{model['name']}"
    outdir = os.path.join(rundir, "outputs", cfg)
    for task, prompt in TASKS.items():
        rec = run_task(model["port"], model["name"], task, prompt, outdir)
        rec.update({"model": model["name"], "role": model["role"], "phase": phase,
                    "cfg": cfg, "profile": "thinking", "effort": "low"})
        out.append(rec)


def mean_tps(recs, model_name):
    vals = [r["tps_wall"] for r in recs
            if r.get("model") == model_name and r.get("tps_wall")]
    return round(sum(vals) / len(vals), 2) if vals else None


def main():
    argv = sys.argv[1:]
    ctx = 16384
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--ctx":
            i += 1
            ctx = int(argv[i])
        else:
            args.append(argv[i])
        i += 1
    if len(args) != 1:
        raise SystemExit(__doc__.strip())
    rundir = args[0]
    MODELS[1]["path"] = resolve_gemma()
    os.makedirs(rundir, exist_ok=True)
    results = {"ctx": ctx, "host": "hp-g1a-windows", "phases": {}}

    def save():
        with open(os.path.join(rundir, "coresidency.json"), "w") as f:
            json.dump(results, f, indent=2)
        with open(os.path.join(rundir, "results.jsonl"), "w", encoding="utf-8") as f:
            for recs in results["phases"].values():
                for r in recs:
                    f.write(json.dumps(r) + "\n")

    try:
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
            battery(m, solo, "solo", rundir)
            log(f"  mean t/s {mean_tps(solo, m['name'])}")
        results["phases"]["solo"] = solo
        save()

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
            battery(m, seq, "coresident_sequential", rundir)
            log(f"  {m['name']} mean t/s {mean_tps(seq, m['name'])}")
        results["phases"]["coresident_sequential"] = seq
        save()

        log("### PHASE 3: co-resident, CONCURRENT")
        con = []
        lock = threading.Lock()

        def worker(m):
            local = []
            battery(m, local, "coresident_concurrent", rundir)
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
            log(f"  {n:<40} solo={s} coresident={q} concurrent={c}  contention={pen}")
            results.setdefault("summary", {})[n] = {
                "solo_tps": s, "coresident_tps": q, "concurrent_tps": c,
                "contention_pct": pen}
        save()
    finally:
        log("killing servers (box left idle)")
        kill_all()
        save()
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")
    log("G1A CO-RESIDENCY COMPLETE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
