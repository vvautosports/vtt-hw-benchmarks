#!/usr/bin/env python3
"""Vision smoke test for Muse-Glimmer-30B — the capability it was actually acquired for.

Usage: python3 muse_vision_smoke.py <rundir>

The 2026-08-28 day-one battery passed Muse 3/3 on TEXT only; the mmproj was downloaded and
never loaded, so nothing has yet exercised the vision path that replaces gemma-3-27b's
niche. This closes that gap.

Deterministic by construction: the test image is generated here, not sourced, so the
correct answer is known exactly rather than judged. Three solid colour bars — red, green,
blue, left to right on white — and the model must report the count and the order. A model
that cannot see the image cannot guess "3" AND the order (1 in 3 x 6 = 18 by chance, and
the failure modes in practice are refusals or hallucinated descriptions, not lucky
permutations).

Writes a pure-PNG encoder inline because the workstation has no PIL and the inference host
should not need one either. Drives llama-server directly (same shim as coresidency_test.py)
because the mmproj has to be passed at launch.
"""
import base64
import json
import os
import re
import struct
import subprocess
import sys
import time
import urllib.request
import zlib

HOME = os.path.expanduser("~")
SERVER = os.path.join(HOME, ".unsloth/llama.cpp/llama-server")
MODEL = "/mnt/ai-models/unsloth/Muse-Glimmer-30B-GGUF/Muse-Glimmer-30B-UD-Q8_K_XL.gguf"
MMPROJ = "/mnt/ai-models/unsloth/Muse-Glimmer-30B-GGUF/mmproj-Muse-Glimmer-30B-BF16.gguf"
PORT = 8811

BARS = [("red", (220, 30, 30)), ("green", (30, 170, 60)), ("blue", (40, 70, 210))]
W, H, MARGIN, BAR_W = 480, 200, 30, 120


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def make_png(path):
    """Minimal RGB PNG encoder — no PIL anywhere in the chain."""
    px = [[(255, 255, 255)] * W for _ in range(H)]
    for i, (_, rgb) in enumerate(BARS):
        x0 = MARGIN + i * (BAR_W + MARGIN)
        for y in range(MARGIN, H - MARGIN):
            for x in range(x0, min(x0 + BAR_W, W)):
                px[y][x] = rgb
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in px)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)
    return len(png)


def launch(logfile):
    cmd = (f"setsid nohup {SERVER} -m {MODEL} --mmproj {MMPROJ} --port {PORT} "
           f"--host 127.0.0.1 -c 8192 -ngl -1 --flash-attn on --jinja "
           f"--alias Muse-Glimmer-30B > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def wait_health(timeout=900):
    t0 = time.monotonic()
    while time.monotonic() - t0 < timeout:
        try:
            with urllib.request.urlopen(
                    f"http://127.0.0.1:{PORT}/health", timeout=5) as r:
                if json.loads(r.read()).get("status") == "ok":
                    return round(time.monotonic() - t0, 1)
        except Exception:
            pass
        time.sleep(5)
    return None


def ask(prompt, b64):
    body = {
        "model": "Muse-Glimmer-30B",
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": prompt},
            {"type": "image_url",
             "image_url": {"url": "data:image/png;base64," + b64}},
        ]}],
        "max_tokens": 512, "seed": 42, "temperature": 0.0,
    }
    req = urllib.request.Request(
        f"http://127.0.0.1:{PORT}/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"})
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=600) as r:
        data = json.loads(r.read())
    wall = time.monotonic() - t0
    msg = (data.get("choices") or [{}])[0].get("message", {}) or {}
    usage = data.get("usage", {}) or {}
    return {"content": msg.get("content") or "", "wall_s": round(wall, 1),
            "prompt_tokens": usage.get("prompt_tokens"),
            "completion_tokens": usage.get("completion_tokens")}


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__.strip())
    rundir = sys.argv[1]
    os.makedirs(rundir, exist_ok=True)
    img = os.path.join(rundir, "bars.png")
    log(f"generated {img} ({make_png(img)} bytes, {W}x{H}, 3 bars)")
    b64 = base64.b64encode(open(img, "rb").read()).decode()

    results = {"image": {"width": W, "height": H,
                         "bars": [n for n, _ in BARS]}, "checks": []}
    subprocess.run(["bash", "-c", "pkill -f '[l]lama-server' ; pkill -f '[u]nsloth run'"],
                   check=False)
    time.sleep(5)
    subprocess.run(["bash", "-c", "pkill -9 -f '[l]lama-server'"], check=False)
    time.sleep(3)

    logfile = os.path.join(rundir, "serve-muse-vision.log")
    launch(logfile)
    load = wait_health()
    if load is None:
        log("LOAD FAILED — mmproj may be rejected by this build")
        results["loaded"] = False
        try:
            results["serve_log_tail"] = open(logfile, errors="replace").read()[-2000:]
        except OSError:
            pass
    else:
        results["loaded"] = True
        results["load_seconds"] = load
        log(f"loaded with mmproj in {load}s")

        cases = [
            ("count", "How many coloured bars are in this image? "
                      "Answer with just the number.",
             lambda c: "3" in c or "three" in c.lower()),
            ("order", "List the colours of the bars from left to right, "
                      "separated by commas. Colours only.",
             lambda c: [n for n, _ in BARS]
             == re.findall(r"red|green|blue", c.lower())[:3]),
        ]
        for name, prompt, check in cases:
            r = ask(prompt, b64)
            ok = bool(check(r["content"]))
            r.update({"case": name, "correct": ok})
            results["checks"].append(r)
            log(f"  {name}: correct={ok} ptok={r['prompt_tokens']} "
                f"wall={r['wall_s']}s :: {r['content'][:90]!r}")

    subprocess.run(["bash", "-c", "pkill -9 -f '[l]lama-server'"], check=False)
    time.sleep(3)
    subprocess.Popen(["bash", "-c",
                      "setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run "
                      "--model /mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/"
                      "GLM-4.7-Flash-UD-Q8_K_XL.gguf -H 0.0.0.0 -p 8888 "
                      f"> {HOME}/unsloth-serve.log 2>&1 < /dev/null &"])
    with open(os.path.join(rundir, "vision-smoke.json"), "w") as f:
        json.dump(results, f, indent=2)
    passed = sum(1 for c in results["checks"] if c["correct"])
    log(f"VISION SMOKE COMPLETE — {passed}/{len(results['checks'])} checks passed")
    with open(os.path.join(rundir, "DONE"), "w") as f:
        f.write("done\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
