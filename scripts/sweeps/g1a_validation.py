#!/usr/bin/env python3
"""HP G1a (Strix Halo, Windows) serve-validation of UNSLOTH_DISABLE_UNIFIED_MEMORY=1.

Usage: python g1a_validation.py <rundir> [--model NAME] [--gguf PATH] [--skip-text]

The b10639 unified-memory env fix was staged on the G1a via setx but never serve-verified:
nothing measured on this box is trustworthy until a graded battery runs against a server
launched WITH the env. This driver is that battery. Windows-native counterpart of
toolcall_battery.py + the text battery, deliberately self-contained (the deployed harness
modules assume POSIX setsid/pkill).

Protocol matches the framework runs where it matters:
  - fresh server per graded cell (b10639 bleeds state across requests on one server)
  - raw healing rung only: --disable-tools --disable-tool-call-healing --disable-tool-call-nudging
  - text cells at thinking/low (the roster-baseline config), tool cells greedy per
    toolcall_cases_tier2.json request_constants
  - transcripts in grader section format; grade with:
      python scripts/utils/grade_sweep.py <rundir> results --layout cfg

UNSLOTH_DISABLE_UNIFIED_MEMORY is PRESENCE-tested by studio ('=0' does not disable), so the
env is injected explicitly into every server launch — inheriting the User-scope setx would
work, but launching explicit removes the doubt this run exists to settle.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

UNSLOTH = os.path.expanduser(r"~\.unsloth\studio\bin\unsloth.exe")
BASE = "http://127.0.0.1:8888"
RAW_FLAGS = ["--disable-tools", "--disable-tool-call-healing", "--disable-tool-call-nudging"]
LOAD_TIMEOUT = 1500

HERE = os.path.dirname(os.path.abspath(__file__))
TIER2 = os.path.join(HERE, "toolcall_cases_tier2.json")

TEXT_SNIPPET_IMPORT = os.path.join(HERE)  # sweep_phase1 lives beside this file
sys.path.insert(0, HERE)


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def kill_servers():
    """llama-server ignores SIGTERM on the framework build; on Windows just taskkill /F.
    The studio python child dies with its unsloth.exe parent."""
    for name in ("llama-server.exe", "unsloth.exe"):
        subprocess.run(["taskkill", "/IM", name, "/F", "/T"],
                       capture_output=True, check=False)
    for _ in range(15):
        r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq llama-server.exe"],
                           capture_output=True, text=True, check=False)
        if "llama-server.exe" not in r.stdout:
            return True
        time.sleep(2)
    return False


def launch(gguf, logfile):
    env = dict(os.environ)
    env["UNSLOTH_DISABLE_UNIFIED_MEMORY"] = "1"
    cmd = [UNSLOTH, "run", "--model", gguf, "-H", "127.0.0.1", "-p", "8888"] + RAW_FLAGS
    # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP: survives this script, no console window.
    subprocess.Popen(cmd, stdout=open(logfile, "w", encoding="utf-8"),
                     stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                     env=env, creationflags=0x00000008 | 0x00000200)


def refresh_key(logfile):
    try:
        with open(logfile, encoding="utf-8", errors="replace") as f:
            keys = re.findall(r"sk-unsloth-[A-Za-z0-9_-]+", f.read())
        return keys[-1] if keys else None
    except OSError:
        return None


def wait_loaded(logfile, timeout=LOAD_TIMEOUT):
    t0 = time.monotonic()
    while time.monotonic() - t0 < timeout:
        key = refresh_key(logfile)
        if key:
            try:
                req = urllib.request.Request(BASE + "/v1/models",
                                             headers={"Authorization": "Bearer " + key})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read())
                for m in data.get("data", []):
                    if m.get("loaded"):
                        return key, m.get("id"), round(time.monotonic() - t0, 1)
            except Exception:
                pass
        time.sleep(10)
    return None, None, None


def fresh_server(gguf, logfile):
    kill_servers()
    launch(gguf, logfile)
    return wait_loaded(logfile)


def post(body, key, timeout=1800):
    req = urllib.request.Request(
        BASE + "/v1/chat/completions", data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def write_transcript(outdir, fname, reasoning, content, calls=None, meta=None):
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, fname), "w", encoding="utf-8") as f:
        if reasoning:
            f.write("=== REASONING ===\n" + reasoning + "\n\n")
        f.write("=== CONTENT ===\n" + content + "\n\n")
        if calls is not None:
            f.write("=== TOOLCALLS ===\n" + json.dumps(calls, indent=1) + "\n\n")
        if meta is not None:
            f.write("=== META ===\n" + json.dumps(meta, indent=1) + "\n")


def flatten(tool_calls):
    out = []
    for tc in tool_calls or []:
        fn = tc.get("function", {})
        raw = fn.get("arguments")
        parsed, ok = raw, True
        if isinstance(raw, str):
            try:
                parsed = json.loads(raw)
            except (ValueError, TypeError):
                parsed, ok = raw, False
        out.append({"name": fn.get("name"), "arguments": parsed,
                    "arguments_raw": raw, "args_parsed": ok})
    return out


def base_record(task, profile, effort, wall, data):
    usage = data.get("usage", {}) or {}
    timings = data.get("timings", {}) or {}
    comp = usage.get("completion_tokens")
    return {"task": task, "profile": profile, "effort": effort,
            "wall_s": round(wall, 1), "prompt_tokens": usage.get("prompt_tokens"),
            "completion_tokens": comp,
            "tps_wall": round(comp / wall, 2) if comp and wall > 0 else None,
            "tps_server": timings.get("predicted_per_second"),
            "prefill_tps": timings.get("prompt_per_second")}


def main():
    argv = sys.argv[1:]
    model_name = "NVIDIA-Nemotron-3.5-Lightning-30B-A3B"
    gguf = None
    skip_text = False
    args = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--model":
            i += 1
            model_name = argv[i]
        elif a == "--gguf":
            i += 1
            gguf = argv[i]
        elif a == "--skip-text":
            skip_text = True
        elif a.startswith("--"):
            raise SystemExit(f"unknown flag: {a}")
        else:
            args.append(a)
        i += 1
    if len(args) != 1:
        raise SystemExit(__doc__.strip())
    rundir = args[0]
    if gguf is None:
        raise SystemExit("--gguf <path> is required")
    if not os.path.exists(gguf):
        raise SystemExit(f"gguf not found: {gguf}")

    from sweep_phase1 import TASKS, PROFILES  # noqa: E402  (canonical text battery)

    bundle = json.load(open(TIER2, encoding="utf-8"))
    tc_cases = bundle["cases"]
    tc_consts = bundle["request_constants"]

    cfg = f"{model_name}__g1a-raw"
    outdir = os.path.join(rundir, "outputs", cfg)
    os.makedirs(outdir, exist_ok=True)
    import shutil
    shutil.copyfile(TIER2, os.path.join(rundir, "toolcall_cases.json"))

    out_path = os.path.join(rundir, "results.jsonl")
    records = []

    def flush():
        with open(out_path, "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    common = {"model": model_name, "cfg": cfg, "host": "hp-g1a-windows",
              "env": {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"},
              "flags": " ".join(RAW_FLAGS), "isolation": "fresh-server-per-case"}

    cells = ([] if skip_text else [("text", t) for t in TASKS]) + \
            [("tool", c) for c in tc_cases]
    try:
        for kind, task in cells:
            logfile = os.path.join(rundir, f"serve-{cfg}-{task}.log")
            key, mid, load_s = fresh_server(gguf, logfile)
            if key is None:
                log(f"{task}: LOAD FAILED")
                records.append({**common, "task": task, "loaded": False})
                flush()
                continue
            log(f"{task}: loaded in {load_s}s as {mid}")
            t0 = time.monotonic()
            try:
                if kind == "text":
                    body = {"model": mid,
                            "messages": [{"role": "user", "content": TASKS[task]}],
                            "max_tokens": 8192, "seed": 42, "reasoning_effort": "low",
                            **PROFILES["thinking"]}
                    data = post(body, key)
                    wall = time.monotonic() - t0
                    msg = (data.get("choices") or [{}])[0].get("message", {}) or {}
                    rec = base_record(task, "thinking", "low", wall, data)
                    rec["finish_reason"] = (data.get("choices") or [{}])[0].get("finish_reason")
                    write_transcript(outdir, f"{task}--thinking--low.txt",
                                     msg.get("reasoning_content") or "",
                                     msg.get("content") or "")
                else:
                    case = tc_cases[task]
                    body = {"model": mid,
                            "messages": [{"role": "user", "content": case["prompt"]}],
                            "tools": case["tools"], "tool_choice": "auto",
                            "max_tokens": tc_consts["max_tokens"],
                            "seed": tc_consts["seed"],
                            "temperature": tc_consts["temperature"],
                            "top_p": tc_consts["top_p"],
                            "reasoning_effort": tc_consts["reasoning_effort"],
                            "enable_tools": tc_consts["enable_tools"]}
                    data = post(body, key)
                    wall = time.monotonic() - t0
                    choice = (data.get("choices") or [{}])[0]
                    msg = choice.get("message", {}) or {}
                    calls = flatten(msg.get("tool_calls"))
                    rec = base_record(task, "toolcall", tc_consts["reasoning_effort"],
                                      wall, data)
                    rec.update({"finish_reason": choice.get("finish_reason"),
                                "turns": 1, "n_calls": len(calls),
                                "chain_depth_reached": 0,
                                "raw_toolcall_text_detected": False,
                                "args_parse_failures":
                                    sum(1 for c in calls if not c["args_parsed"])})
                    meta = {k: rec[k] for k in
                            ("finish_reason", "turns", "n_calls", "chain_depth_reached",
                             "raw_toolcall_text_detected", "args_parse_failures",
                             "prompt_tokens")}
                    meta["case"] = task
                    write_transcript(outdir,
                                     f"{task}--toolcall--{tc_consts['reasoning_effort']}.txt",
                                     msg.get("reasoning_content") or "",
                                     msg.get("content") or "", calls, meta)
            except Exception as e:  # noqa: BLE001 - one cell must not kill the battery
                rec = {"task": task, "error": repr(e)[:300],
                       "wall_s": round(time.monotonic() - t0, 1)}
            rec.update(common)
            rec["loaded"] = True
            rec["load_s"] = load_s
            records.append(rec)
            flush()
            log(f"  {task}: tps={rec.get('tps_server')} wall={rec.get('wall_s')}s "
                f"err={rec.get('error')}")
    finally:
        log("battery done — killing server (box left idle deliberately)")
        kill_servers()
        flush()
    with open(os.path.join(rundir, "DONE"), "w", encoding="utf-8") as f:
        f.write("done\n")
    log("G1A VALIDATION COMPLETE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
