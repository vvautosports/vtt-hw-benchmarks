# Session Continuation Prompt
**Generated:** 2026-09-02
**Ending state:** Track 2A battery merged to develop; smoke root-caused, 1 valid pass
**Starting state:** rerun the smoke with OOM mitigations, then widen to the agent matrix

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (cheap tier is fine) to run the Startup block below and the
Section-scoped reads, and return a ≤2K-word digest. ONLY that digest enters main context —
never read the files or run the startup block in the main thread. Switch the main thread to
a higher tier only when implementation starts. Every path below is ABSOLUTE.
(Doctrine: vvt-omnigent ADR 0005.)

We're working on the **vtt-hw-benchmarks** repo at `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks`.
Branch: `develop`, clean, at `3b676ff` (PR #5 merged — the whole Track 2A battery is on develop).
Forgejo-primary: push via the `forgejo` remote; `origin` is a stale GitHub mirror; `gh` lies here.

**Kal's intent for the next session: keep testing.** The box is free and on its GLM resting state.

## Startup block (subagent runs this first; ABSOLUTE paths)

```bash
# 1. New worktree off develop for the rerun work (worktrees are mandatory for feature work).
#    NOTE: any branch created from an older base misses .forgejo/workflows/ and its CI
#    pends forever on the ubuntu-latest label — branching off current develop avoids that.
cd "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks" && git fetch forgejo --prune && \
  git merge --ff-only forgejo/develop && \
  git worktree add .claude/worktrees/battery-rerun -b feature/battery-rerun forgejo/develop

# 2. Gates must be green before spending box time (run in WSL — native Windows lacks the tooling):
wsl -e bash -lc "cd /mnt/c/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/battery-rerun && \
  python3 scripts/testing/test_fixtures.py && python3 scripts/testing/test_grade_toolcall.py && \
  python3 scripts/testing/test_grade_receipt.py"
# expect: 'all 20 fixture checks passed' / 'all 28 grader checks passed' / 'all 21 grader checks passed'

# 3. Confirm the box is free and see what is serving (never measure while a human is using it):
ssh framework 'uptime; pgrep -af "[l]lama-server" | grep -o "\-m [^ ]*"; ls ~/agent_task_battery.py ~/fixtures ~/restore_glm.sh ~/relaunch_qwen.sh'
```

## Status

### Completed this session
- **PR #5 merged to develop** (`3b676ff`) — Track 1 wrap-up, vision receipt battery, Track 2A
  fixtures + runner + preflight, both smoke runs, crash-recovery runbook + WOL script.
- **Issue #12 root-caused and rewritten.** The Aug-29 "proxy never executes tools" verdict was
  a poisoned measurement. On a clean serve the proxy returns correct `tool_use` in 1.2s and
  the hello.txt one-shot passes. Real bug: the llama-server child is **OOM-killed (code -9)**
  under sustained agentic contexts (auto ctx 202752 × `--parallel 4` × 25k-token slots on
  unified memory), and the studio's Anthropic-proxy httpx client **wedges after respawn**
  ("Cannot send a request, as the client has been closed") — 500s for every later cell.
- **First passing cell:** `feature-with-tests` PASSED end-to-end (agent edits → hidden
  acceptance suite → grade green). Whole Track 2A chain proven.
- Runner **preflight guard** added: aborts a run in seconds when the serve can't execute tools.
- Forgejo CI unblocked with the vvc-64 session: merged develop's `.forgejo/workflows/` in,
  fixed one MD038, `ci / test` green in ~15s.
- Issues filed: **#13** (WOL self-heal), **#14** (Qwen3.8-Flash-Next MTP re-baseline),
  **#15** (EvalScope + community-comparable benchmarking lane).

### Remaining (in priority order)
1. **Smoke rerun with OOM mitigations (#12)** — pin a modest `-c` (e.g. 32768) and
   `--parallel 1` on the battery serve. Expect 4-5 clean cells instead of 2.
2. **7-agent matrix (#10)** — Codex, OpenCode, Hermes, OpenClaw, Pi, dsh. Verify each
   one-shot invocation with `--no-launch` style dry-runs BEFORE burning cells; pin dsh's
   npx version in the manifest.
3. **MTP re-baseline (#14)** — needs the Framework's unsloth runtime bumped from b10639 to
   ≥ b10715 (or a Desktop update, which ships MTP default-on); head is 2.79GB `shared-Q8_0`.
4. **EvalScope pilot (#15)** — `evalscope perf` concurrency ladder (also answers #14's
   concurrency question) + dashboard on a harvested run.
5. **Config-sweep zero-edit spin** — genuine finding, transcript in the run dir; worth a look.
6. **Runner scoring nuance (#12)** — `timeout=True` can coexist with a passing grade; add a
   completion-grace or a separate work-complete flag.

### Deferred
- Vision serving driver (queued from the vision lane) — decision made: **vendor** the
  extraction schema + system prompt from expense-agent into this repo so runs stay
  self-contained. Serving code written off-hardware doesn't get committed.
- Muse-Glimmer-30B per-family config investigation before any vision-quality verdict.

## Key decisions made this session
- **Two-lane benchmarking (#15):** community lane (official + YouTube-canon tests, run via
  EvalScope, contamination expected, for comparability with published numbers) never mixes
  into the bespoke lane (execution-graded fixtures = internal ranking truth).
- **Vision-capable models add the receipt battery** to Track 2B grade fidelity; an engine
  that can't load the mmproj records `mmproj-load-failed` rather than dropping the row.
- Battery serves get pinned context and `--parallel 1` — auto-selected context is the
  memory bomb on this hardware.

## What to do next
1. Run the startup block via the subagent; confirm gates green and the box free.
2. Serve Qwen3-Coder-30B with pinned `-c 32768 --parallel 1`, wait for `/health`, then run:
   `python3 ~/agent_task_battery.py ~/smoke_claude.json ~/agent-smoke-<date> --fixtures ~/fixtures --timeout 600`
   (the preflight will abort in seconds if the serve is degraded — that's the guard working).
3. Harvest into `results/sweeps/`, write a CAVEATS.md if anything is poisoned, commit, push,
   and update #12 with whether pinning fixed the OOM.
4. If clean: dry-run the other six agents' one-shot invocations, then start the matrix (#10).

## Section-scoped reads
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/results/sweeps/2026-09-02-agent-smoke/CAVEATS.md` — read FULL. The per-cell validity table and the OOM/wedge evidence.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/scripts/agents/README.md` — read FULL. Deploy model (scp + CRLF strip), spec shape, safety, metrics.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/scripts/agents/agent_task_battery.py` §module docstring + §`preflight_toolcall` + §`main` flag parsing — settles CLI flags and what the preflight does.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/tasks/fixtures/README.md` — read FULL. Fixture layout, rules, both-ways self-test.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/docs/reference/TRACK2-HARNESS-BENCHMARKS.md` §"Track 2A" + §"Build list" — the 7-agent invocation table and matrix sizing.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/docs/runbooks/agentic-crash-recovery.md` — read FULL (short). Box-down triage, WOL, PID-kill technique, tailscaled literal trap.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/scripts/sweeps/README.md` §"Deployment model" + §"The trampling rule" — conventions the new runner mirrors.

## Blockers
None for the rerun — box is free, gates green, everything merged. #14 (MTP) is gated on a
runtime bump; #15 (EvalScope) needs the package installed on the box first.

## Pending system-evolution items
None.

## Discord Thread
None — no thread exists for this lane; the Discord bot token is not configured on this machine.
