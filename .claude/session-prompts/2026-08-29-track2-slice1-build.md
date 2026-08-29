# Session Continuation Prompt
**Generated:** 2026-08-29
**Ending phase:** Track 1 tool-calling — CLOSED (all axes settled) + Track 2 design approved
**Starting phase:** Track 2 slice 1 — fixture battery + agent runner build

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (a cheap model tier is fine) to run the Startup block below and
the Section-scoped reads, and return a ≤2K-word digest. ONLY that digest enters main
context — never read the files or run the startup block in the main thread. Switch the main
thread to a higher model tier only when implementation starts (switching mid-session
re-prices the whole history at the new rate). Every path below is ABSOLUTE. (Cross-harness
doctrine: vvt-omnigent ADR 0005.)

We're working on the vtt-hw-benchmarks repo, worktree
`C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction`.
Branch: `feature/unsloth-direction` (clean, **~31 commits ahead of forgejo — UNPUSHED**, see
Blockers).
Rule: hand startup to a subagent (▶ FIRST MOVE); then execute the startup block; honor
read scoping literally; apply documented environment workarounds on the first attempt.

## Startup block (the subagent runs this first; batch aggressively; ABSOLUTE paths)

```bash
# 1. Git state (worktree)
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" status -sb
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" log --oneline -8
# 2. Forgejo health — BOUNDED curl only; NEVER git push / git ls-remote (they hang minutes).
#    Expected while wedged: version=200 fast, info/refs times out (HTTP 000). BOTH 200 => wedge cleared.
curl -s -m 8 -o /dev/null -w "version %{http_code}\n" https://git.vvautosports.com/api/v1/version
curl -s -m 15 -o /dev/null -w "inforefs %{http_code}\n" "https://git.vvautosports.com/vvc/vtt-hw-benchmarks/info/refs?service=git-upload-pack"
# 3. Framework box state (ssh runs native on Windows; ONE inference session per box —
#    a llama-server here may be another session's: confirm before killing)
ssh -o ConnectTimeout=10 framework 'pgrep -af "llama-server|unsloth run" | head -3; df -h /mnt/ai-models | tail -1'
# 4. Grader gate (must pass before/after any grader edit; run via WSL, 28 checks)
wsl -e bash -c "cd /mnt/c/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction && python3 scripts/testing/test_grade_toolcall.py | tail -1"   # expect: all 28 grader checks passed
```

## Track 1 status — CLOSED 2026-08-28 (do not re-litigate)

### Completed this session (all graded, all committed, each with a manifest)
- Tier 2 battery built + grader multi-call extension (28-check regression suite) — **ranks**: 7/7 Qwen3-Coder-30B/Coder-Next/Qwen3.8-Flash-Next/GLM-4.7-Flash; 6/7 Nemotron-3.5; 5/7 gpt-oss-120b (`results/sweeps/2026-08-28-toolcall-tier2`)
- Parallel-call defect (Nemotron-3.5 + gpt-oss plan 3 calls, emit 1) is a cross-OS model trait AND unrescuable by healing/nudging (0/4, `2026-08-28-parallel-rescue`) → **hard routing rule: no parallel fan-out behind those two**
- No distractor positional bias (pos 1/3/5 all pass); deep-chain closed (5/5 at 100/100, only gpt-oss breaks at 31)
- Co-residency correctness-proven BOTH boxes: framework GLM+Coder 18/18 (`2026-08-28-coresidency-graded`), G1a Nemotron+gemma zero grades flipped (`2026-08-28-g1a-coresidency`)
- G1a unified-memory fix SERVE-VERIFIED on Windows (9/10, ~36 t/s, `2026-08-28-g1a-validation`)
- Windows-vs-Linux A/B: **Linux 1.56× faster**, identical build 10639/2a36554fc (`2026-08-28-ab-nemotron-framework`); studio auto-speculation ≈ +30% over direct
- DeepSeek 16384 ctx pin RETIRED: ladder loads/serves to 98304, needle 3/3 to ~35k tokens, prefill ~110–130 t/s (`2026-08-28-deepseek-ctx-ladder`, `2026-08-28-deepseek-needle`)
- Nemotron TL;DR omission = sampling-dependent, not template (`2026-08-28-nemotron-tldr-seeds`; also first G1a server wedge logged there)
- Coresidency + G1a drivers now capture answers (gradeable); PERFORMANCE-SUMMARY has a § Tool-calling section

### Remaining in Track 2 slice 1 (the next build — spec is authoritative, read it FULL)
1. Build 5 execution-graded fixture repos under `tasks/fixtures/` + per-fixture `grade.sh` + prompt file (specs in the Track 2 doc § task battery)
2. Build `scripts/agents/agent_task_battery.py` (fresh fixture copy → one-shot agent launch → timeout → grade.sh → server /metrics token delta → results.jsonl + manifest conventions)
3. Smoke: Claude Code × 5 tasks × Qwen3-Coder-30B, co-located on framework
4. Then: 7-agent sweep (CC, Codex, OpenCode, Hermes, OpenClaw, Pi, dsh) — dsh via `npx @deepseek-ai/dsh`, PIN ITS VERSION per run (developer preview)
5. Then Track 2B server matrix (existing batteries vs studio/unsloth-llama-server/mainline llama.cpp/vLLM/Ollama/LM Studio) — **GGUF-ONLY rule** (Kal): same UD-Q8_K_XL artifact everywhere; vLLM via its GGUF loader, record `gguf-load-failed` if it won't
6. Then one remote config: G1a → framework over the mesh

### Deferred / backlogged
- Devbox serve-pair wiring (Issue 3 draft): approved scope = serve + LiteLLM role routes on Framework only, NO agent loop — belongs to a vvt-devbox session, not this lane
- Tier 2 top-band escalation ideas: tier2 manifest `saturation_watch`
- DeepSeek 35k–98k graded depth; needle positional sweep (10%/90%)
- vLLM engine-native formats (safetensors/FP8/AWQ) — later labelled slice
- G1a dual-boot A/B (separates OS from chassis in the 1.56× result)

## Key decisions made this session (Kal, 2026-08-28)
- Track 2A: ALL SEVEN agents in slice 1; 5 execution-graded micro-tasks; server-side /metrics is token-accounting truth
- Track 2B: vLLM IS in (Phase-6 dual-machine arch is built on it) but **GGUF-only for now**
- Topology: co-located first, then one remote config
- Devbox wiring: issue-draft only, Framework host, serve+routes scope
- No new Track 1 probes — the track is closed

## What to do next
1. Run startup block (subagent). If Forgejo `info/refs` returns 200: **push the branch**, then `/create-issue` Mode B over the pending-issues file (4 issues — Issue 3 targets vvc/vvt-devbox, rest vvc/vtt-hw-benchmarks), then consider the PR (target `develop`, per /ship).
2. Start Track 2 slice 1 items 1–2 (fixtures + runner) — pure local file work, no inference box needed until the smoke run.
3. Smoke run needs framework: confirm box ownership first (one inference session per box).

## Section-scoped reads
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/docs/reference/TRACK2-HARNESS-BENCHMARKS.md` — read FULL (the approved spec this session executes)
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/.claude/session-prompts/2026-08-28-pending-forgejo-issues.md` — read FULL (4 banked issue drafts + repo targets)
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/docs/reference/PERFORMANCE-SUMMARY.md` — § "Tool-calling (Track 1)" only (leaderboards + routing rule)
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/scripts/sweeps/toolcall_battery.py` — docstring only (spec-entry shape + manifest conventions the new runner should mirror)
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/scripts/sweeps/toolcall_cases_tier2.json` — `notes` array only (standing run rules: --disable-tools, enable_tools:false, greedy, raw rung, per-case ceilings)

## Blockers
- **Forgejo git handler + repo-scoped API wedged** (CT 237; infra lane owns the `docker restart forgejo`). Symptom: `/api/v1/version` fast-200, everything repo-scoped hangs. NEVER `git push`/`git ls-remote` while wedged — bounded curl probes only. ~31 commits + 4 issue drafts wait on it.
- Framework has ONE llama-server (GLM baseline via studio :8888) — standard resting state, fine to preempt for benchmarks after ownership check.

## Pending system-evolution items
None (Forgejo writes blocked; the 4 banked issue drafts in the pending-issues file cover everything).

## Discord Thread
(none yet for this lane — Discord post attempted at reset time; see commit chat log)
