# Session Continuation Prompt
**Generated:** 2026-08-27
**Ending phase:** Roster harvest + phase-2 batch + first llama.cpp-version sweep (COMPLETE)
**Starting phase:** b10639 rollback decision + version-sweep suite build-out (#8 workstream C)

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread

Spawn ONE Explore subagent (cheap tier — sonnet/haiku, NEVER fable) to run the Startup
block below and the Section-scoped reads, and return a ≤2K-word digest. ONLY that digest
enters main context — never read the files or run the startup block in the main thread.
Switch the main thread to a higher tier only when implementation starts. Every path below
is ABSOLUTE. (Doctrine: vvt-omnigent ADR 0005.)

We're working on the **vtt-hw-benchmarks** repo, worktree at
`C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction`.
Branch: `feature/unsloth-direction`.
Rule: hand startup to a subagent; execute the startup block; honor read scoping literally;
apply the documented environment workarounds on the FIRST attempt.

## ⚠ THE DECISION WAITING FOR KAL

**b10639 is a net regression. Rollback has not been done and is Kal's call.**
Nothing that currently works depends on b10639. Recommendation on the table: treat
`b10472-mix-4b653db` as the production build and `b10639-mix-f6f92fe` as
qwen4exp-experimental only. Ask Kal before touching the runtime. Evidence is in
`results/sweeps/2026-08-27-version-sweep/manifest.yaml` and the b10639-batch manifest.
No rollback mechanism has been investigated yet — `unsloth studio update` has no obvious
pin/downgrade flag; that research is unstarted.

## Startup block (the subagent runs this; ABSOLUTE paths; batch aggressively)

```bash
# 1. Worktree + forge state (origin=GitHub is STALE, forgejo is primary — never push origin)
git -C C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction status --short && \
git -C C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction log --oneline -5 && \
git -C C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction log --oneline forgejo/feature/unsloth-direction..HEAD

# 2. Box state: build, serve health, disk. (Bracket trick is MANDATORY over tailscale ssh —
#    it embeds the command string in its own argv, so `pgrep -f "studio update"` matches
#    ITSELF. Use `[s]tudio update`. This bit twice on 2026-08-27.)
ssh -n framework 'date; ~/.unsloth/llama.cpp/llama-server --version | head -1; unsloth --version; \
  ps -eo pid,etime,args | grep "[l]lama-server" | cut -c1-120; \
  df -h /mnt/ai-models ~ | tail -2; \
  KEY=$(grep -oE "sk-unsloth-[A-Za-z0-9_-]+" ~/unsloth-serve.log | tail -1); \
  curl -s -m 10 -H "Authorization: Bearer $KEY" http://localhost:8888/v1/models | head -c 200'

# 3. Grader must reproduce every committed run byte-for-byte (0 changes each = green).
cd C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction && \
py scripts/utils/grade_sweep.py results/sweeps/2026-08-26-glm47-flash-param-sweep phase1 --check && \
py scripts/utils/grade_sweep.py results/sweeps/2026-08-27-roster-validation results --layout model --check && \
py scripts/utils/grade_sweep.py results/sweeps/2026-08-27-b10472-batch results --layout cfg --check && \
py scripts/utils/grade_sweep.py results/sweeps/2026-08-27-b10639-batch results --layout cfg --check
# expect: "0 record(s) would change" x4
```

## Status

### Completed this session
- **Harvested + graded the 2026-08-26 overnight run** → `results/sweeps/2026-08-27-roster-validation/`
  (26 records; 12 graded, 10 trampled, 2 errors).
- **Rescued `grade_sweep.py` into the repo** at `scripts/utils/grade_sweep.py` (it was in a dead
  session's scratchpad). Generalised `--layout` to any record field; added `--check` for
  regression-proofing. Verified it reproduces the committed 2026-08-26 grades exactly.
- **Root-caused Nemotron-3.5's HTTP 500s** → `results/sweeps/2026-08-27-nemotron-retest/`.
  MTP is the cause; the `-np > 1` theory is DISPROVEN. Model-specific, not build-wide.
- **Downloaded + benchmarked 4 phase-2 candidates** (176.6 GiB, 0 failures) and the whole
  generational control arm → `results/sweeps/2026-08-27-b10472-batch/` (11 configs).
- **Built the version-sweep suite's first two datapoints** →
  `results/sweeps/2026-08-27-version-sweep/` (b10472 control captured BEFORE upgrading).
- **Upgraded to b10639** and benchmarked it → `results/sweeps/2026-08-27-b10639-batch/`.
- Updated `docs/reference/UNSLOTH-DIRECTION.md` and `models-inventory.yaml`
  (added the `all_models` section `mode: "all"` had been advertising with nothing behind it).
- Posted results + ticked 5 of 6 checkboxes on GitHub issue #10.

### Leaderboard (b10472, thinking/low, t/s reasoning/code/summarize)
| model | t/s | quality |
|---|---|---|
| Qwen3.6-35B-A3B-MTP | **57.6 / 58.2 / 50.0** | 3/3 |
| Ornith-1.5-35B-A3B | 54.6 / 58.5 / 52.1 | 3/3 |
| Nemotron-3.5-Lightning (`--speculative-type off`) | 43.2 / 46.8 / 46.9 | 3/3 |
| Nemotron-3-Nano-30B | 39.7 / 41.7 / 40.5 | 3/3 |
| Qwen3-Coder-30B-A3B-Instruct | 39.5 / **73.3** / 18.9 | 2/3 |
| gemma-4-26B-A4B-it | 36.6 / 36.8 / 35.0 | 3/3 |
| GLM-4.7-Flash (champion) | 32.3 / 38.6 / 33.3 | 3/3 |

### Remaining in this phase
1. **Kal's b10639 rollback decision** (see above). Blocking everything runtime-related.
2. Re-test **Qwen3-Coder-Next on an idle box** — its HTTP 500 landed while a 104 GiB
   download was running, so memory/IO pressure is not excluded. Until then its
   "generational inversion" verdict carries a confound.
3. **Spec-type sweep on b10639** — all three GLM tasks flattened to 31.3–31.7 t/s, which
   looks like speculation stopped paying. Unconfirmed.
4. GLM-5.3-Flash **quant watch** — re-check `unsloth/GLM-5.3-Flash-GGUF` for a UD-Q8 or a
   fitting UD-Q4. As of 2026-08-27 the top tier was UD-Q4_K_XL at 186 GiB (ceiling is
   ~122 GB usable). Only IQ1–IQ3_XXS fit.
5. Retention decisions — all evidence-gated and NOTHING has been deleted (see below).

### Deferred / backlogged
- DeepSeek-V4-Flash-0731 — only fits at IQ1–IQ3_XXS. `dspark` needs b10228+ so the runtime
  is fine; size is the blocker.
- Dual-machine RPC pool (MiniMax-M3 182G + Kimi-K3). No external draft-model workflow
  exists in the harness yet — would be built from scratch.
- MLflow Phase 2 (workstream D) — manifests are keyed to map 1:1 onto MLflow params/tags.

## Key decisions made this session
- **Retention is evidence-gated** (Kal, 2026-08-27): a legacy model is retired only once
  there is empirical evidence it holds no niche its successor cannot cover. The legacy set
  is a CONTROL ARM, not a deletion queue. **Nothing was deleted this session.**
- Verdicts from that control arm: **Nemotron-3-Nano KEEP** (only 9–16% slower, and it runs
  correctly on DEFAULT flags where 3.5 needs an override). **Qwen3-Coder-30B KEEP, strong
  niche** (73.3 t/s on code — highest in the study — and it beats its successor outright).
  **MiniMax-M2.5 KEEP, unresolved** (its copy is UD-Q3 in a Q8 field, so "never terminates"
  indicts the copy; its M3 comparison is blocked while M3 can't load on one node).
  **GLM-4.7-Flash-REAP-23B — no niche found**, the only real retirement candidate.
  **gemma-3-27b — no speed/quality niche**, but ships an `mmproj` vision projector the
  gemma-4 GGUFs lack, so a vision niche is untested rather than disproven.
- **Runtime build is an OUTPUT-CHANGING axis** — must be quality-graded, never ranked on
  speed alone. Same for **native-MTP speculation** (the old "output-invariant" claim came
  from GLM, which has no MTP head; Qwen3.6 produced different outputs with MTP on vs off).
- Nemotron-3.5 must always be launched with `--speculative-type off`.
- Qwen3.8-27B: keep studio's default; the MTP sidecar works but doesn't beat it.

## Corrections to earlier beliefs (do NOT re-derive these)
- **MiniMax-M3 did not fail on architecture.** Backend said "needs about 181 GB but only
  about 122 GB is available". The driver's "arch unsupported or crash" is a generic
  catch-all. **~122 GB is the real usable ceiling**, not the nominal 128 GiB GTT.
- **`gtt_used_mib` is a broken metric** — reads 411–418 MiB for every model regardless of
  26–36 GB of weights. Never cite it; `grep gttsize /proc/cmdline` is authoritative.
- **`~/.cache/huggingface` is NOT redundant blobs.** 84 of its 85 GB is the sole copy of
  Qwen3.8-Flash-Next at UD-Q3_K_XL; everything else is 4 KB of metadata. Purging it deletes
  a model. It becomes a clean deletion only once the new Q4 copy is validated.
- **The `/mnt/ai-models` vendor dirs are NOT duplicates of unsloth copies.** `openai/` (61G)
  is gpt-oss-120b, `THUDM/` (92G) is glm-4.7-reap-218b, `Qwen/` (98G) is qwen3-235b-a22b —
  and that last one is an ACTIVE entry in `models-inventory.yaml`. An earlier session
  wrongly proposed these as safe purges. They are not.

## What to do next
1. Ask Kal the **b10639 rollback** question. If yes, research how to pin/downgrade the
   llama.cpp release under `unsloth studio update` before touching anything.
2. Re-test Qwen3-Coder-Next on an idle box (item 2 above) — cheapest way to remove the one
   real confound in this session's headline generational finding.
3. If staying on b10639: run a spec-type sweep to confirm/deny the speculation-flattening
   hypothesis.
4. GLM-5.3-Flash quant re-check (`hf_fs ls hf://models/unsloth/GLM-5.3-Flash-GGUF`).
5. Then #8 workstream C (version-sweep suite proper) or MLflow Phase 2.

## Section-scoped reads
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/results/sweeps/2026-08-27-version-sweep/manifest.yaml` — §`findings` — the whole b10639 regression case. READ FULL, it is short.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/results/sweeps/2026-08-27-b10639-batch/manifest.yaml` — §`caveats.b10639_instruction_following` — the two-model quality regression, stated precisely.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/results/sweeps/2026-08-27-b10472-batch/manifest.yaml` — §`entries` — per-model verdicts incl. the generational control arm.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/docs/reference/UNSLOTH-DIRECTION.md` — §"Phase-2 candidates + generational control arm" and §"llama.cpp-version sweep" ONLY (~line 178 to end). Do not read the whole file.
- `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/scripts/utils/grade_sweep.py` — module docstring only (first 45 lines) — layouts + trampling contract.

## Environment workarounds (apply on FIRST attempt)
- **tailscale ssh embeds the command string in its own argv** → `pgrep -f`/`pkill -f` match
  THEMSELVES. Always bracket: `[l]lama-server`, `[s]tudio update`. This produced a false
  "still running" and a false "3 orphan processes" on 2026-08-27.
- This llama-server build **ignores SIGTERM** — `pkill -9` required.
- Detached launches over ssh: `ssh -n framework 'setsid nohup <cmd> > LOG 2>&1 < /dev/null & disown'`.
  A trailing `; exit 0` in the same string silently prevented the process from starting once.
- **Git Bash `/tmp` is invisible to native Windows `py`** — scp to the scratchpad, not `/tmp`.
- Heredocs: bash heredocs choke on YAML/prose with quotes — use the Write tool for those.
- `py` not `python3` on Windows; no local `pyyaml` — validate YAML by piping to `framework`.
- Markdown lint: the doc violates MD013 throughout by house style; CI runs markdownlint with
  `continue-on-error: true`. Match surrounding style, don't reflow.
- **Forgejo is primary** (`git.vvautosports.com/vvc/vtt-hw-benchmarks`, PR #5 open, base
  `develop`). `origin` = GitHub is a stale recreated branch — never push it. Issues #8/#10/#11
  still live on GitHub and `gh` works for them.

## Harness scripts (on Framework `~`, NOT yet committed — issue #8 harness-backend item)
`roster_batch.py` (spec-driven batch, per-config output dirs — this is the trampling fix),
`battery.py` (3-task battery vs whatever is serving), `nemotron_retest.py`, `fetch_roster.sh`,
plus the pre-existing `sweep_phase1.py` / `sweep_phase2.py` / `overnight_run.py`.
Spec files: `batch_b10472.json`, `batch_b10472_mtp.json`, `batch_b10639.json`.
Committing these is an open #8 task.

## Blockers
- **b10639 rollback decision** — Kal's call, blocks all runtime work.
- Qwen3.8-Flash-Next never terminates on b10639 (all tasks cap out). Blocked on
  ggml-org/llama.cpp#27742 merging upstream.
- MiniMax-M3 cannot load on one node (needs 181 GB) — blocked on the RPC pool.
- Disk: 47G free on `/mnt/ai-models`. No purge approved; the menu is parked with Kal.

## Pending system-evolution items
None.

## Discord Thread
`1542400459300536440` — reply to this thread, do not create a new one.
