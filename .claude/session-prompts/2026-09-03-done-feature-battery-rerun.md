# Session Continuation Prompt
**Generated:** 2026-09-03
**Ending phase:** Feature complete — docs(bench): cache-ram falsified, evidence lakehouse reference arch, parallelism plan
**Starting phase:** Track 2A root cause — proxy-captured real cell on a fresh boot; MLflow wiring waits on ref-arch §11

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (a cheap model tier is fine) to run any startup commands and the
Section-scoped reads below, and return a ≤2K-word digest. ONLY that digest enters main
context — never read the files in the main thread. Switch the main thread to a higher model
tier only when implementation starts (switching mid-session re-prices the whole history).
Every path in this prompt is ABSOLUTE. (Cross-harness doctrine: vvt-omnigent ADR 0005.)

We're working on the vtt-hw-benchmarks repo. Worktree:
`C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\battery-rerun` (branch `feature/battery-rerun`, PR #19 open).
If #19 has merged, remove the worktree and start a new one from `forgejo/develop`.
Forgejo-primary: push to remote `forgejo`; `origin` is the stale GitHub mirror; `gh` does not work.

## Feature completed

**Branch:** `feature/battery-rerun`
**PR:** #19 — https://git.vvautosports.com/vvc/vtt-hw-benchmarks/pulls/19
**Commits:** 5 since develop (d565910, 2f3efca, ab0e87e, f57c7cd, 4c20608)

### What was done
- **Cache-ram test (falsified):** `serve_pinned.sh` now exports `LLAMA_ARG_CACHE_RAM` (32768 MiB
  default). One config-sweep cell with it → identical to baseline (timeout, 124k ptok, 1.63 tok/s,
  35 GB slab). Evidence + writeup: `results/sweeps/2026-09-03-cacheram-ab/FINDING-cacheram-2026-09-03.md`.
- **Root-cause narrowed:** llama-server log shows two prompt streams alternating on the single
  slot (~25k and ~7.5k tokens, lockstep growth, both fully reprocessed). Isolation probes proved
  the RAM cache works (alternating 24k prompts → 0.8 s), the studio Anthropic path is prefix-stable,
  replayed real Claude Code requests reuse, and Claude Code only mutates `cache_control` markers.
  Stream B (≈ A minus the 24 tool declarations) is unidentified.
- **Reference architecture:** `docs/reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md` — Kal's
  open-lakehouse guiding lights mapped to MLflow 3.4 OSS / UC OSS 0.3 / Delta on MinIO; build
  order §10; Kal's decisions §11. Artifact: https://claude.ai/code/artifact/77160554-334e-4a39-ac06-c866f16c687e
- **Parallelism matrix:** `docs/reference/AI-SERVER-PARALLELISM-MATRIX-PLAN.md`, plan-only (AI
  server 100.64.0.39 still off the mesh; no ping sent).
- Earlier on the branch: real serve verification, memory-leak evidence, #12 narrowed, slab drain rate.

### Test results
markdownlint clean on both docs; shellcheck one pre-existing SC2015 info; cell + probe evidence in the results dir. See PR #19.

## Deferred / follow-up work
- Rewrite issue #12: root cause is NOT cache size; cite the FINDING.
- Handoff to the infra lakehouse session written: `C:\Users\kalman9\Documents\vvc\vvt-infrastructure\.claude\session-prompts\2026-09-03-evidence-lakehouse-handoff-from-hwbench.md` (PR on `feature/session-prompt-lakehouse-handoff`).
- MLflow wiring (hwbench #6) blocked on Kal's §11 decisions; then follow §10 build order (identity/schemas → writer → live hooks → registry → gold).
- Framework box: OOM killer took gnome-shell at 16:00 (desktop session dead until Kal logs in). Serve torn down; 65 GB avail, 33 GB slab → wait ~3 h or reboot before the next cell. The `>90 GB` guard stays.
- Box helpers left in `~` on framework: `logproxy.py` (8899→8888 capture), `diffreq.py`, `diffmsg.py`, `cache_probe.py`, `studio_probe.py`, `replay.py`, `run_cacheram.sh`, `cc-capture/`.

## What to do next
1. **Fresh boot → one real cell with request capture.** Start `~/logproxy.py`, run the cell with
   spec `env: {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8899"}` (verify `unsloth start` does not
   override it; else launch `claude` directly with the env `unsloth start claude --no-launch`
   prints). Diff every request (`~/diffreq.py`) and correlate with llama-server tasks → identifies
   stream B and the prefix-breaking field.
2. Then one variable per boot: `--parallel 2` (`--max-seq-length 131072`), then
   `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` / `CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536`.
3. Rewrite #12. Re-run the 5-cell battery once reuse is proven. Then the 6-agent matrix (#10).
4. AI server matrix when the box answers (plan doc §"Order of execution"; step 0 = ask Jordan).

## Section-scoped reads
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\battery-rerun\results\sweeps\2026-09-03-cacheram-ab\FINDING-cacheram-2026-09-03.md` — read FULL (~90 lines); the current root-cause state and the next test.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\battery-rerun\scripts\agents\agent_task_battery.py` — lines 121-157 (`discover_base_and_key`, metrics discovery) and 317-336 (per-entry `env` plumbing).
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\battery-rerun\scripts\agents\serve_pinned.sh` — read FULL (~58 lines); the `>90 GB` guard and the env line.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\battery-rerun\docs\reference\EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md` — §10 and §11 only, unless MLflow work starts.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\battery-rerun\docs\runbooks\agentic-crash-recovery.md` — §box-down triage, if framework does not answer.
- Startup: `ssh framework 'free -g | head -2; grep SUnreclaim /proc/meminfo; ss -ltn | grep -c :8888; uptime'` — clean means avail >90 GB, nothing on 8888.

## Blockers
- Framework needs its slab drained (or a reboot) before any cell. AI server off the mesh (needs on-site `tailscaled`).

## Pending system-evolution items
None.
