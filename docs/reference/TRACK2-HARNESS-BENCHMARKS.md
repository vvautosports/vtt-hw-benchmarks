# Track 2 — Harness Benchmarks (design)

**Status:** approved design, 2026-08-28 (Kal's slice decisions inline). Implementation not started.
**Prereq reading:** [PERFORMANCE-SUMMARY.md](PERFORMANCE-SUMMARY.md) § Tool-calling — Track 1 settled the *model* axis; this track benchmarks the *harnesses around the models*.

## Why this track exists

Track 1 already proved, incidentally, that harness choice changes results as much as model choice:

- unsloth studio's auto-speculation is worth **+30% t/s** over direct llama-server on Nemotron-3.5 (`2026-08-28-ab-nemotron-framework`)
- the direct llama-server path **flips grades** on Nemotron (whole answer routed into `reasoning_content`, both OSes) — serving harness changes *correctness*, not just speed
- the parallel-call defect is unrescuable server-side (`2026-08-28-parallel-rescue`) — meaning *client* harnesses that serialize tool calls will mask it and ones that rely on parallel emission will trip it

Two orthogonal axes follow.

## Track 2A — Agent-harness battery (client axis)

Same model + same server; swap the agent. **Slice 1 scope (decided): all seven.**

| Agent | One-shot invocation | Notes |
|---|---|---|
| Claude Code | `unsloth start claude` + `-p` | primary VVC driver |
| OpenAI Codex | `unsloth start codex --persist` | **requires GGUF via llama-server backend** — useful forced-path control |
| OpenCode | `unsloth start opencode run "..."` | in the devbox toolset |
| Hermes Agent | `unsloth start hermes --persist --oneshot "..."` | |
| OpenClaw | `unsloth start openclaw --persist agent --local --session-id <id> --message "..."` | |
| Pi | `unsloth start pi --persist --print "..."` | |
| DeepSeek Harness (dsh) | `npx @deepseek-ai/dsh` headless, pointed at our endpoint | MIT, model-agnostic, plugin-based; **developer preview — pin the version per run, expect churn** |

`unsloth start` handles endpoint/key/model/context wiring per agent and supports pinned sampling flags (`--temp/--top-p/--top-k/--reasoning-effort`) — use it as the launcher wherever supported; dsh is launched directly. `--yolo` (non-prompting mode) is required for unattended runs and is acceptable **only inside disposable fixture checkouts**.

### The task battery (decided: 5 execution-graded micro-tasks)

Grading is **execution-based** (workstream F): pass = the fixture's test suite goes green after the agent runs. No LLM judges, no transcript grepping for correctness.

1. **fix-failing-test** — small repo, one deliberately broken function, failing pytest; agent told "make the tests pass."
2. **implement-from-doctests** — empty function body + rich doctests (the Track 1 `parse_ranges` spec, promoted to execution grading).
3. **multi-file refactor** — rename/re-signature a function used across 4–5 files; tests assert the new API and old-name absence.
4. **tool-heavy search-and-edit** — config value scattered across files with decoys; tests assert every real site changed, decoys untouched. (Exercises the tool-call loop hardest — where the Tier 2 traits will surface end-to-end.)
5. **small feature + tests** — add a tiny feature AND its tests; grade = new tests pass and a hidden acceptance test passes.

Fixture rules: one git repo per task under `tasks/fixtures/`; runner copies to a scratch dir per cell (never in-place); deterministic `grade.sh` per fixture (exit 0 = pass); agent prompt text versioned with the fixture.

### Metrics per cell

- task pass/fail (execution), wall-clock, total tokens (server `/metrics` delta — agent-reported token counts are not comparable across harnesses), request count / turns, server-side t/s during the run, transcript captured for post-hoc analysis.

### Matrix sizing

First pass: 7 agents × 5 tasks × **1 model** (Qwen3-Coder-30B — the clean 7/7 coder champion) ≈ 35 cells. Widen to GLM-4.7-Flash and Qwen3.8-Flash-Next only after the runner is proven. Single seed initially; repeat-3 on any cell that decides a ranking claim.

## Track 2B — Serving-harness matrix (server axis)

Same model + same client (the existing text + Tier 2 batteries — they're plain OpenAI-style clients and run against any endpoint nearly unchanged); swap the server. **Slice scope (decided): vLLM is in** — the Phase-6 dual-machine architecture is built on it, so its single-node numbers are the future baseline, not an experiment.

| Server | Where | Notes |
|---|---|---|
| unsloth studio API | Framework | current production path (measured) |
| unsloth llama-server (direct) | Framework | measured; the MI50/gfx906 path |
| **mainline llama.cpp** | Framework | isolates what the unsloth fork adds |
| **vLLM** | Framework (single-node), later dual-node | **quant caveat below** |
| Ollama | Framework | popular baseline, GGUF |
| LM Studio server | G1a (:1234, already installed) | Windows-side comparison point |

**Quant-parity rule (decided 2026-08-28): GGUF only, for now.** Every engine cell serves
the exact same UD-Q8_K_XL GGUF artifact — that keeps every row a pure engine comparison.
For vLLM this means its GGUF loader is the tested path: if the shared artifact loads,
vLLM joins the matrix on equal footing; if it does not, the vLLM cell is recorded as
`gguf-load-failed` and vLLM's engine-native formats (safetensors/FP8/AWQ) become a
LATER, separately-labelled slice — never mixed into the GGUF ranking. Engine-native
format benchmarking is deferred, not cancelled (it matters for the Phase-6 dual-node
work), but it gets its own table when it happens.

**Grade fidelity is a first-class metric here** — the Nemotron channel-routing result proves servers can flip grades via template handling. Every server cell runs the graded batteries, not just throughput probes.

**Vision-capable models add the receipt battery (decided 2026-08-29).** For engine cells serving a vision-capable model (currently gemma-4-26B-A4B-it UD-Q8_K_XL + mmproj-F16, VISION-VALIDATED 31/31 tuned; Muse-Glimmer-30B parked pending per-family config work), the graded batteries include the 5-receipt extraction battery — `scripts/sweeps/receipt_battery_gen.py` writes images + truth into the run dir, `grade_receipt()` in `scripts/utils/grade_sweep.py` grades 31 fields, gated by `scripts/testing/test_grade_receipt.py`. Same quant-parity spirit: the mmproj artifact is pinned alongside the GGUF, and an engine that cannot load the mmproj records `mmproj-load-failed` rather than dropping the row silently.

## Topology (decided)

Co-located first (agents on Framework → localhost) for the whole main matrix; then **one remote config** (G1a → Framework over the Headscale mesh) on a subset to price the real devbox usage pattern.

## Build list (slice 1)

1. `tasks/fixtures/` — the 5 fixture repos + per-fixture `grade.sh` + prompt file
2. `scripts/agents/agent_task_battery.py` — runner: fresh fixture copy → launch agent one-shot → wait/timeout → run grade.sh → collect metrics (incl. server `/metrics` delta) → results.jsonl per the existing manifest conventions
3. Smoke: Claude Code × 5 tasks × Coder-30B, co-located
4. Then the 7-agent sweep; then Track 2B server matrix (cheap — battery reuse); then the remote config

## Open items / risks

- dsh is a developer preview (released 2026-08-13) — pin its version in every manifest.
- Codex constraint: GGUF + llama-server backend only.
- Per-agent token accounting is not apples-to-apples → server-side `/metrics` is the source of truth.
- `--yolo` safety: fixtures are disposable copies; runner must never point an agent at a real repo.
- Fixture contamination: tasks must not collide with training-famous puzzles; keep them boring and bespoke.
