# Continuation — Framework + Strix Halo testing (Lane B/C)
**Generated:** 2026-08-28
**Scope:** Framework Desktop and HP G1a ONLY. Does not touch the AI server or the forge.

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT

Spawn ONE Explore subagent (cheap tier is fine) to run the Startup block and the
Section-scoped reads below, and return a ≤2K-word digest. ONLY the digest enters main
context — never read these files or run the startup block in the main thread. Escalate the
main thread's tier only when implementation starts. All paths absolute. (Doctrine:
vvt-omnigent ADR 0005.)

Repo: `vtt-hw-benchmarks`, worktree
`C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction`
Branch: `feature/unsloth-direction` (clean; **9 commits unpushed — see Blockers, do not
try to fix that here**).

## ⚠️ Parallel-session rules

A second session may be running the **AI server** lane (`2026-08-28-lane-aiserver-gfx906.md`).
That is a different machine, so it is safe. But:

- **One worktree per session.** If the AI-server session commits to this repo too, create
  your own worktree rather than sharing the index:
  `git -C <main clone> worktree add .claude/worktrees/<name> feature/unsloth-direction`
- **Only ONE session may run inference on `framework` at a time.** Every driver here does
  `pkill -f '[l]lama-server'` before loading, so a second benchmarking session on the same
  box will silently kill your servers mid-run and produce garbage. Same rule for the HP.

## Startup block (subagent runs this; batch it)

```bash
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" log --oneline -10
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" status --short --branch
# Branch tracks `forgejo`. `origin` is the STALE GitHub mirror — never compare against it.

# Framework health + free space + what is currently serving
ssh framework 'ps -eo args | grep "[l]lama-server" | head -1 | cut -c1-140; df -h /mnt/ai-models | tail -1'

# Grader regression gate — MUST stay at 0 before and after any grader edit
cd "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" && python scripts/testing/test_grade_toolcall.py | tail -1
```

## Where things stand

The 2026-08-28 session built the Track 1 tool-calling harness and re-baselined the roster.
Two results define what to do next:

- **Tier 1 is saturated — 90/90.** Six models × three healing rungs × five cases, every cell
  passing. It answers "can this roster drive tools?" (yes) but **cannot rank anything.**
- **The clean leaderboard reordered.** Under `--disable-tools`, five of six models gained
  10–21%: Ornith-1.5 (64.5) > Nemotron-3.5 (63.1) > Qwen3.6-35B-MTP (61.3) > Qwen3-Coder-30B
  (43.7) > GLM-4.7-Flash (34.8) > gpt-oss-120b (33.1).

## Standing rules — do not relearn these

- **`--disable-tools` stays ON even for tool-calling runs.** It governs *server-side*
  built-ins (web search, code exec), which is a different mechanism from the *client-tool
  passthrough* (`tools:[...]`) under test. Also send `enable_tools: false` per request.
- **Run the `raw` rung alone by default.** The 3-rung healing ladder (`raw`/`healed`/`full`)
  separated nothing on this roster because no model needed repair. Apply the ladder
  *surgically* only to a model that fails at `raw` — the sole place it can change a verdict.
- **`unsloth run` silently accepts unknown flags.** A server starting is NOT evidence a flag
  was honoured. Verify behaviourally or in the source.
- **Grading expectations travel WITH each run** (`toolcall_cases.json` is copied into the run
  dir). Editing case definitions can never re-grade committed history — keep it that way.
- Fresh server per graded cell (bleed). `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` on every Strix
  Halo launch. llama-server ignores SIGTERM. Bracket pkill patterns (`[l]lama-server`) or
  tailscaled matches itself. Never cite the 204–225 t/s Qwen3.8 figures.
- **Never cite Qwen3-Coder-30B's 74.5 code figure.** It was speculation racing through
  ~3000 tokens of tool-loop boilerplate. True clean figure is ~43.6.

## What to do next (priority order)

1. **Harder tool-call cases — the headline gap.** Tier 1 cannot rank. Add: parallel /
   multi-call turns, nested and union-typed argument schemas, ambiguous tool selection,
   adversarial arg coercion. **Also rotate `tc_distractor`'s correct tool position** — it is
   currently always last of five, so positional bias is completely untested.
2. **Push the chain past 60.** Five models saturated the 60-call bar as well, so their real
   ceilings are still unknown. Use `toolcall_cases_deepchain.json`, raise `target_depth` and
   `pass_depth` together. (gpt-oss-120b already breaks at 31 by *fabricating* a terminal
   answer — reproducible across all three rungs. Do not re-litigate that; extend the others.)
3. **Grade a co-resident run.** `coresidency_test.py` measured throughput and health only. It
   does NOT establish that answers stay correct under contention — wire the graders in. This
   is the biggest unverified claim in the dual-agent architecture story.
4. **HP G1a validation (different box — safe to interleave).**
   `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` is staged there via `setx` but has **never been
   serve-verified on Windows**, and the unified-memory corruption bug is a Strix Halo defect,
   not a Linux one. Nothing on the HP is trustworthy until a graded battery runs there.
   Then light-pair co-residency (GLM 33 + Coder 34 = 67 GiB). **HP under Windows caps at
   96 GB — the heavy pair at 95 GiB will not fit; do not attempt it.**
5. **Nemotron-3.5 summarize second seed.** It failed on a missing literal `TL;DR` label with
   5 correct bullets; Nemotron-3-Nano shows the identical habit. Confirm family trait.
6. **DeepSeek context ceiling.** Ran pinned at 16384 for load safety; ~25 GiB KV budget
   remains after 97 GiB of weights. Real limit unmeasured.

## Section-scoped reads

- `.../docs/reference/PERFORMANCE-SUMMARY.md` §"Roster leaderboard" — current clean numbers. Rows marked ✅ were re-measured 2026-08-28 and supersede everything earlier.
- `.../docs/reference/UNSLOTH-DIRECTION.md` §"Track 1 — tool calling & agentic" — the Tier 1 result block and the two scoping corrections.
- `.../docs/reference/SERVING-GOTCHAS-STRIX-HALO.md` §(c) and §(d) — the three tool flags and why they differ. **§(a) is the unified-memory bug item 4 must verify.**
- `.../scripts/sweeps/toolcall_cases.json` — read FULL (~250 lines). New cases go here.
- `.../results/sweeps/2026-08-28-toolcall-tier1/manifest.yaml` §`caveats` — why 90/90 is a floor, not a ranking.
- `.../results/sweeps/2026-08-28-coresidency/manifest.yaml` §`caveats.no_quality_check` — exactly what item 3 must close.

## Harness map

| file | role |
|---|---|
| `scripts/sweeps/toolcall_battery.py` | Track 1 driver; fresh server per case; `--cases` and `--only` flags |
| `scripts/sweeps/sweep_toolcall.py` | owns `run_tool_case()` + the multi-turn loop |
| `scripts/sweeps/isolated_battery.py` | the 3-task text battery |
| `scripts/sweeps/coresidency_test.py` | two llama-servers on disjoint ports; also the plain-llama-server shim |
| `scripts/utils/grade_sweep.py` | graders, incl. the `toolcall` family; `--check` is the regression gate |
| `scripts/utils/summarize_toolcall.py` | renders the rung × case matrix |
| `scripts/testing/test_grade_toolcall.py` | 14 grader checks, no inference host needed |
| `scripts/testing/probe_healing_axis.py` | proves the healing axis is live (needed before reading anything into rung equality) |

Deploy pattern (drivers run ON the box): `scp` to `~`, then
`ssh framework 'sed -i "s/\r$//" ~/*.py ~/*.json'` — Windows checkouts are CRLF and both
python and bash choke otherwise. Launch detached with `setsid nohup ... & disown` and write
to a log; **do not** hold results in an ssh pipe, a dropped connection loses the run.

## Blockers

- **9 commits unpushed** — the Forgejo git handler is wedged (`/api/v1/version` answers in
  0.08 s while `info/refs` times out, for all repos). A separate lane owns the fix
  (`docker restart forgejo` in CT 237). **Do not retry pushes or `git ls-remote` here — they
  hang for minutes.** Just keep committing locally.
