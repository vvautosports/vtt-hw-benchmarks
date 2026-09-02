# Agent battery (Track 2A)

Driver for the agent-harness axis: same model + same server, swap the agent CLI.
Design: [TRACK2-HARNESS-BENCHMARKS.md](../../docs/reference/TRACK2-HARNESS-BENCHMARKS.md).
Tracking issue: vtt-hw-benchmarks #10.

## Deployment model

Like the sweep drivers, `agent_task_battery.py` runs **on the inference host**
(agents co-located with the server), and it does **not** manage the server —
serve the target model first, then run the battery.

```bash
# from the repo root on your workstation
scp scripts/agents/agent_task_battery.py framework:/home/kalman9/
scp scripts/agents/specs/*.json framework:/home/kalman9/
scp -r tasks/fixtures framework:/home/kalman9/fixtures
ssh framework 'sed -i "s/\r$//" ~/agent_task_battery.py ~/*.json $(find ~/fixtures -type f)'
```

The `sed` matters: Windows checkouts are CRLF and Python/bash both choke.

Smoke run (Claude Code x 5 fixtures x Qwen3-Coder-30B):

```bash
ssh -n framework 'setsid nohup python3 ~/agent_task_battery.py ~/smoke_claude.json \
    ~/agent-smoke-$(date +%Y-%m-%d) --fixtures ~/fixtures \
    > ~/agent-smoke.log 2>&1 < /dev/null & disown'
```

## Spec entries

Same registry shape as the sweep drivers, with `cmd` instead of `flags`:

```json
{"name": "claude", "tag": "smoke",
 "cmd": ["unsloth", "start", "claude", "--yolo", "-p", "{prompt}"],
 "env": {}}
```

Every arg has `{prompt}` replaced by the fixture's `prompt.md`. cfg = `<name>__<tag>`.
Before the first run of any agent, verify its one-shot invocation on the box and fix
the spec (not the runner) — the launcher syntax table lives in the Track 2 design doc.
For dsh, pin the npx version inside `cmd` (e.g. `npx @deepseek-ai/dsh@x.y.z`) — it is
a developer preview and the manifest must record the exact version.

## Safety

`--yolo` / non-prompting mode is acceptable ONLY because every agent runs in a
disposable scratch copy under the run dir. The runner never points an agent at a
real repo, and scratch dirs are never reused (the trampling rule).

## Metrics

Token accounting is the **server-side** `/metrics` delta (llamacpp:* counters),
never agent-reported counts — those are not comparable across harnesses. Serve
with `--metrics` enabled; the runner auto-discovers the llama-server port via
pgrep or takes `--metrics-url` explicitly. Grading is execution-based per fixture
(`grade.sh`, exit 0 = pass) — see [tasks/fixtures/README.md](../../tasks/fixtures/README.md).

Before spending hardware, run the no-inference gate on your workstation (WSL/Linux):

```bash
python3 scripts/testing/test_fixtures.py
```
