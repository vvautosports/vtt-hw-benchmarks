#!/usr/bin/env python3
"""Run the Track 2A agent battery: execution-graded fixture tasks per agent CLI.

Usage: python3 agent_task_battery.py <agents_spec.json> <rundir>
           [--fixtures DIR] [--only TASK,TASK] [--timeout S] [--grade-timeout S]
           [--metrics-url URL] [--no-preflight]

Before any cells run, a tool-call preflight probe hits the studio Anthropic
`/v1/messages` endpoint and aborts the run if no tool_use comes back — this
catches a degraded/wedged serve in seconds instead of burning 900s cells (the
2026-08-29 false 0/3, issue #12). `--no-preflight` skips it.

Runs ON the inference host (agents co-located with the server), like the sweep
drivers. It does NOT manage the server: serve the target model first (studio
`unsloth run`, llama-server child launched with --metrics), then run this.

Spec entries mirror the roster_batch/toolcall_battery shape:

  {"name": "claude", "tag": "smoke",
   "cmd": ["unsloth", "start", "claude", "--yolo", "-p", "{prompt}"],
   "env": {"...": "..."}}

`cmd` is the one-shot launch template; every arg has "{prompt}" replaced by the
fixture's prompt.md text. cfg = <name>__<tag>. --yolo (non-prompting) is required
for unattended runs and is safe ONLY because agents run in disposable scratch
copies — this runner never points an agent at a real repo.

Per cell: fresh fixture copy under <rundir>/scratch/<cfg>/<task>/ (git repo,
baseline commit) -> agent one-shot with cwd there -> wait/timeout -> capture
git diff + transcript -> enforce protected.txt (byte-identical) -> inject
hidden/ -> run grade.sh (exit 0 = pass) -> server /metrics delta -> append to
results.jsonl (flushed per record, one output dir per cfg — the trampling rule).

Token accounting comes from the server's Prometheus /metrics (llamacpp:* delta),
NOT agent-reported counts — those are not comparable across harnesses. With no
--metrics-url the runner discovers a local llama-server --port from pgrep and
uses the first /metrics endpoint that answers.

Fixture layout (see tasks/fixtures/README.md): fixture/ (what the agent gets),
hidden/ (grading assets injected after the run), prompt.md, grade.sh,
protected.txt (paths that must come back byte-identical), solution/ (self-test
overlay only — never shipped to agents).
"""
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import time
import urllib.request

GIT_IDENT = ["-c", "user.name=agent-battery", "-c", "user.email=bench@vvc.local"]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def run_git(scratch, *args):
    return subprocess.run(["git", *GIT_IDENT, *args], cwd=scratch,
                          capture_output=True, text=True)


def scrape_metrics(url):
    """All llamacpp:* samples from a Prometheus /metrics endpoint, or None."""
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            text = resp.read().decode("utf-8", errors="replace")
    except Exception:
        return None
    out = {}
    for line in text.splitlines():
        if line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("llamacpp:"):
            try:
                out[parts[0]] = float(parts[1])
            except ValueError:
                pass
    return out or None


def preflight_toolcall(base_url, key, model):
    """Confirm the serving path executes tool calls before burning cells.

    The 2026-08-29 smoke went 0/3 (900s timeouts, zero edits) because the box
    was in a degraded state, not because the path was broken — a clean-serve
    probe returned a proper tool_use in ~1s. This fails a run fast (seconds)
    instead of hours when the endpoint is wedged. Returns (ok, detail)."""
    payload = json.dumps({
        "model": model, "max_tokens": 64,
        "tools": [{"name": "write_file", "description": "Write a text file",
                   "input_schema": {"type": "object",
                                    "properties": {"path": {"type": "string"},
                                                   "content": {"type": "string"}},
                                    "required": ["path", "content"]}}],
        "messages": [{"role": "user",
                      "content": "Use write_file to create hello.txt containing: hi"}],
    }).encode()
    req = urllib.request.Request(base_url.rstrip("/") + "/v1/messages", data=payload,
                                 method="POST")
    req.add_header("content-type", "application/json")
    req.add_header("anthropic-version", "2023-06-01")
    if key:
        req.add_header("x-api-key", key)
        req.add_header("authorization", "Bearer " + key)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = json.loads(resp.read().decode("utf-8", errors="replace"))
    except Exception as e:
        return False, f"probe request failed: {e}"
    blocks = body.get("content", []) or []
    if any(b.get("type") == "tool_use" for b in blocks):
        return True, "tool_use returned"
    return False, f"no tool_use (stop_reason={body.get('stop_reason')}, blocks={[b.get('type') for b in blocks]})"


def discover_base_and_key():
    """Studio base URL + api key from `unsloth start claude --no-launch` (never
    logged). Returns (base_url, key, model) or (None, None, None)."""
    try:
        out = subprocess.run(["bash", "-c",
                              "unsloth start claude --no-launch 2>/dev/null"],
                             capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return None, None, None
    import re
    base = re.search(r"ANTHROPIC_BASE_URL=(\S+)", out)
    key = re.search(r"ANTHROPIC_AUTH_TOKEN=(sk-unsloth-[0-9a-f]+)", out)
    model = re.search(r"ANTHROPIC_MODEL=(\S+)", out)
    return (base.group(1) if base else None,
            key.group(1) if key else None,
            model.group(1) if model else None)


def discover_metrics_url():
    """Find a local llama-server /metrics endpoint via pgrep (bracketed match —
    over tailscale SSH an unbracketed pattern matches itself)."""
    probe = subprocess.run(["bash", "-c", "pgrep -af '[l]lama-server'"],
                           capture_output=True, text=True)
    candidates = []
    for line in probe.stdout.splitlines():
        toks = line.split()
        if "--port" in toks:
            port = toks[toks.index("--port") + 1]
            candidates.append((("--metrics" in toks), port))
    candidates.sort(reverse=True)  # prefer servers launched with --metrics
    for _, port in candidates:
        url = f"http://127.0.0.1:{port}/metrics"
        if scrape_metrics(url) is not None:
            return url
    return None


def metrics_delta(before, after):
    if not before or not after:
        return None
    return {k: round(after[k] - before.get(k, 0.0), 6)
            for k in after if after[k] != before.get(k, 0.0)}


def sum_matching(delta, needle):
    if not delta:
        return None
    hits = [v for k, v in delta.items() if needle in k]
    return round(sum(hits), 3) if hits else None


def inject_hidden(fixture_dir, scratch):
    hidden = os.path.join(fixture_dir, "hidden")
    if os.path.isdir(hidden):
        shutil.copytree(hidden, scratch, dirs_exist_ok=True)


def protected_violations(fixture_dir, scratch):
    """Paths from protected.txt that are missing or not byte-identical."""
    listing = os.path.join(fixture_dir, "protected.txt")
    if not os.path.exists(listing):
        return []
    bad = []
    for rel in open(listing, encoding="utf-8").read().split():
        pristine = os.path.join(fixture_dir, "fixture", rel)
        current = os.path.join(scratch, rel)
        try:
            same = open(pristine, "rb").read() == open(current, "rb").read()
        except OSError:
            same = False
        if not same:
            bad.append(rel)
    return bad


def run_agent(cmd, cwd, env, timeout_s, transcript_path):
    """One-shot agent launch in its own process group; SIGKILL the group on
    timeout (this llama-server generation ignores SIGTERM; assume agents may too)."""
    started = time.time()
    with open(transcript_path, "w", encoding="utf-8", errors="replace") as out:
        proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=out,
                                stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, start_new_session=True)
        try:
            exit_code = proc.wait(timeout=timeout_s)
            timed_out = False
        except subprocess.TimeoutExpired:
            timed_out = True
            exit_code = None
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass
            proc.wait()
    return exit_code, timed_out, round(time.time() - started, 1)


def main():
    argv = sys.argv[1:]
    fixtures_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "..", "tasks", "fixtures")
    only = None
    timeout_s = 900
    grade_timeout_s = 300
    metrics_url = None
    preflight = True
    args = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--no-preflight":
            preflight = False
        elif a == "--fixtures":
            i += 1
            fixtures_dir = argv[i]
        elif a == "--only":
            i += 1
            only = [s.strip() for s in argv[i].split(",") if s.strip()]
        elif a == "--timeout":
            i += 1
            timeout_s = int(argv[i])
        elif a == "--grade-timeout":
            i += 1
            grade_timeout_s = int(argv[i])
        elif a == "--metrics-url":
            i += 1
            metrics_url = argv[i]
        elif a.startswith("--"):
            raise SystemExit(f"unknown flag: {a}")
        else:
            args.append(a)
        i += 1
    if len(args) != 2:
        raise SystemExit(__doc__.strip())
    spec = json.load(open(args[0], encoding="utf-8"))
    rundir = os.path.abspath(args[1])
    fixtures_dir = os.path.abspath(fixtures_dir)

    if preflight:
        base, key, model = discover_base_and_key()
        if not base:
            log("PREFLIGHT SKIPPED: could not resolve studio base/key "
                "(pass --no-preflight to silence)")
        else:
            ok, detail = preflight_toolcall(base, key, model)
            log(f"preflight tool-call probe: {'OK' if ok else 'FAIL'} — {detail}")
            if not ok:
                raise SystemExit(
                    "ABORT: serving path does not execute tool calls — refusing "
                    "to burn cells on a degraded serve (see issue #12). Fix the "
                    "serve or pass --no-preflight to override.")

    tasks = sorted(
        d for d in os.listdir(fixtures_dir)
        if os.path.isdir(os.path.join(fixtures_dir, d, "fixture"))
        and os.path.exists(os.path.join(fixtures_dir, d, "grade.sh")))
    if only:
        missing = [t for t in only if t not in tasks]
        if missing:
            raise SystemExit(f"unknown task(s): {missing}")
        tasks = only

    os.makedirs(os.path.join(rundir, "outputs"), exist_ok=True)
    # Provenance: fixtures and spec are copied into the run dir, and scratch
    # copies are made FROM the run-dir copy — a later fixture edit can never
    # change what a committed run means.
    run_fixtures = os.path.join(rundir, "fixtures")
    for t in tasks:
        dst = os.path.join(run_fixtures, t)
        if not os.path.exists(dst):
            shutil.copytree(os.path.join(fixtures_dir, t), dst)
    shutil.copyfile(args[0], os.path.join(rundir, os.path.basename(args[0])))

    if metrics_url is None:
        metrics_url = discover_metrics_url()
    log(f"metrics endpoint: {metrics_url or 'NONE (token accounting disabled)'}")

    with open(os.path.join(rundir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"created_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                   "host": platform.node(), "argv": sys.argv, "tasks": tasks,
                   "metrics_url": metrics_url,
                   "agents": [f"{e['name']}__{e.get('tag', 'default')}" for e in spec]},
                  f, indent=1)

    out_path = os.path.join(rundir, "results.jsonl")
    records = []

    def flush():
        with open(out_path, "w", encoding="utf-8") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")

    for entry in spec:
        cfg = f"{entry['name']}__{entry.get('tag', 'default')}"
        outdir = os.path.join(rundir, "outputs", cfg)
        os.makedirs(outdir, exist_ok=True)
        env = dict(os.environ)
        env.update(entry.get("env") or {})
        log(f"=== {cfg}")
        for task in tasks:
            fixture_dir = os.path.join(run_fixtures, task)
            prompt = open(os.path.join(fixture_dir, "prompt.md"),
                          encoding="utf-8").read().strip()
            cmd = [a.replace("{prompt}", prompt) for a in entry["cmd"]]

            scratch = os.path.join(rundir, "scratch", cfg, task)
            if os.path.exists(scratch):  # never reuse a scratch dir (trampling rule)
                shutil.rmtree(scratch)
            shutil.copytree(os.path.join(fixture_dir, "fixture"), scratch)
            run_git(scratch, "init", "-q")
            run_git(scratch, "add", "-A")
            run_git(scratch, "commit", "-qm", "baseline")

            before = scrape_metrics(metrics_url) if metrics_url else None
            transcript = os.path.join(outdir, f"{task}.log")
            agent_exit, timed_out, wall_s = run_agent(cmd, scratch, env,
                                                      timeout_s, transcript)
            after = scrape_metrics(metrics_url) if metrics_url else None

            run_git(scratch, "add", "-A")
            diff = run_git(scratch, "diff", "HEAD").stdout
            diff_file = os.path.join(outdir, f"{task}.diff")
            with open(diff_file, "w", encoding="utf-8", errors="replace") as f:
                f.write(diff)

            violations = protected_violations(fixture_dir, scratch)
            inject_hidden(fixture_dir, scratch)
            try:
                grade = subprocess.run(
                    ["bash", os.path.join(fixture_dir, "grade.sh")], cwd=scratch,
                    capture_output=True, text=True, timeout=grade_timeout_s)
                grade_exit, grade_timeout = grade.returncode, False
                grade_tail = (grade.stdout + grade.stderr)[-2000:]
            except subprocess.TimeoutExpired:
                grade_exit, grade_timeout = None, True
                grade_tail = ""

            delta = metrics_delta(before, after)
            predicted = sum_matching(delta, "tokens_predicted_total")
            rec = {
                "task": task, "agent": entry["name"], "cfg": cfg,
                "cmd_template": entry["cmd"],
                "started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "wall_s": wall_s, "agent_exit": agent_exit, "timeout": timed_out,
                "protected_violations": violations,
                "grade_exit": grade_exit, "grade_timeout": grade_timeout,
                "grade_tail": grade_tail,
                "passed": (grade_exit == 0 and not violations and not grade_timeout),
                "metrics_url": metrics_url, "metrics_delta": delta,
                "prompt_tokens_delta": sum_matching(delta, "prompt_tokens_total"),
                "predicted_tokens_delta": predicted,
                "wall_tps": (round(predicted / wall_s, 2)
                             if predicted and wall_s else None),
                "transcript": os.path.relpath(transcript, rundir),
                "diff_file": os.path.relpath(diff_file, rundir),
                "scratch": os.path.relpath(scratch, rundir),
            }
            records.append(rec)
            flush()
            log(f"  {task}: passed={rec['passed']} wall={wall_s}s "
                f"agent_exit={agent_exit} timeout={timed_out} "
                f"protected={violations or 'ok'} "
                f"ptok={rec['prompt_tokens_delta']} gtok={predicted}")

    flush()
    log("AGENT TASK BATTERY COMPLETE")
    with open(os.path.join(rundir, "DONE"), "w", encoding="utf-8") as f:
        f.write("done\n")


if __name__ == "__main__":
    main()
