# Session Continuation Prompt
**Generated:** 2026-08-29
**Ending phase:** Feature complete — vision-track port (receipt battery banked, task family built) — UNCOMMITTED, review-gated
**Starting phase:** Review + commit the vision-track changes, then the queued vision work

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (a cheap model tier is fine) to run the Section-scoped reads
below and return a ≤2K-word digest. ONLY that digest enters main context — never read the
files in the main thread. Switch the main thread to a higher model tier only when
implementation starts (switching mid-session re-prices the whole history).
Every path in this prompt is ABSOLUTE. (Cross-harness doctrine: vvt-omnigent ADR 0005.)

We're working on the vtt-hw-benchmarks repo at `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks`.
The vision-track changes live UNCOMMITTED in the worktree
`C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction`
on branch `feature/unsloth-direction` (open Forgejo PR #5). That worktree may also host an
active testing session — coordinate before touching its HEAD.

## Feature completed (this session)

**Branch:** `feature/unsloth-direction` (changes uncommitted by Kal's explicit review gate)
**PR:** Forgejo vvc/vtt-hw-benchmarks #5 (pre-existing; will carry these changes once committed)
**Files:** 4 modified + 3 new (171 insertions)

### What was done
- Banked the first vision-track run from expense-agent:
  `results/sweeps/2026-08-27-receipt-battery-g1a/` — manifest with round-1/round-2 tables,
  failure modes, run context (G1a Windows gfx1151, b10639 + UNSLOTH_DISABLE_UNIFIED_MEMORY=1,
  all UD-Q8_K_XL, schema-locked JSON), raw round-2 JSON, battery images + truth verbatim.
- Built the receipt task family per grade_sweep conventions:
  `grade_sweep.py` receipt family (rcpt01–rcpt05, behavior-identical port of expense-agent
  model_compare.py grading, truth travels in the run dir as `receipt_truth.json`),
  `scripts/sweeps/receipt_battery_gen.py` (deterministic generator, lazy-PIL),
  `scripts/testing/test_grade_receipt.py` (21-check no-inference self-test, pins the graded
  surface to 31 fields).
- `models-inventory.yaml`: gemma-4-26B-A4B-it → VISION-VALIDATED (31/31 tuned / 29/31
  untuned, mmproj-F16, judgment-call misses only); new Muse-Glimmer-30B entry (split
  verdict: bars.png smoke 2/2 PASS, receipt extraction FAIL as configured — 3/13 fields,
  3/5 empty responses, ~110 s/receipt; per-family config investigation queued, parked not
  disqualified); MiMo-V2.5 disqualification comment (~192 GB smallest sane quant vs
  ~122 GB ceiling, no download).
- `docs/reference/UNSLOTH-DIRECTION.md`: new "Vision track — first measurement" section
  (tables, verdicts, check-vision gotcha, task-family port notes); fixed the stale Track 3
  vision-projector bullet. `scripts/sweeps/README.md`: registered the generator + self-test.

### Test results
- `test_grade_receipt.py`: 21/21 pass (WSL python3, no inference host).
- `test_grade_toolcall.py` regression: 28/28 pass.
- `grade_sweep.py --check` on committed runs (2026-08-28-g1a-validation,
  2026-08-28-dayone-deepseek-muse): 0 records change.
- markdownlint (develop's config) + yamllint: clean on all changed files.

## Deferred / follow-up work
- **Vision serving driver** (deliberately not built blind): image-capable driver,
  fresh-server-per-task per the bleed protocol, `--disable-tools`; decide whether to vendor
  the extraction schema + system prompt (with the two round-2 rules) out of expense-agent
  `extract.py`/`config.json` or keep the harness in expense-agent.
- **Muse-Glimmer per-family config investigation** (chat-template × schema-locked-JSON
  interaction) before any vision-quality verdict on it.
- Real-photo receipt battery; vision quant ladder (Q8 vs Q4, Track 2 pattern).
- Pull gemma-4 `mmproj-F16.gguf` beside the Framework `/mnt/ai-models` copy before any
  Framework vision serve (validated only in the G1a HF cache).
- Ops gotcha now recorded: `/api/models/check-vision` serves a stale capability cache —
  trust `is_vision` from `/api/inference/load`.

## What to do next
1. Kal reviews the uncommitted vision-track changes in the unsloth-direction worktree;
   commit on `feature/unsloth-direction` (suggested: one `feat(vision)` commit).
2. Merge this session-prompt PR; clean up its worktree
   (`git worktree remove .claude/worktrees/session-prompt-vision-port`).
3. Continue the next testing wave (context already handed to that session via
   SendMessage 2026-08-29): Track 2 slice 1 per
   `.claude/session-prompts/2026-08-29-track2-slice1-build.md`, plus the deferred vision
   items above as hardware time allows.

## Section-scoped reads
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction\docs\reference\UNSLOTH-DIRECTION.md` — §"Vision track — first measurement" (near EOF, before References): settles every verdict and queued item.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction\results\sweeps\2026-08-27-receipt-battery-g1a\manifest.yaml` — read FULL: run context, tables, caveats, check-vision gotcha.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction\scripts\utils\grade_sweep.py` — §RECEIPT_TASKS + grade_receipt(): the new family's contract.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction\models-inventory.yaml` — §gemma-4-26B-A4B-it / §Muse-Glimmer-30B / MiMo comment: inventory status changes.
- `C:\Users\kalman9\Documents\vvc\expense-agent\docs\model-comparison-2026-08-27.md` — read FULL (53 lines): the source verdict.

## Blockers
- Review gate: nothing in the vision-track changeset is committed until Kal approves.
- Discord MCP bot token not configured on this machine — /done Discord post skipped.
- `forgejo-token` helper not seeded on the G1a (bootstrap-vvc-credentials.sh not run);
  Forgejo API calls fall back to the git credential store.

## Pending system-evolution items
None.

## Discord Thread
(none — Discord post skipped: bot token not configured on this machine)
