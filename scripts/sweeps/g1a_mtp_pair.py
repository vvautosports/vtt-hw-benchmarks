#!/usr/bin/env python3
"""HP G1a (Strix Halo, Windows) speculative-decoding on/off pairs (hwbench #14).

Usage: python scripts/sweeps/g1a_mtp_pair.py <spec.json> <rundir> [--port 8899] [--skip-text]
                                            [--only <task|case> ...]

Spec rows are roster_batch rows plus two speculative keys:

    {"name": "Qwen3.6-35B-A3B-MTP", "tag": "g1a-b10830-mtp2",
     "path": "C:/.../Qwen3.6-35B-A3B-UD-Q8_K_XL.gguf",
     "flags": "--disable-tools --disable-tool-call-healing --disable-tool-call-nudging",
     "env": {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"},
     "speculative_type": "mtp", "spec_draft_n_max": 2}

Each row is served with `unsloth run --speculative-type <type> [--spec-draft-n-max N]`.
On the b10830 studio the type values are `auto|mtp|dspark|dflash|ngram|mtp+ngram|off|
ngram-simple`; the studio translates `mtp` into llama-server's `--spec-type draft-mtp
--spec-draft-n-max N` (visible in the serve log's "Starting llama-server" line and the
"Spec decoding: draft-mtp (MTP-only)" event). Sidecar drafters (`mtp-<model>.gguf`) are picked
up automatically from the model directory when the type is `mtp`. The `off` arm is
explicit, because the studio default is "auto".

Protocol (matches g1a_validation.py, whose launcher/helpers this reuses):
  - fresh server per graded cell, raw healing rung, text cells thinking/low,
    tool cells greedy per toolcall_cases_tier2.json
  - every record carries speculative_type / spec_draft_n_max and, when the server
    reports them, timings.draft_n / draft_n_accepted -> draft_accept_rate. The studio
    proxy strips llama-server `timings` from /v1/chat/completions (tps_server and the
    draft counters come back None); tps_wall is the comparable number.
  - manifest.auto.yaml via run_manifest so log_sweep_to_mlflow.py ingests the rundir;
    grade with:  python scripts/utils/grade_sweep.py <rundir> results --layout cfg

`--only reasoning` is the smoke form: one text cell per arm, enough to see the
spec flags in the llama-server command line and draft_n in the timings.

Port defaults to 8899: the Unsloth Desktop app squats 8888 on this box and a second
`unsloth run` on a held port spawns an unreachable orphan (see UNSLOTH-DIRECTION.md).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import g1a_validation as g1a  # noqa: E402  (launcher, key harvest, transcripts)
import run_manifest as rm  # noqa: E402
from sweep_phase1 import PROFILES, TASKS  # noqa: E402

PREBUILT_INFO = os.path.expanduser(r"~\.unsloth\llama.cpp\UNSLOTH_PREBUILT_INFO.json")
TIER2 = os.path.join(HERE, "toolcall_cases_tier2.json")
DRIVER = "scripts/sweeps/g1a_mtp_pair.py"
SPEC_RE = re.compile(r"(?i)(spec|draft|mtp|specul)")


def runtime_build():
    """release_tag from the studio's prebuilt manifest (llama-server --version is not
    on PATH on Windows and the studio bundles its own binary)."""
    try:
        with open(PREBUILT_INFO, encoding="utf-8") as f:
            d = json.load(f)
        return str(d.get("release_tag") or d.get("tag") or "unknown")
    except Exception as e:  # noqa: BLE001
        return f"unknown ({e!r})"


def launch(gguf, flags, env, spec_type, n_max, port, logfile):
    e = dict(os.environ)
    e.update({str(k): str(v) for k, v in (env or {}).items()})
    cmd = [g1a.UNSLOTH, "run", "--model", gguf, "-H", "127.0.0.1", "-p", str(port),
           "--speculative-type", spec_type]
    if n_max is not None and spec_type != "off":
        cmd += ["--spec-draft-n-max", str(n_max)]
    cmd += [x for x in str(flags or "").split() if x]
    subprocess.Popen(cmd, stdout=open(logfile, "w", encoding="utf-8"),
                     stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                     env=e, creationflags=0x00000008 | 0x00000200)
    return cmd


def spec_log_lines(logfile, limit=12):
    try:
        with open(logfile, encoding="utf-8", errors="replace") as f:
            lines = [ln.rstrip() for ln in f if SPEC_RE.search(ln)]
    except OSError:
        return []
    return [re.sub(r"sk-unsloth-[A-Za-z0-9_-]+", "sk-unsloth-<redacted>", ln)[:700]
            for ln in lines[:limit]]


def draft_stats(data):
    t = data.get("timings", {}) or {}
    n, acc = t.get("draft_n"), t.get("draft_n_accepted")
    out = {}
    if n is not None:
        out["draft_n"] = n
    if acc is not None:
        out["draft_n_accepted"] = acc
    if n and acc is not None:
        out["draft_accept_rate"] = round(acc / n, 4)
    return out


def main():
    argv = sys.argv[1:]
    port, skip_text, only, args = 8899, False, [], []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--port":
            i += 1
            port = int(argv[i])
        elif a == "--skip-text":
            skip_text = True
        elif a == "--only":
            i += 1
            only.append(argv[i])
        elif a.startswith("--"):
            raise SystemExit(f"unknown flag: {a}")
        else:
            args.append(a)
        i += 1
    if len(args) != 2:
        raise SystemExit(__doc__.strip())
    spec_path, rundir = args
    spec = json.load(open(spec_path, encoding="utf-8"))
    g1a.BASE = f"http://127.0.0.1:{port}"

    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    shutil.copyfile(TIER2, os.path.join(rundir, "toolcall_cases.json"))
    shutil.copyfile(spec_path, os.path.join(rundir, "spec.json"))
    bundle = json.load(open(TIER2, encoding="utf-8"))
    tc_cases, tc_consts = bundle["cases"], bundle["request_constants"]
    build = runtime_build()

    man = rm.write_start(rundir, spec, DRIVER, sys.argv, {
        "isolation": "fresh-server-per-case", "axis": "cfg", "rung": "raw",
        "hardware": "HP ZBook Ultra G1a (Strix Halo, 128GB, Windows 11)",
        "request_constants": {"text": {"profile": "thinking", "reasoning_effort": "low",
                                       "seed": 42, "max_tokens": 8192},
                              "tool": tc_consts},
        "cases": sorted(tc_cases),
        "outputs": "outputs/<cfg>/<task>--<profile>--<effort>.txt",
    })
    man["runtime_build"] = build      # finalize() re-emits from this dict
    man["node"] = "hp-g1a-windows"
    g1a.log(f"build={build} port={port} entries={len(spec)}")

    out_path = os.path.join(rundir, "results.jsonl")
    records = []

    def flush():
        with open(out_path, "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    cells = ([] if skip_text else [("text", t) for t in TASKS]) + \
            [("tool", c) for c in tc_cases]
    if only:
        cells = [c for c in cells if c[1] in only]
        if not cells:
            raise SystemExit(f"--only matched no cell: {only}")
    try:
        for entry in spec:
            cfg = f"{entry['name']}__{entry.get('tag', 'default')}"
            spec_type = str(entry.get("speculative_type", "off"))
            n_max = entry.get("spec_draft_n_max")
            flags = entry.get("flags", "")
            env = entry.get("env") or {}
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            common = {"model": entry["name"], "cfg": cfg, "tag": entry.get("tag", "default"),
                      "host": "hp-g1a-windows", "runtime_build": build,
                      "flags": flags, "env": env, "isolation": "fresh-server-per-case",
                      "speculative_type": spec_type, "spec_draft_n_max": n_max}
            g1a.log(f"=== {cfg}  speculative={spec_type} n_max={n_max} flags={flags!r}")
            if not os.path.exists(entry["path"]):
                g1a.log(f"{cfg}: PATH MISSING {entry['path']}")
                records.append({**common, "loaded": False, "error": "path missing"})
                flush()
                continue

            for kind, task in cells:
                logfile = os.path.join(rundir, f"serve-{cfg}-{task}.log")
                g1a.kill_servers()
                launch(entry["path"], flags, env, spec_type, n_max, port, logfile)
                key, mid, load_s = g1a.wait_loaded(logfile)
                if key is None:
                    g1a.log(f"{task}: LOAD FAILED")
                    records.append({**common, "task": task, "loaded": False,
                                    "spec_log": spec_log_lines(logfile)})
                    flush()
                    continue
                g1a.log(f"{task}: loaded in {load_s}s as {mid}")
                t0 = time.monotonic()
                try:
                    if kind == "text":
                        body = {"model": mid,
                                "messages": [{"role": "user", "content": TASKS[task]}],
                                "max_tokens": 8192, "seed": 42, "reasoning_effort": "low",
                                **PROFILES["thinking"]}
                        data = g1a.post(body, key)
                        wall = time.monotonic() - t0
                        choice = (data.get("choices") or [{}])[0]
                        msg = choice.get("message", {}) or {}
                        rec = g1a.base_record(task, "thinking", "low", wall, data)
                        rec["finish_reason"] = choice.get("finish_reason")
                        g1a.write_transcript(outdir, f"{task}--thinking--low.txt",
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
                        data = g1a.post(body, key)
                        wall = time.monotonic() - t0
                        choice = (data.get("choices") or [{}])[0]
                        msg = choice.get("message", {}) or {}
                        calls = g1a.flatten(msg.get("tool_calls"))
                        rec = g1a.base_record(task, "toolcall", tc_consts["reasoning_effort"],
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
                        g1a.write_transcript(
                            outdir, f"{task}--toolcall--{tc_consts['reasoning_effort']}.txt",
                            msg.get("reasoning_content") or "", msg.get("content") or "",
                            calls, meta)
                    rec.update(draft_stats(data))
                except Exception as e:  # noqa: BLE001 - one cell must not kill the pair
                    rec = {"task": task, "error": repr(e)[:300],
                           "wall_s": round(time.monotonic() - t0, 1)}
                rec.update(common)
                rec["loaded"] = True
                rec["load_s"] = load_s
                rec["spec_log"] = spec_log_lines(logfile)
                records.append(rec)
                flush()
                g1a.log(f"  {task}: tps={rec.get('tps_server')} wall={rec.get('wall_s')}s "
                        f"draft={rec.get('draft_n')}/{rec.get('draft_n_accepted')} "
                        f"err={rec.get('error')}")
    finally:
        g1a.log("pair done -- killing server")
        g1a.kill_servers()
        flush()
        rm.finalize(rundir, records)
    with open(os.path.join(rundir, "DONE"), "w", encoding="utf-8") as f:
        f.write("done\n")
    g1a.log("G1A MTP PAIR COMPLETE")
    return 0


if __name__ == "__main__":
    sys.exit(main())
