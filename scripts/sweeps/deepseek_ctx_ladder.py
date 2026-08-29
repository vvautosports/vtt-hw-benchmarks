#!/usr/bin/env python3
"""DeepSeek-V4-Flash context ceiling probe — how far past the 16384 pin can it go?

Usage: python3 deepseek_ctx_ladder.py <rundir>

The day-one run pinned --max-seq-length 16384 "for load safety" (97 GiB of weights leave
~25 GiB of KV budget on the ~122 GiB box); the true ceiling was never measured. This
climbs the ladder: for each ctx, fresh studio serve, verify the SPAWNED llama-server
actually got the ctx (unsloth run swallows unknown flags — a started server proves
nothing, so the serve log's llama-server command line is checked), then prove serving
with a tiny greedy completion. Stops at the first rung that fails to load or serve.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)
import sweep_phase1 as sp1  # noqa: E402
import sweep_phase2 as sp2  # noqa: E402

GGUF = ("/mnt/ai-models/unsloth/DeepSeek-V4-Flash-0731-GGUF/UD-IQ3_XXS/"
        "DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00001-of-00004.gguf")
BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
LADDER = [24576, 32768, 49152, 65536, 98304]
LOAD_TIMEOUT = 2400  # 97 GiB of weights — day-one loads took several minutes


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def mem_available_gib():
    with open("/proc/meminfo") as f:
        info = {k: int(v.split()[0]) for k, v in (line.split(":", 1) for line in f)}
    return round(info["MemAvailable"] / 1024 / 1024, 1)


def launch(ctx, logfile):
    cmd = (f"setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run "
           f"--model {GGUF} -H 0.0.0.0 -p 8888 --disable-tools "
           f"--max-seq-length {ctx} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def spawned_ctx(logfile):
    """The -c the studio actually passed to llama-server, from the serve log."""
    try:
        text = open(logfile, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    m = re.findall(r"llama-server[^\n]*?\s-c\s+(\d+)", text)
    return int(m[-1]) if m else None


def tiny_completion():
    key = sp1.KEY
    body = {"model": "x", "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
            "max_tokens": 16, "temperature": 0.0, "seed": 42}
    # resolve loaded model alias
    req = urllib.request.Request("http://localhost:8888/v1/models",
                                 headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read())
    for m in data.get("data", []):
        if m.get("loaded"):
            body["model"] = m["id"]
    req = urllib.request.Request("http://localhost:8888/v1/chat/completions",
                                 data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json",
                                          "Authorization": "Bearer " + key})
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read())
    msg = (data.get("choices") or [{}])[0].get("message", {}) or {}
    return {"wall_s": round(time.monotonic() - t0, 1),
            "content": (msg.get("content") or "")[:80]}


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__.strip())
    rundir = sys.argv[1]
    os.makedirs(rundir, exist_ok=True)
    results = []

    def save():
        with open(os.path.join(rundir, "ladder.json"), "w") as f:
            json.dump(results, f, indent=2)

    try:
        for ctx in LADDER:
            logfile = os.path.join(rundir, f"serve-ctx{ctx}.log")
            sp2.kill_serve()
            mem_before = mem_available_gib()
            log(f"=== ctx {ctx}: launching (MemAvailable {mem_before} GiB)")
            launch(ctx, logfile)
            t0 = time.monotonic()
            ok = sp2.wait_loaded(logfile, timeout=LOAD_TIMEOUT)
            load_s = round(time.monotonic() - t0, 1)
            rec = {"ctx_requested": ctx, "loaded": bool(ok), "load_s": load_s,
                   "ctx_spawned": spawned_ctx(logfile),
                   "mem_available_before_gib": mem_before,
                   "mem_available_after_gib": mem_available_gib()}
            if not ok:
                tail = ""
                try:
                    tail = open(logfile, encoding="utf-8", errors="replace").read()[-800:]
                except OSError:
                    pass
                rec["serve_log_tail"] = tail
                results.append(rec)
                save()
                log(f"ctx {ctx}: LOAD/SERVE FAILED after {load_s}s — ceiling found, stopping")
                break
            try:
                rec["completion"] = tiny_completion()
                rec["serves"] = True
            except Exception as e:  # noqa: BLE001
                rec["serves"] = False
                rec["completion_error"] = repr(e)[:200]
            results.append(rec)
            save()
            log(f"ctx {ctx}: loaded={rec['loaded']} spawned_c={rec['ctx_spawned']} "
                f"serves={rec.get('serves')} load={load_s}s "
                f"mem_after={rec['mem_available_after_gib']} GiB")
            if not rec.get("serves"):
                log("serving failed — ceiling found, stopping")
                break
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        subprocess.Popen(["bash", "-c",
                          "setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run "
                          f"--model {BASELINE} -H 0.0.0.0 -p 8888 "
                          f"> {HOME}/unsloth-serve.log 2>&1 < /dev/null &"])
        save()
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")
    log("DEEPSEEK CTX LADDER COMPLETE")


if __name__ == "__main__":
    main()
