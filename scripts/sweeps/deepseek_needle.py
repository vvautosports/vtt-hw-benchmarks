#!/usr/bin/env python3
"""DeepSeek long-context needle probe — does retrieval hold at the newly unlocked depths?

Usage: python3 deepseek_needle.py <rundir>

The ctx ladder (2026-08-28-deepseek-ctx-ladder) proved rungs to 98304 LOAD and serve, but
no cell processed a long prompt. This is the graded half: a unique needle sentence buried
mid-document in ~8k / ~24k / ~48k-token filler, question at the end, greedy. Serve at
--max-seq-length 65536 (the new safe setting), fresh serve per cell.

The needle token differs per cell, so b10639 cross-request bleed cannot flatter a later
cell with an earlier cell's answer even if state leaks.

Grade: content contains the cell's code. Also records prefill_tps and wall — the prefill
cost at depth is the other unmeasured quantity this run pins down.
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

GGUF = ("/mnt/ai-models/unsloth/DeepSeek-V4-Flash-0731-GGUF/UD-IQ3_XXS/"
        "DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00001-of-00004.gguf")
BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
LOAD_TIMEOUT = 2400

# (label, approx target prompt tokens, needle code) — codes unique per cell (bleed guard)
CELLS = [
    ("8k", 8000, "ZK-4471-MOTH"),
    ("24k", 24000, "QX-9182-FERN"),
    ("48k", 48000, "RV-3356-DUSK"),
]

TOPICS = [
    "the maintenance schedule of industrial heat exchangers",
    "soil drainage in terraced vineyards",
    "the calibration of pressure sensors in bottling lines",
    "inventory rotation policies in cold-storage warehouses",
    "the acoustics of open-plan office partitions",
    "ballast water management in coastal freighters",
    "the fatigue testing of bicycle frame welds",
    "queue management in regional rail interchanges",
]


def filler_paragraph(i):
    t = TOPICS[i % len(TOPICS)]
    return (f"Section {i}. This section reviews {t}. The working group noted in meeting "
            f"{100 + i} that procedures were revised {i % 7 + 1} times last cycle, and the "
            f"audit trail records {i * 13 % 97} minor findings, none of which were "
            f"escalated. Routine monitoring continues under protocol {i % 5 + 2}A, with "
            f"quarterly reviews scheduled and no exceptions outstanding. ")


def build_prompt(target_tokens, code):
    # ~72 words/paragraph ≈ 95 tokens; build to target, needle at ~50% depth.
    n = max(4, target_tokens // 95)
    paras = [filler_paragraph(i) for i in range(n)]
    needle = (f"IMPORTANT OPERATIONAL NOTE: the vault access code for this facility is "
              f"{code}. Retain this exactly. ")
    paras.insert(n // 2, needle)
    return ("You will read a long operations digest, then answer one question.\n\n"
            + "\n".join(paras)
            + "\n\nQuestion: What is the vault access code stated in the digest? "
              "Reply with just the code on its own line as 'CODE: <code>'.")


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def launch(logfile):
    cmd = (f"setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run "
           f"--model {GGUF} -H 0.0.0.0 -p 8888 --disable-tools "
           f"--max-seq-length 65536 > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def resolve_model(key):
    req = urllib.request.Request("http://localhost:8888/v1/models",
                                 headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read())
    for m in data.get("data", []):
        if m.get("loaded"):
            return m["id"]
    return None


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__.strip())
    rundir = sys.argv[1]
    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    records = []

    def save():
        with open(os.path.join(rundir, "results.jsonl"), "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    try:
        for label, target, code in CELLS:
            logfile = os.path.join(rundir, f"serve-{label}.log")
            sp2.kill_serve()
            launch(logfile)
            if not sp2.wait_loaded(logfile, timeout=LOAD_TIMEOUT):
                log(f"{label}: LOAD FAILED")
                records.append({"cell": label, "loaded": False})
                save()
                continue
            key = sp1.KEY
            model = resolve_model(key)
            prompt = build_prompt(target, code)
            body = {"model": model, "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": 1024, "seed": 42, "temperature": 0.0, "top_p": 1.0,
                    "reasoning_effort": "low", "enable_tools": False}
            req = urllib.request.Request("http://localhost:8888/v1/chat/completions",
                                         data=json.dumps(body).encode(),
                                         headers={"Content-Type": "application/json",
                                                  "Authorization": "Bearer " + key})
            t0 = time.monotonic()
            try:
                with urllib.request.urlopen(req, timeout=3600) as resp:
                    data = json.loads(resp.read())
            except Exception as e:  # noqa: BLE001
                records.append({"cell": label, "loaded": True, "error": repr(e)[:300],
                                "wall_s": round(time.monotonic() - t0, 1)})
                save()
                log(f"{label}: REQUEST ERROR")
                continue
            wall = time.monotonic() - t0
            choice = (data.get("choices") or [{}])[0]
            msg = choice.get("message", {}) or {}
            content = msg.get("content") or ""
            usage = data.get("usage", {}) or {}
            timings = data.get("timings", {}) or {}
            found = code in content
            rec = {"cell": label, "loaded": True, "needle_code": code,
                   "prompt_tokens": usage.get("prompt_tokens"),
                   "completion_tokens": usage.get("completion_tokens"),
                   "wall_s": round(wall, 1),
                   "prefill_tps": timings.get("prompt_per_second"),
                   "tps_server": timings.get("predicted_per_second"),
                   "finish_reason": choice.get("finish_reason"),
                   "needle_found": found, "correct": found}
            records.append(rec)
            with open(os.path.join(rundir, "outputs", f"needle-{label}.txt"),
                      "w", encoding="utf-8") as f:
                f.write("=== CONTENT ===\n" + content + "\n")
            save()
            log(f"{label}: ptok={rec['prompt_tokens']} found={found} wall={rec['wall_s']}s "
                f"prefill_tps={rec['prefill_tps']}")
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
    log("DEEPSEEK NEEDLE PROBE COMPLETE")


if __name__ == "__main__":
    main()
