#!/usr/bin/env python3
"""Run the Track 1 tool-calling battery over a spec, fresh server per (entry, case).

Usage: python3 toolcall_battery.py <spec.json> <rundir> [--cases FILE] [--only CASE,CASE]

Same bleed protocol as isolated_battery.py: b10639 leaks state across requests on one
server, so every case runs as the sole conversation of its own server process. The two
multi-turn cases (tc_chain, tc_longchain) are several requests BY DESIGN -- the chain is
the test -- so the protocol is fresh-server-per-CASE, not per request.

Spec entries: {"name", "path", "tag"?, "flags"?, "env"?} -- the roster_batch registry
shape, unchanged. The healing ladder is expressed purely in `flags`, so the three rungs
are just three spec entries per model:

  raw     --disable-tools --disable-tool-call-healing --disable-tool-call-nudging
  healed  --disable-tools --enable-tool-call-healing  --disable-tool-call-nudging
  full    --disable-tools --enable-tool-call-healing  --enable-tool-call-nudging

cfg = <name>__<tag>; grade with --layout cfg. toolcall_cases.json is copied into the run
dir so the harvested run grades self-contained.
"""
import json
import os
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)

import sweep_phase1 as sp1  # noqa: E402,F401  (imported for its KEY, refreshed by sp2)
import sweep_phase2 as sp2  # noqa: E402
import sweep_toolcall as tc  # noqa: E402

BASELINE = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
BASELINE_ENV = {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}
LOAD_TIMEOUT = 1500


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def launch(path, flags, logfile, env=None):
    env_prefix = ""
    if env:
        env_prefix = "env " + " ".join(f"{k}={v}" for k, v in env.items()) + " "
    cmd = (f"setsid nohup {env_prefix}unsloth run --model {path} -H 0.0.0.0 -p 8888 "
           f"{flags} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def fresh_server(path, flags, logfile, env):
    sp2.kill_serve()
    launch(path, flags, logfile, env=env)
    return sp2.wait_loaded(logfile, timeout=LOAD_TIMEOUT)


def main():
    argv = sys.argv[1:]
    cases_file = os.path.join(HOME, "toolcall_cases.json")
    only = None
    args = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--cases":
            i += 1
            cases_file = argv[i]
        elif a == "--only":
            i += 1
            only = [s.strip() for s in argv[i].split(",") if s.strip()]
        elif a.startswith("--"):
            raise SystemExit(f"unknown flag: {a}")
        else:
            args.append(a)
        i += 1
    if len(args) != 2:
        raise SystemExit(__doc__.strip())
    spec = json.load(open(args[0], encoding="utf-8"))
    rundir = args[1]

    bundle = tc.load_cases(cases_file)
    consts = bundle["request_constants"]
    cases = bundle["cases"]
    names = only or list(cases)
    missing = [n for n in names if n not in cases]
    if missing:
        raise SystemExit(f"unknown case(s): {missing}")

    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    # Provenance: the grader reads expectations from the run dir, not the repo.
    shutil.copyfile(cases_file, os.path.join(rundir, "toolcall_cases.json"))

    out_path = os.path.join(rundir, "results.jsonl")
    records = []

    def flush():
        with open(out_path, "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    try:
        for entry in spec:
            cfg = f"{entry['name']}__{entry.get('tag', 'default')}"
            flags = entry.get("flags", "")
            env = entry.get("env") or {}
            outdir = os.path.join(rundir, "outputs", cfg)
            os.makedirs(outdir, exist_ok=True)
            log(f"=== {cfg}  flags={flags!r} env={env!r}")
            if not os.path.exists(entry["path"]):
                records.append({"model": entry["name"], "cfg": cfg, "flags": flags,
                                "env": env, "loaded": False, "error": "path missing"})
                flush()
                continue
            for case_name in names:
                logfile = os.path.join(rundir, f"serve-{cfg}-{case_name}.log")
                if not fresh_server(entry["path"], flags, logfile, env):
                    log(f"{cfg}/{case_name}: LOAD FAILED")
                    tail = ""
                    try:
                        tail = open(logfile, encoding="utf-8", errors="replace").read()[-1000:]
                    except OSError:
                        pass
                    records.append({"model": entry["name"], "cfg": cfg, "task": case_name,
                                    "flags": flags, "env": env, "loaded": False,
                                    "serve_log_tail": tail})
                    flush()
                    continue
                rec = tc.run_tool_case(case_name, cases[case_name], consts, outdir)
                rec.update({"model": entry["name"], "cfg": cfg, "flags": flags,
                            "env": env, "loaded": True,
                            "isolation": "fresh-server-per-case"})
                records.append(rec)
                flush()
                log(f"  {case_name}: calls={rec.get('n_calls')} depth={rec.get('chain_depth_reached')} "
                    f"turns={rec.get('turns')} ptok={rec.get('prompt_tokens')} "
                    f"finish={rec.get('finish_reason')} rawtext={rec.get('raw_toolcall_text_detected')} "
                    f"err={rec.get('error')}")
    finally:
        log("restoring GLM baseline")
        sp2.kill_serve()
        launch(BASELINE, "", os.path.join(HOME, "unsloth-serve.log"), env=BASELINE_ENV)
        ok = sp2.wait_loaded(os.path.join(HOME, "unsloth-serve.log"), timeout=900)
        log(f"baseline restored healthy={ok}")
        flush()
    log("TOOLCALL BATTERY COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w", encoding="utf-8") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
