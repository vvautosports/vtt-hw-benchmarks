#!/usr/bin/env python3
"""Phase 2 param sweep: server-side axes (--speculative-type, --parallel).

Usage: python3 sweep_phase2.py <profile> <effort>
  profile/effort: the winning per-request config from phase 1 (e.g. thinking medium)

For each server config: kill the serve, relaunch with the config's flags, wait
until the model reports loaded, run the fixed battery (3 tasks single-stream +
a 4-way concurrent probe), record t/s. Restores the baseline serve at the end
no matter what. Requires ~/sweep_phase1.done (refuses to kill a serve that
phase 1 is still using). Results: ~/sweep-results-phase2.jsonl, marker
~/sweep_phase2.done.
"""
import json, os, re, subprocess, sys, threading, time, urllib.request

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)
from sweep_phase1 import TASKS, PROFILES, run_one  # noqa: E402  (reuse fixed tasks/profiles)
import sweep_phase1  # noqa: E402

BASE = "http://localhost:8888"
MODEL_PATH = "/mnt/ai-models/unsloth/GLM-4.7-Flash-GGUF/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
OUT = os.path.join(HOME, "sweep-results-phase2.jsonl")
DONE = os.path.join(HOME, "sweep_phase2.done")
BASELINE_LOG = os.path.join(HOME, "unsloth-serve.log")

PROFILE = sys.argv[1] if len(sys.argv) > 1 else "thinking"
EFFORT = sys.argv[2] if len(sys.argv) > 2 else "medium"

SPEC_TYPES = ["auto", "mtp", "ngram", "mtp+ngram", "off"]
PARALLEL_EXTRA = [1, 8]  # np=4 covered by the spec-type round


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)


def kill_serve():
    # this llama-server build ignores SIGTERM (verified 2026-08-26) — escalate
    sh("pkill -f '[u]nsloth run' ; pkill -f '[l]lama-server'")
    for i in range(30):
        if sh("pgrep -f '[l]lama-server'").returncode != 0:
            return True
        if i == 4:
            sh("pkill -9 -f '[u]nsloth run' ; pkill -9 -f '[l]lama-server'")
        time.sleep(2)
    return False


def refresh_key(logfile):
    for lf in (logfile, BASELINE_LOG):
        try:
            with open(lf) as f:
                keys = re.findall(r"sk-unsloth-[A-Za-z0-9_-]+", f.read())
            if keys:
                return keys[-1]
        except OSError:
            pass
    return None


def wait_loaded(logfile, timeout=420):
    t0 = time.monotonic()
    while time.monotonic() - t0 < timeout:
        key = refresh_key(logfile)
        if key:
            try:
                req = urllib.request.Request(
                    BASE + "/v1/models",
                    headers={"Authorization": "Bearer " + key})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read())
                if any(m.get("loaded") for m in data.get("data", [])):
                    sweep_phase1.KEY = key
                    return True
            except Exception:
                pass
        time.sleep(10)
    return False


def launch(extra_flags, logfile, append=False):
    redir = ">>" if append else ">"
    cmd = (f"setsid nohup unsloth run --model {MODEL_PATH} -H 0.0.0.0 -p 8888 "
           f"{extra_flags} {redir} {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def battery(cfg_name):
    # separate output dir per server config — never trample phase 1's files
    outdir = os.path.join(HOME, "sweep-out-phase2",
                          re.sub(r"[^A-Za-z0-9]+", "_", cfg_name))
    os.makedirs(outdir, exist_ok=True)
    sweep_phase1.OUTDIR = outdir
    recs = []
    profile = PROFILES[PROFILE]
    for task, prompt in TASKS.items():
        rec = run_one(task, prompt, PROFILE, profile, EFFORT)
        rec["server_config"] = cfg_name
        recs.append(rec)
        print(f"  {cfg_name} / {task}: wall={rec.get('wall_s')} "
              f"tok={rec.get('completion_tokens')} err={rec.get('error')}", flush=True)
    # 4-way concurrent probe: same short reasoning task in 4 threads
    results = [None] * 4
    def worker(i):
        # distinct task label per thread — run_one derives the output filename
        # from it, and 4 threads must not race one path
        results[i] = run_one(f"reasoning_c{i}", TASKS["reasoning"], PROFILE, profile, EFFORT)
    threads = [threading.Thread(target=worker, args=(i,)) for i in range(4)]
    t0 = time.monotonic()
    for t in threads: t.start()
    for t in threads: t.join()
    wall = time.monotonic() - t0
    toks = sum((r or {}).get("completion_tokens") or 0 for r in results)
    errs = sum(1 for r in results if r and r.get("error"))
    recs.append({"server_config": cfg_name, "task": "concurrent4",
                 "profile": PROFILE, "effort": EFFORT, "wall_s": round(wall, 1),
                 "completion_tokens": toks, "errors": errs,
                 "tps_aggregate": round(toks / wall, 2) if wall > 0 and toks else None})
    print(f"  {cfg_name} / concurrent4: wall={wall:.0f}s agg_toks={toks} "
          f"agg_tps={toks/wall:.1f} errs={errs}", flush=True)
    return recs


def mean_tps(recs):
    vals = [r["tps_wall"] for r in recs
            if r.get("tps_wall") and r.get("task") != "concurrent4"]
    return sum(vals) / len(vals) if vals else 0.0


def run_config(out, cfg_name, extra_flags):
    print(f"=== CONFIG {cfg_name}: {extra_flags}", flush=True)
    logfile = os.path.join(HOME, f"sweep-serve-{re.sub(r'[^A-Za-z0-9]+', '_', cfg_name)}.log")
    if not kill_serve():
        print("  kill_serve timed out, aborting config", flush=True)
        return []
    launch(extra_flags, logfile)
    if not wait_loaded(logfile):
        recs = [{"server_config": cfg_name, "error": "server did not become ready"}]
    else:
        recs = battery(cfg_name)
    for r in recs:
        out.write(json.dumps(r) + "\n")
    out.flush()
    return recs


def main():
    if not os.path.exists(os.path.join(HOME, "sweep_phase1.done")):
        print("phase 1 not done; refusing to restart the serve", flush=True)
        sys.exit(1)
    if os.path.exists(DONE):
        os.remove(DONE)
    scores = {}
    try:
        with open(OUT, "w") as out:
            for spec in SPEC_TYPES:
                cfg = f"spec={spec},np=4"
                recs = run_config(out, cfg, f"--speculative-type {spec} --parallel 4")
                scores[spec] = mean_tps(recs)
            best = max(scores, key=scores.get) if any(scores.values()) else "auto"
            print(f"=== best spec type: {best} ({scores})", flush=True)
            for np_ in PARALLEL_EXTRA:
                cfg = f"spec={best},np={np_}"
                run_config(out, cfg, f"--speculative-type {best} --parallel {np_}")
    finally:
        print("=== restoring baseline serve", flush=True)
        kill_serve()
        launch("", BASELINE_LOG, append=True)
        ok = wait_loaded(BASELINE_LOG)
        print(f"=== baseline restored, healthy={ok}", flush=True)
    with open(DONE, "w") as f:
        f.write("done\n")
    print("SWEEP PHASE 2 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
