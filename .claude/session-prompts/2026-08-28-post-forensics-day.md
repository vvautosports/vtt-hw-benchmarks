# Continuation — 2026-08-28 (after the forensics day)

**Worktree:** `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction`
**Branch:** `feature/unsloth-direction` → PR #5 (Forgejo, base develop) — 12 commits from 2026-08-27, all pushed.
**Model tier note (Kal):** start this session on Opus; escalate only if needed.

## ▶ FIRST MOVE

Per the session-startup doctrine, spawn ONE cheap-tier Explore subagent (digest-only) to read:
1. `docs/reference/UNSLOTH-DIRECTION.md` — sections from "Root cause: unified-memory env corruption" onward (the 2026-08-27 arc: three serving-axis discoveries, re-validation batches, scoping sections, cross-reference table).
2. `docs/reference/PERFORMANCE-SUMMARY.md` + `docs/reference/SERVING-GOTCHAS-STRIX-HALO.md` (human-facing state).
3. `results/sweeps/2026-08-27-baselines-235b-oss120b/manifest.yaml` and `results/sweeps/2026-08-27-qwen38-quant-ladder/manifest.yaml` (caveats sections carry the open threads).
4. `git -C <worktree> log --oneline -12` + `git status`.
5. On the Framework (ssh framework): `cat ~/batch-toolsoff-ab-2026-08-27/DONE 2>/dev/null; tail -5 ~/batch-toolsoff-ab.log` — the overnight 235B-notools re-run + GLM tools-on/off A/B.

## State snapshot (2026-08-27 night)

- **Three serving axes found + neutralized:** (1) `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` corrupts inference on Strix Halo/b10639 — opt-out permanent on Framework (`~/.bashrc.d/unsloth.sh` + environment.d), staged on G1a via `setx` (NOT yet serve-verified on Windows); (2) cross-request state bleed on b10639 — **fresh server per graded task** is protocol (`isolated_battery.py`); (3) `unsloth run` server-side tools default ON — **`--disable-tools`** now mandatory for battery serves; corpus-wide prompt-inflation caveat on token-economy comparisons.
- **Roster:** Nemotron-3.5 default flags = speed leader (56 t/s, 3/3); Coder-30B = code king (74.5); Qwen3.8-Flash-Next fully working (3/3, Q4_K_XL stays serving quant after 9/9 ladder — economy inversion: smaller quants faster per-token but verbose, Q4 wins wall-clock); gpt-oss-120b 3/3 @ 27–32 t/s; Coder-Next + MiniMax rehabilitated (M2.5 Q3 copy deleted as fragile).
- **Disk:** deleted M2.5/Nano/REAP-23B/reap-218b/gemma-3-27b (~283 GB); added Qwen3.8 IQ4_XS + Q2_K_XL. ~62 GB free at last check — verify with `df -h /mnt/ai-models`.
- **Wiki:** vvt-knowledge PR #53 MERGED (serving rules + roster pages live on develop). **8→7 open wiki PRs remain (Aug 15–27) — Kal triage needed; PR #52 now CONFLICTS with #53 (both touched strix gotchas) and needs a rebase.** The SSO/Quartz wiki site has NO CD workflow in the repo — deploy mechanism is external (documented in unmerged PR #21); staleness of the SSO link is (a) unmerged PR backlog + (b) possibly a Quartz build pulling main (5 behind develop).
- **Artifact:** shareable report published — https://claude.ai/code/artifact/342ffca1-6388-463c-b823-06940f73ed2d (Kal can share to team). Rewritten explainer-first per Kal's feedback (no campy headlines; battery mechanics + pass criteria lead; per-task columns, no coded triples); repo-tracked copy at `docs/reports/2026-08-27-bench-report.html`. **Style rule for future reports: explain the test before the scores; no single-letter metric coding; plain headlines.**

## Task queue (priority order)

1. ~~Grade the A/B batch~~ **DONE same night** (`results/sweeps/2026-08-27-toolsoff-rerun-ab/`, commit 9fe8a54): injection = ~1200 tok/request schema + tool loops; 235B code PASSES clean with `--disable-tools` (its summarize flipped 5→4 bullets — one-seed prompt-composition sensitivity); GLM 3/3 both ways, tools-off t/s closes part of the "-7% vs b10472" gap. Skip item 5 of the FIRST MOVE digest.
2. **Build Track 1 tool-calling battery (Tier 1)** — TOP PRIORITY per Kal. Scoping + Qwen-family intel already in UNSLOTH-DIRECTION.md ("Scoping: multi-dimensional test tracks" + the Qwen intel bullet): deterministic graders (schema-validate, expected-call match, distractor, refusal), healing on/off axis, "survives 15+ chained calls" regression (llama.cpp #19513 shape), `--disable-tools` OFF for these runs obviously — tools are the subject. Extend `grade_sweep.py` with a `toolcall` family.
3. **Downloads (Kal-approved):** DeepSeek-V4-Flash-0731 **UD-IQ3_XXS** (~104 GB — fits ceiling; Q4 does NOT) + Muse-Glimmer-30B (**Q4_K_XL 16 GB + mmproj Q8 2 GB** for fit; Q8 needs another ~15 GB free) from unsloth HF repos → `/mnt/ai-models/unsloth/`. Check `df` first. Then DeepSeek day-one battery (isolated_battery.py) + Muse vision smoke.
4. **Champion re-baseline under `--disable-tools`** — clears the last economy caveat; use isolated_battery, top-6 models.
5. **PR #5 review/merge** with Kal (12 commits; then /release develop→main if he wants v0.x cut).
6. Backlog: wiki PR triage w/ Kal (esp. rebase #52, review #21 for the Quartz deploy story), Ornith-1.5-9B for MI50s, context/KV-quant ladder, b10472 order-test, HF forum post (draft in `results/sweeps/2026-08-27-b10639-umfix-batch/upstream-issue-draft.md` — GitHub issue declined by Kal, forum maybe).

## Standing rules (do not relearn these)

- Fresh server per graded task (bleed). `--disable-tools` for text batteries. `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` on every Strix Halo launch (permanent on Framework; presence-tested var, `=0` won't work). `pkill -f llama-server` self-kill gotcha over ssh — use `[l]` bracket patterns. llama-server ignores SIGTERM. prompt_tokens >2000 on a battery cell = tool-injection suspect. Never cite the 204–225 t/s Qwen3.8 figures.
- Per-family configs are policy (flags/env in spec registry, recorded per record). Commits: conventional, pause for Kal review, push updates PR #5. gh does not work on Forgejo — REST API with `git credential fill` token.
