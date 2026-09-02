#!/usr/bin/env python3
"""Run the fixed 3-task battery (thinking / effort=low) against whatever is
currently serving on :8888, and record the runtime build alongside the results.

Usage: python3 battery.py <outdir> <jsonl_out> [alias]

Reuses TASKS / PROFILES / run_one from sweep_phase1 verbatim so the numbers are
directly comparable to the param sweep and the roster run: seed=42,
max_tokens=8192, profile=thinking, reasoning_effort=low.

If alias is omitted it is read from /v1/models (the entry with loaded=true), so
the same script works for any model without editing.
"""
import json
import os
import subprocess
import sys
import urllib.request

sys.path.insert(0, os.path.expanduser("~"))
import sweep_phase1 as sp  # noqa: E402

PROFILE = "thinking"
EFFORT = "low"


def loaded_alias():
    req = urllib.request.Request(
        sp.BASE + "/v1/models",
        headers={"Authorization": "Bearer " + sp.KEY})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read())
    entries = data.get("data") or []
    for m in entries:
        if m.get("loaded"):
            return m.get("id")
    raise SystemExit("no loaded model reported by /v1/models")


def runtime_build():
    exe = os.path.expanduser("~/.unsloth/llama.cpp/llama-server")
    try:
        p = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=60)
        return ((p.stdout or "") + (p.stderr or "")).strip().splitlines()[0]
    except Exception as e:  # noqa: BLE001
        return f"unknown ({e!r})"


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip())
    outdir, jsonl = sys.argv[1], sys.argv[2]
    alias = sys.argv[3] if len(sys.argv) > 3 else loaded_alias()

    build = runtime_build()
    os.makedirs(outdir, exist_ok=True)
    sp.MODEL = alias
    sp.OUTDIR = outdir

    print(f"model={alias}\nbuild={build}\noutdir={outdir}", flush=True)
    with open(jsonl, "w") as out:
        for task, prompt in sp.TASKS.items():
            print(f"-> {task}", flush=True)
            rec = sp.run_one(task, prompt, PROFILE, sp.PROFILES[PROFILE], EFFORT)
            rec["model"] = alias
            rec["runtime_build"] = build
            out.write(json.dumps(rec) + "\n")
            out.flush()
            print("   ", {k: rec.get(k) for k in
                          ("wall_s", "completion_tokens", "tps_wall", "error")
                          if rec.get(k) is not None}, flush=True)
    print("BATTERY COMPLETE", flush=True)


if __name__ == "__main__":
    main()
