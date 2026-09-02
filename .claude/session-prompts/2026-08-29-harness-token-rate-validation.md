# Next session — agentic harness token-rate validation (Unsloth Desktop as driver)

## Startup (per session-startup doctrine — ONE Explore subagent, digest only)

Spawn one Explore subagent to read and digest:
- `docs/reference/UNSLOTH-DIRECTION.md` (this worktree) — current roster, per-family
  config registry, fresh-server protocol
- `models-inventory.yaml` — tps/quality/required_flags per model
- `C:\Users\kalman9\Documents\vvc\expense-agent\docs\model-comparison-2026-08-27.md`
  — the vision-track battery result (gemma-4-26B-A4B 31/31 receipt extraction)
- Recent `git log --oneline -15` in this worktree (the vision-track port from
  expense-agent may have landed — session task_7fd368b5 was porting it)

## Objective

**Validate that an agentic harness driven from Unsloth Desktop ITSELF does not
kill token rates.** Kal's stated vision: the Desktop app is the driver — NOT
Claude Code or another terminal coding agent pointed at the local server
(`unsloth start <agent>` exists and works that way, but it is at most an
optional comparison arm, not the subject).

Harness overhead theory to test: system prompts + tool schemas + multi-turn
tool loops inflate prompt tokens; on local serving, prompt processing and
KV growth are where t/s dies. Measure it, don't assume it.

## Where

Framework Desktop (Fedora, Strix Halo) — Unsloth Desktop is installed there
(RDP was enabled 2026-08-16 specifically for driving its GUI from the G1a);
the env fix `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` is already permanent there.
Fallback/second datapoint: devbox-1 ThinLinc VM (192.168.7.91).

## Known facts to build on (established 2026-08-27/28 on the G1a, expense-agent work)

- Studio backend has server-side tools: web search + code execution
  (`--enable-tools`; `unsloth studio run` defaults them ON; the off direction
  applies server-wide when disabled).
- `studio.db` schema contains `mcp_servers`, `research_runs`,
  `research_plan_steps`, `research_sources`, `research_events` tables →
  the Desktop app has native MCP support + a research/agent mode. First step:
  inventory what Settings/UI actually exposes (MCP server config, tools
  toggles, research mode) — screenshots into the session record.
- `engine_stats` log lines emit `gen_tok_s` / `prompt_tok_s` per 10s window;
  `/v1/chat/completions` returns usage tokens; `/api/inference/status` shows
  the active model. Auth: bearer keys in shared auth.db work across server
  instances (G1a key lives in Vaultwarden item "expense-agent studio" — mint a
  Framework-local one the same way if needed:
  `unsloth_cli.commands.studio._create_api_key_inprocess`).
- gemma-4-26B-A4B reports `supports_tools: true` at load; it is the
  efficiency pick (3/3 battery, ~36 t/s bare) AND the receipt-vision winner.

## Experiment design (adjust with judgment)

Matrix, per model — gemma-4-26B-A4B first, then Nemotron-3.5-Lightning
(speed leader), Qwen3.6-35B-MTP (does MTP survive tool use?), optionally
Qwen3.8-Flash-Next (thinker):

1. **Baseline**: bare chat, no tools — should reproduce roster t/s numbers.
2. **Tools declared, unused**: same prompts with tools enabled — isolates
   schema/prompt-bloat cost (prompt_tok_s hit, per-task wall clock).
3. **Tool loop**: tasks that require 2-5 tool calls (web search question,
   code-exec computation, and an MCP tool if the Desktop UI exposes config) —
   measure end-to-end wall clock, total tokens, effective t/s, and correctness.

Record per the sweep conventions (spec entries carry `flags`/`env`; results
into `results/sweeps/2026-08-29-harness-overhead/` or similar). Fresh server
per task remains ground truth on b10639 (cross-request bleed).

## Constraints / reminders

- Per-family configs are policy (best model at best-known config).
- `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` on every Strix Halo launch; opt-out must
  UNSET, `=0` does nothing.
- Never cite `gtt_used_mib`; ~122GB usable ceiling.
- Studio `/api/models/check-vision` can serve a stale capability cache —
  trust `/api/inference/load` / `/api/inference/status` responses.
- No commits without Kal's review.

## Why this matters (context)

The expense-agent pipeline (vvc/expense-agent) currently uses Claude Code as
orchestrator + local model for perception only. Kal's direction: move the
driving to Unsloth Desktop over time. This session decides whether harness
overhead makes that viable at local token rates, and which model family
drives best. Tool-calling is also the #1 unmeasured track in
UNSLOTH-DIRECTION.md — this doubles as its first measurement.
