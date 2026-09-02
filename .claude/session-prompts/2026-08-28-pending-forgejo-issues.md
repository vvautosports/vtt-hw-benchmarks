# Pending Forgejo issues — file when git.vvautosports.com recovers

Written 2026-08-28 evening. Both the git smart-HTTP handler AND repo-scoped API routes
hang (HTTP 000; `/api/v1/version` answers fine) — the CT 237 git-handler wedge, owned by
the infra lane. When the forge is back: `/create-issue` with this file (Mode B), one
issue per section, repo `vvc/vtt-hw-benchmarks`.

---

## Issue 1 — fix: Nemotron-3.5 answers land in reasoning_content on direct llama-server serving

**Labels:** bug, priority:medium

### Expected Behavior
Serving NVIDIA-Nemotron-3.5-Lightning-30B-A3B via a directly-launched llama-server
(`--jinja`, no studio proxy) returns the model's answer in `message.content`, as the
studio path does.

### Actual Behavior
The entire answer is routed into `message.reasoning_content`; `content` is empty
(content_chars=0). Any consumer reading the content channel gets nothing. Reproduced on
BOTH boxes (framework Linux and HP G1a Windows), all phases including solo — a property
of the direct serving path, not the box, OS, or contention.

### Evidence
- `results/sweeps/2026-08-28-g1a-coresidency/` — Nemotron grades 1/3 in all three phases
  (code cell: content empty, full doctest answer in the reasoning section); caveat block
  documents the diagnosis
- `results/sweeps/2026-08-28-ab-nemotron-framework/` — identical grade pattern on Linux
- Same-day studio-path control: `results/sweeps/2026-08-28-g1a-validation/` grades the
  same model 3/3 text
- The serve log hints the fix: "chat template supports preserving reasoning, consider
  enabling it via --reasoning-preserve"

### Tasks
- [ ] Reproduce with `--reasoning-preserve` and/or `--chat-template-kwargs` variants on a
      direct llama-server launch (framework, build 10639/2a36554fc)
- [ ] Identify the minimal flag set that puts answers in `content`
- [ ] Re-grade one 3-task battery cell set to confirm 3/3 on the direct path
- [ ] Record the required flags in `docs/reference/SERVING-GOTCHAS-STRIX-HALO.md`

### Success Criteria
- [ ] Direct-llama-server Nemotron battery grades match the studio path (3/3 text)
- [ ] Flags documented; MI50/gfx906 plan (which depends on direct llama-server) unblocked

---

## Issue 2 — chore: G1a llama-server wedge — request accepted, gen_tok_s=0 indefinitely

**Labels:** bug, priority:low

### What happened
During the 2026-08-28 Nemotron TL;DR seed probe on the HP G1a (Windows), the seed-44
serve wedged: `/health` ok, request accepted (`running: 1`), but `engine_stats` reported
`gen_tok_s: 0.0` indefinitely; the client timed out after 30 minutes on a ~3-minute
request. First wedge observed on this box — the 5th consecutive fresh server load of the
evening. Killed cleanly; not reproduced since.

### Evidence
- `results/sweeps/2026-08-28-nemotron-tldr-seeds/manifest.yaml` (incident block) and
  `serve-seed44.log` in the same run dir

### Tasks
- [ ] On recurrence: capture the spawned llama-server log
      (`~/.unsloth/studio/logs/llama-server/`) before killing
- [ ] Add a per-request watchdog to the G1a drivers (`g1a_validation.py`,
      `g1a_coresidency.py`): timeout at ~3x expected wall, kill + record + continue —
      the framework drivers' equivalent protection
- [ ] Track frequency; if >1 in 20 loads, escalate to a dedicated repro run

### Success Criteria
- [ ] G1a batteries survive a wedged cell without losing the run
- [ ] Wedge frequency data exists after the next few G1a sessions

---

## Issue 3 — feat: standing dual-model serve pair + role-named LiteLLM routes
**REPO: vvc/vvt-devbox** (not hw-benchmarks — set OWNER/REPO by hand in /create-issue)
**Labels:** enhancement, priority:medium

### Goal
Make the benchmark-validated dual-agent serving config a standing, addressable service:
GLM-4.7-Flash (orchestrator) + Qwen3-Coder-30B (sub-agent) co-resident on the Framework
box, reachable by ROLE via LiteLLM. Scope approved by Kal 2026-08-28: serve + routes
only — no agent-loop code (that is omnigent/4-window-framework work with its own design).

### Current State
The Framework serves one model at a time via unsloth studio on :8888; model choice per
task is manual. Benchmarks (vtt-hw-benchmarks, 2026-08-28) validated the pair
co-resident: 74.3 GiB resident, ~48 GiB headroom, 18/18 graded cells correct across
solo/sequential/concurrent, ~30 t/s each under worst-case contention (GLM −10%,
Coder −32%). Direct llama-server (not studio) is the tested path — both models emit
gradeable content on it (unlike Nemotron, see the reasoning_content issue).

### Tasks
- [ ] Launch script (or systemd units) for the pair: direct llama-server, GLM-4.7-Flash
      UD-Q8_K_XL :8801 + Qwen3-Coder-30B UD-Q8_K_XL :8802, ctx 32768 each, `--jinja
      -ngl -1 --flash-attn on --no-context-shift`, health-check loop (mirror
      vtt-hw-benchmarks `scripts/sweeps/coresidency_test.py` launch block)
- [ ] LiteLLM config: role-named routes `vvc-orchestrator` → :8801, `vvc-coder` → :8802
- [ ] Encode the routing policy in the config comments/docs: parallel-tool-call turns
      must never route to Nemotron-3.5 or gpt-oss-120b (defect is unrescuable —
      hw-benchmarks `2026-08-28-parallel-rescue`)
- [ ] Document coexistence with benchmarking: bench sessions kill llama-server; the pair
      is preemptible, restart via the launch script
- [ ] Smoke test from one consumer (Claude Code or OpenCode) hitting both routes

### Success Criteria
- [ ] Both routes answer chat completions through LiteLLM by role name
- [ ] Pair survives a reboot / restarts with one command
- [ ] Docs state the preemption rule and the no-parallel-fan-out policy

### Context
Evidence base: vtt-hw-benchmarks `results/sweeps/2026-08-28-coresidency/` (throughput +
heavy-pair rejection), `2026-08-28-coresidency-graded/` (18/18 correctness),
`2026-08-28-parallel-rescue/` (routing rule), PERFORMANCE-SUMMARY.md § Tool-calling.
Host decision: Framework (accepted tradeoff: bench sessions preempt the pair).

---

## Issue 4 — feat: Track 2 harness benchmarks — agent battery + serving matrix
**REPO: vvc/vtt-hw-benchmarks**
**Labels:** enhancement, priority:medium

### Goal
Benchmark the harnesses around the models, both axes: (2A) seven agent CLIs (Claude
Code, Codex, OpenCode, Hermes, OpenClaw, Pi, DeepSeek dsh) on execution-graded
micro-tasks against the same model+server; (2B) six serving stacks (unsloth studio,
unsloth llama-server, mainline llama.cpp, vLLM, Ollama, LM Studio) under the existing
graded batteries. Design approved by Kal 2026-08-28; full spec in
`docs/reference/TRACK2-HARNESS-BENCHMARKS.md`.

### Tasks
- [ ] Build the 5 execution-graded fixture repos + per-fixture grade.sh (spec § task battery)
- [ ] Build scripts/agents/agent_task_battery.py (fresh fixture copy, one-shot agent
      launch, timeout, execution grading, server /metrics token delta)
- [ ] Smoke: Claude Code x 5 tasks x Qwen3-Coder-30B, co-located on Framework
- [ ] 7-agent sweep (35 cells), then widen models
- [ ] Track 2B server matrix via existing batteries — GGUF-only rule: every engine
      serves the same UD-Q8_K_XL artifact; vLLM via its GGUF loader (record
      gguf-load-failed if it won't; engine-native formats are a later labelled slice)
- [ ] One remote config (G1a -> Framework over mesh) to price real devbox usage

### Success Criteria
- [ ] An agent-harness leaderboard with execution-graded pass rates + cost metrics
- [ ] A serving-harness table with t/s AND grade fidelity per engine
- [ ] Findings recorded in PERFORMANCE-SUMMARY.md with per-run manifests
