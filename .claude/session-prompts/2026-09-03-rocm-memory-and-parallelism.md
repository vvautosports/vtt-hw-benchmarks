# Session Continuation Prompt
**Generated:** 2026-09-03
**Ending state:** Track 2A blocked; root cause narrowed to ZERO PREFIX CACHE REUSE (see BREAKTHROUGH)
**Starting state:** test LLAMA_ARG_CACHE_RAM (one env var, one cell), then MLflow wiring, then AI-server parallelism

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent to run the Startup block and the Section-scoped reads, and return
a ≤2K-word digest. ONLY that digest enters main context. Switch the main thread to a higher
tier only when implementation starts. Every path below is ABSOLUTE.
(Doctrine: vvt-omnigent ADR 0005.)

Repo: `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks`, Forgejo-primary
(`git.vvautosports.com/vvc/vtt-hw-benchmarks`). Push via the `forgejo` remote; `origin` is a
stale GitHub mirror and `gh` lies here. Worktree in use:
`.claude/worktrees/battery-rerun` on `feature/battery-rerun`.

## Startup block

```bash
# 1. Is the Framework healthy and is exactly ONE serve running? (see "the orphan trap" below)
ssh framework 'free -g | sed -n 2p; grep SUnreclaim /proc/meminfo; \
  ss -ltnp 2>/dev/null | grep 8888; \
  for p in /proc/[0-9]*; do e=$(readlink $p/exe 2>/dev/null); case "$e" in *llama-server) echo "child ${p#/proc/}";; esac; done'

# 2. Gates (WSL — native Windows lacks python3)
wsl -e bash -lc "cd /mnt/c/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/battery-rerun && \
  python3 scripts/testing/test_fixtures.py | tail -2 && \
  python3 scripts/testing/test_grade_toolcall.py | tail -1 && \
  python3 scripts/testing/test_grade_receipt.py | tail -1"
# expect: 'all 25 fixture checks passed' / 'all 28' / 'all 21'   (25, not 20 — PR #17 added checks)

# 3. Is the AI server back on the mesh yet? (was down all of 2026-09-03)
ping -n 2 100.64.0.39
```

---

## THE HEADLINE: four wrong theories, then the real one

Track 2A cannot produce valid cells. **The current best explanation is that every agent turn
reprocesses its entire context (zero prefix cache reuse), most likely because llama.cpp's
`--cache-ram` defaults to 8 GB and we never set it.** The memory blowup appears to be a
downstream symptom. Full evidence in the BREAKTHROUGH section at the bottom — read that first.

Four earlier explanations were WRONG and are still recorded in issue #12 and in older run
CAVEATS files. Do not trust those without reading this table.

| # | Theory | Verdict |
|---|--------|---------|
| 1 | "Auto ctx 202752 x --parallel 4 is the memory bomb" (issue #12 as written) | **WRONG.** Pinned `-c 65536 --parallel 1`, verified on the live child, still exhausted the box. |
| 2 | "Unreclaimable slab leaks and ratchets; reboot per battery" | **HALF RIGHT.** It does NOT leak forever (drains over hours), but it DOES ratchet within a session: 32 GB was still held with zero children, GTT at 0.0 and no process above 158 MB RSS. |
| 3 | "Stale orphan serves stacking is the whole problem" | **PARTLY RIGHT — fixes the baseline only.** Real, and now fixed by `serve_pinned.sh`, but growth persists with exactly one clean serve. |
| 4 | "`UNSLOTH_DISABLE_UNIFIED_MEMORY=1` causes it" | **WRONG.** A/B'd: flag removed was slightly WORSE (36.3 GB peak vs 30.7). Exonerated. |
| 5 | **Zero prefix cache reuse; `--cache-ram` default of 8 GB forces evict-and-reprocess every turn** | **CURRENT. Test this first — it is one env var and one cell.** |

### The orphan trap (real, fixed, keep the fix)
A studio parent can keep **LISTENING on 8888 after its model is gone**. A new `unsloth run`
then fails to bind, spawns an **orphan studio + child on a random port**, and every agent still
talks to 8888 and gets `No model is currently resident`. Orphans stack, each holding a model
copy in GTT — that is what drove the baseline to 103 GB on 2026-09-02.
Found via: two `unsloth run` parents alive (PID 176235 from 21:25 the previous night owning
8888 with no model; PID 278758 from 07:17 with the real model on port 39781).

**Two harness bugs of mine caused the overnight wipeout (30/30 cells lost). Both are fixed in
`~/serve_pinned.sh`, but the same traps exist anywhere else you script this:**
1. `curl http://127.0.0.1:8888/health` returns the studio **SPA index.html with HTTP 200** even
   with no model resident. It is a frontend catch-all, NOT a health probe. The real check is
   `unsloth start claude --no-launch`, which exits **non-zero** with "No model is currently
   resident".
2. `out=$(cmd | tail -4); rc=$?` captures **tail's** status, always 0. Every dry-run "passed".
   Use `PIPESTATUS` or do not pipe.

### What the current bug actually looks like
Run A, one `config-sweep` cell from a genuinely clean baseline, 10.2 minutes
(`results/sweeps/2026-09-03-clean-baseline-ab/memory.log`, 36 rows):

- used **44.5 GB -> 112.3 GB** = **+67.8 GB, ~6.6 GB/min**, min available **5.3 GB**
- **GTT flat at 39.4-39.5 GB** the whole time; `children=1` the whole time
- `SUnreclaim` **0.58 -> 30.7 GB**; llama-server RSS **1.2 -> 8.8 GB**
- cell result: FAIL, 600s timeout, ptok 147131, gtok 926, **wall_tps 1.54**

So the growth is host memory outside the GPU allocation, mostly unreclaimable kernel slab,
accumulating per-request and released only at process exit. No baseline is large enough; a
clean start only buys a few extra minutes.

### The experiment that was in flight when this session ended
**A/B of `UNSLOTH_DISABLE_UNIFIED_MEMORY=1`** — it is set on every serve here (it was the
b10639 regression fix). Suspicion: on an APU whose VRAM *is* system RAM, disabling unified
memory forces separate allocations instead of shared pages.

Crucially, **the runtime is now build 10687**, past b10639 — so the flag may no longer be
needed and may now be pure harm. Scripts on the box:
- `~/serve_pinned.sh` — flag SET (control)
- `~/serve_pinned_unified.sh` — flag REMOVED (variant)
- `~/run_ab.sh` — same single `config-sweep` cell, samples avail/SUnreclaim/gtt every 15s
  into `~/ab-unified-2026-09-03/memory.log`

**RESULT: the flag is EXONERATED — theory 4 is also wrong.**

| | A (flag SET) | B (flag REMOVED) |
|---|---|---|
| SUnreclaim peak | 30.7 GB | **36.3 GB** |
| min available | 5.3 GB | **1.6 GB** |
| cell outcome | fail, 600s timeout | fail, 600s timeout |
| ptok / gtok | 147131 / 926 | 124404 / 1002 |
| wall tok/s | 1.54 | 1.67 |
| OOM kills | yes | 0 |

Both grow ~30-36 GB of slab and exhaust the box. B only sawtooths (partial reclaim: climbs
to 23 GB, falls to 15.6, climbs again to 36.3) and survived to timeout rather than being
killed. Removing the flag is a marginal improvement at best, NOT a fix.

## THE STRONGEST REMAINING LEAD — chase this FIRST, before more memory forensics

**Throughput is ~1.6 tok/s.** This class of model benchmarks at **~63 tok/s on the Framework**
(memory `[[project_unsloth_b10639_regression]]`). That is ~40x off, and the token split says
why: **~147k prompt tokens against ~1000 generated**. The cell is PROMPT-BOUND, not
generation-bound — the agent reprocesses an enormous context every turn.

Every transcript in every run contains this line:

`[claude-code:unrecognized_model] {"model":"Qwen3-Coder-30B-A3B-Instruct-UD-Q8_K_XL","query_source":"sdk"}`

Hypothesis: Claude Code does not recognize the model alias, so it is **not doing prompt
caching**, and re-sends the full context each turn. That one fault would produce every
observed symptom at once — huge ptok, trivial gtok, ~1.6 tok/s, per-request allocation
growth, and eventual exhaustion. **The memory blowup may be a SYMPTOM, not the disease.**

Two cheap decisive tests, one cell each:
1. Serve under a model alias Claude Code recognizes (or map the alias), re-run ONE cell, and
   watch whether ptok collapses and tok/s jumps.
2. Run the same fixture with a NON-Claude agent on the same serve (pi and opencode are
   installed). If they show normal tok/s, the fault is Claude-Code-side, not the serve.



---

## Status

### Shipped
- **PR #17** (open, green, mergeable, NOT merged):
  `https://git.vvautosports.com/vvc/vtt-hw-benchmarks/pulls/17`
  Restores `tasks/fixtures/config-sweep/fixture/archive/2025-field-capture.log`, which
  `.gitignore`'s generic `*.log` had silently swallowed in `42f2fd3`. `protected.txt` listed it
  as a decoy and the hidden test asserts on its contents, so **config-sweep was unsolvable by
  any agent in any clean checkout**. Also negates `tasks/fixtures/**`, adds a portable
  "protected paths exist in fixture/" check, and **adds the three python gates to Forgejo CI,
  which linted only** — that gap is how it shipped. Gate proof: CI verified empirically by
  pushing a throwaway branch with the decoy removed and confirming red.
- All six agent CLIs installed on the Framework, unified on **Node v22.23.1**:
  claude, codex, opencode, openclaw, hermes, pi.

### Agent install recipes (confirmed from unsloth's own `unsloth_cli/commands/start.py`)
Do NOT guess npm names — two of these bite.
- codex: `npm install -g @openai/codex`
- opencode: `npm install -g opencode-ai` (v2 variant: `@opencode-ai/cli@beta`)
- pi: `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`
- hermes: installer from **NousResearch/hermes-agent pinned to commit
  `f1af945f6c576eccb126fa955edc9be258b33020`**, `--skip-setup --commit <that>`.
  The npm package `hermes-agent` is published by `wyrtensi` and is **NOT** Nous Research.
- openclaw: `npm install -g openclaw@2026.8.2`. A bare `npm i -g openclaw` installs a **0.0.1
  stub with no binary** because openclaw needs Node >= 22 and npm silently downgrades.
  The openclaw.ai installer wants **sudo to upgrade Node** — do not let it; use nvm v22.
- Hermes requires **>= 65536 context** (`_HERMES_MIN_CONTEXT`). The 32768 originally planned
  would have made it unusable.

### Remaining, in priority order
1. **Finish the A/B and fix the memory pathology.** Everything else on this box is blocked
   behind it. Track 2A has produced exactly ONE valid cell across three nights.
2. **Wire benchmark flows to MLflow** (Kal's ask, 2026-09-03). MLflow is live now. Every run
   this session had to be reconstructed from process tables and kernel logs; registering run
   params (model, `-c`, `--parallel`, env flags) and the memory curve as metrics would have
   made the orphan wipeout obvious instantly. Do this BEFORE the AI-server matrix so that data
   lands in MLflow from the start.
3. **AI-server parallelism matrix** (Kal's ask, for "tonight" 2026-09-03 — slipped, box was
   unreachable). See below.
4. Re-run the 5-cell battery once memory is fixed; then the 6-agent matrix.
5. Issue #12 needs rewriting — its stated root cause is wrong (see the table above).

### Deferred / unchanged
- #14 MTP re-baseline (wants runtime >= b10715; currently 10687)
- #15 EvalScope lane (needs the package installed on the box)
- dsh / DeepSeek Harness: `npx @deepseek-ai/dsh`, launched **directly, not via `unsloth start`**,
  so it needs its own endpoint wiring. Repo records it as MIT, model-agnostic, developer
  preview (2026-08-13), "pin the version per run". No arch caveat recorded for dsh — the "arch"
  concern Kal remembered is most likely **MI50 = gfx906** on the AI server, not DeepSeek.

---

## AI-server parallelism matrix (next session, gated on access)

**Goal (Kal's words):** find whether 2x or 4x GPU configs are better or worse than 6x
individual cards at smaller model sizes, pushing parallelism hard. Ranking axis chosen:
**aggregate throughput under concurrency** (total tok/s + per-user latency with N concurrent
users), not max model size. Full isolation is NOT required except for the single-GPU-alone
baseline.

**Box:** `cincy-aiserver-pve-12` / `aiserver`, Headscale `100.64.0.39`, LAN `192.168.50.73`,
56 vCPU dual Xeon, **6 x AMD Radeon Instinct MI50 32GB HBM2** (192 GB total, 1 TB/s each,
PCIe 4.0 x16 each).

**BLOCKER:** unreachable all of 2026-09-03. `cincy-k10` (100.64.0.14) answers at 135 ms, so the
Cincinnati mesh is fine, but `100.64.0.39` is 100% packet loss and SSH times out — the
runbook's `tailscaled`-died signature. Needs Kal or Opa to start tailscaled. **Do not design
against the documented specs** — memory records that its CPU/GPU/RAM all differ from the infra
docs, so probe first.

**Two caveats that must be settled before the matrix is designed:**
1. **gfx906.** MI50 is gfx906, dropped from recent official ROCm support. Given we spent this
   whole session on a ROCm memory pathology on the *other* box, pin down what ROCm/llama.cpp
   build actually runs on gfx906 there FIRST — otherwise the matrix measures driver behavior
   and calls it topology. Jordan owns thermal tuning on that box and is the person to ask.
2. **Host contention.** With 56 vCPU and uncertain RAM, 6 concurrent serves will likely contend
   on host CPU and RAM (KV, page cache, sampling threads) rather than GPU. A naive 6x test can
   look falsely bad for independent serves when it is really measuring the host. The matrix
   MUST instrument per-serve CPU, RSS, and prompt-processing wait alongside tok/s.

**Shape:** baseline single GPU alone (clean reference), then sharded 2x and 4x
(`--tensor-parallel` splits by tensor; default splits by layer — test both), then 6x
independent serves, each under a concurrency ladder (1/2/4/8 users). EvalScope's `perf`
concurrency ladder (#15) is the natural driver and would answer #14's concurrency question too.

---

## Section-scoped reads
- `results/sweeps/2026-09-03-clean-baseline-ab/memory.log` — the 36-row growth curve. The
  primary evidence.
- `results/sweeps/2026-09-03-clean-baseline-ab/FINDING-memory-2026-09-02.md` — read FULL,
  INCLUDING the correction appended at the bottom. The top half is the falsified theory.
- `results/sweeps/2026-09-02-agent-smoke/CAVEATS.md` — the older per-cell validity table. Its
  root-cause prose is superseded by this prompt.
- `scripts/agents/README.md` — deploy model (scp + CRLF strip), spec shape, metrics.
- `scripts/agents/agent_task_battery.py` §docstring + §`preflight_toolcall` — CLI flags and
  what the preflight guarantees (it works; it caught nothing this session because the serve
  was genuinely healthy at start each time).
- `docs/runbooks/agentic-crash-recovery.md` — box-down triage, WOL, **the tailscaled literal
  trap** (bit me twice this session: `pgrep -f "llama-server"` matches your own ssh argv, and a
  pattern-kill killed my own session).

## Box scripts (on framework, not yet committed — consider committing)
- `~/serve_pinned.sh` — clean-slate teardown, asserts >90 GB free and exactly 1 parent + 1
  child, waits on REAL residency. **Use this instead of `relaunch_qwen.sh`, which pins nothing
  and is what produced the original memory bomb.**
- `~/serve_pinned_unified.sh` — same, env var removed (A/B variant)
- `~/run_ab.sh`, `~/run_clean_battery.sh`, `~/overnight.sh` (the last has the two fixed bugs
  described above — re-read before reuse)

## Blockers
- Framework: the memory pathology (item 1). One valid cell in three nights.
- AI server: off the mesh, needs hands.
- `/proc/slabinfo` needs root and sudoers here has `use_pty`, so the exact leaking slab cache
  could not be named over non-interactive SSH. Ask Kal to run
  `sudo slabtop -o | head -15` during a cell if the A/B does not settle it.

---

## FINAL DIAGNOSIS (2026-09-03 ~11:30) — supersedes the theory table above

Measured with **0 llama-server children, GTT at 0.0 GB, and no process above 158 MB RSS**:

```
Slab:        32123868 kB
SUnreclaim:  31976540 kB      <-- 32 GB held with NOTHING running
Mem:  124 total / 62 used / 61 available
```

**Each agentic cell leaks ~30 GB of unreclaimable kernel slab that SURVIVES process exit
and drains only over hours.**

This partially rehabilitates theory 2, which I wrongly discarded. It looked "released" at
06:47 only because the box had idled ~9 hours overnight and drained. Within a working
session it absolutely ratchets:

- run 1 from a clean boot gets furthest (81 GB headroom)
- each subsequent run starts lower — that is exactly how 2026-09-02 reached a 103 GB
  baseline before its cell even began
- `serve_pinned.sh`'s ">90 GB available" guard now correctly REFUSES to launch on a
  degraded box (it fired at 73 GB and again at 64 GB), which is the right behavior — do
  not weaken that threshold to force a run through

It is kernel/driver memory, not application memory: no process owns it, GTT is zero, and
`echo 3 > /proc/sys/vm/drop_caches` will not touch SUnreclaim.

### Practical consequences for the next session
1. **You get roughly ONE good agentic cell per boot.** Plan around that until it is fixed.
   A 5-cell battery, let alone a 30-cell matrix, cannot complete on this box today.
2. The `>90 GB` guard is load-bearing. If it refuses, the box needs a reboot (or a long
   idle), not a smaller threshold.
3. Prime suspect is the ROCm/HSA path in llama.cpp build 10687. **Bumping the runtime to
   >= b10715 is now the top infrastructure task** — #14 already wants that bump for MTP, so
   the two justify each other.
4. Name the leaking cache to confirm: `sudo slabtop -o | head -15` during and after a cell.
   Needs Kal at a terminal — sudoers here has `use_pty`, so it cannot be done over
   non-interactive SSH.
5. Still worth doing FIRST because it is cheaper and may explain the whole thing: the
   `unrecognized_model` / prompt-caching lead above. ~1.6 tok/s with 147k prompt tokens
   against 926 generated means the agent reprocesses its whole context every turn — which
   would also be what drives the per-request slab allocation. Fix the caching and the leak
   rate may drop below the point where it matters.

---

## BREAKTHROUGH (2026-09-03 ~11:35) — ZERO PREFIX CACHE REUSE. Start here.

This is very likely the primary bug, and the memory leak may be downstream of it.

### Evidence
From the llama-server child log (`~/.unsloth/studio/logs/llama-server/llama-*.log`):

```
task 1150 | prompt processing, n_tokens = 16384, progress = 0.63, t = 22.24 s / 736.63 t/s
task 1150 | prompt processing, n_tokens = 20480, progress = 0.79, t = 30.65 s / 668.28 t/s
task 1150 | prompt processing, n_tokens = 26035, progress = 0.94, t = 40.10 s / 612.84 t/s
task 1150 | stop processing: n_tokens = 26035, truncated = 0
```

`progress` climbing from 0 to 1 means the slot reprocesses the **ENTIRE context every
turn**. With working prefix reuse, progress would start near 1.0 and only the new tokens
would be processed.

Arithmetic checks out exactly: ~26k context reprocessed per turn at ~650 t/s = ~40 s/turn;
~15 turns in a 600 s cell = ~147k prompt tokens. That is precisely the measured ptok, and
it means **the cell spends 100% of its budget on prompt processing** and only emits ~900
tokens.

**Prompt processing speed (~650 t/s) is FINE.** Nothing is slow. The box is doing roughly
15x more work than necessary.

### Why it is probably happening
`unsloth_cli/commands/start.py::_claude_local_env` sets, among others:

```python
"CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1",
...
env["CLAUDE_CODE_AUTO_COMPACT_WINDOW"] = str(int(window))   # 65536 here
env["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"] = "90"               # compacts at ~59k
```

Anthropic prompt caching is a **beta** (`cache_control`). With experimental betas disabled,
Claude Code will not emit cache directives. Separately, llama.cpp only reuses a slot prefix
when the request carries `cache_prompt` (and `--cache-reuse` governs partial reuse), so if
the studio's Anthropic proxy does not set it, every request is a cold prompt.

Also note the earlier incident log line "a 2.3 GiB prompt-cache eviction" — consistent with
cache thrash rather than reuse.

### Tests, cheapest first (all need only ONE cell)
1. Check whether the studio proxy sends `cache_prompt` to llama.cpp. If not, that is the
   bug. Look for the proxy's request construction in
   `studio/backend/core/inference/` (the `anthropic` proxy path).
2. Launch the serve with llama.cpp `--cache-reuse` set (and confirm `cache_prompt`
   defaults) and re-run one cell. Watch whether `progress` starts near 1.0 and ptok
   collapses.
3. Unset `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` for the agent env and re-run one cell.
4. Cross-check with a non-Claude agent (pi/opencode are installed) on the same serve — if
   they show prefix reuse, the fault is Claude-Code-side.

### Why this reorders everything
If each turn stops reprocessing 26k tokens, the cell does ~15x less prompt work, which
plausibly also collapses the per-request allocation growth that produces the ~30 GB slab.
**Fix caching first, then re-measure memory.** Do not spend more time on slab forensics
until this is settled.

### THE CONCRETE FIX CANDIDATE: `--cache-ram` is defaulting to 8 GB

`llama-server --help`:

```
-cram, --cache-ram N   set the maximum cache size in MiB
                       (default: 8192, -1 = no limit, 0 = disable)
                       (env: LLAMA_ARG_CACHE_RAM)
```

Unsloth's own source confirms we never set it —
`studio/backend/core/inference/llama_cpp.py:5764`:

```python
"""--cache-ram (MiB) the last load asked for; None means the default 8192."""
```

It is `None` on every serve we launched, and `--cache-ram` appears nowhere on the child
cmdline. So the prompt cache is capped at **8 GB** while the agent's KV state for a ~26k
context on a 30B model grows past it. The cache evicts, and the next turn reprocesses from
scratch — exactly the `progress = 0 -> 1` pattern in the child log, and exactly the
"2.3 GiB prompt-cache eviction" line from the original 2026-09-02 incident.

**It is settable by env var, so no `unsloth run` passthrough is needed:**

```bash
setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 LLAMA_ARG_CACHE_RAM=32768 \
  unsloth run --model ... --max-seq-length 65536 --parallel 1 -H 0.0.0.0 -p 8888 ...
```

Start with an explicit large value (e.g. 32768 MiB) rather than `-1`. Unlimited cache on a
box that is already memory-fragile could trade one failure mode for another, and we want to
watch what the cache actually costs.

**Expected signature if this is the bug:** in the child log, `prompt processing` lines
should start at `progress` near 1.0 instead of climbing from 0; ptok per cell should fall
from ~147k to roughly the size of the final context; wall tok/s should rise sharply; and the
slab growth should shrink because far fewer buffers are allocated per cell.

Note the interaction flagged in the help text: `--cache-idle-slots ... using unified KV
(default: enabled, requires cache-ram)`. Worth reading before tuning.

**This is the single highest-value thing to try next, and it is one line and one cell.**

---

## MEASURED DRAIN RATE (2026-09-03 14:43) — no reboot required

The box recovered on its own. `uptime` confirms **no reboot happened** (up 22:14, continuous
with the morning's 18:59 reading), yet after ~3h15m idle:

| metric | 11:28 (post-run) | 14:43 (idle) |
|---|---|---|
| SUnreclaim | 30.6 GB | **0.55 GB** |
| available | 68 GB | **121 GB** |
| gtt_used | 0.0 GB | 0.2 GB |
| llama children | 0 | 0 |

So the slab drains passively in roughly **three hours of idle** — a reboot is faster but
never necessary. This also confirms it is not a permanent leak.

**Practical scheduling rule:** back-to-back agentic cells are what fail. Either fix the
cache-reuse bug (see BREAKTHROUGH) or space runs ~3h apart. `serve_pinned.sh`'s >90 GB
guard enforces this automatically — if it refuses, wait or reboot; never lower it.

**Box state at handoff: CLEAN and READY** — 121 GB available, 0.55 GB slab, zero llama
children, nothing listening on 8888. Perfect starting condition for the
`LLAMA_ARG_CACHE_RAM` test.
