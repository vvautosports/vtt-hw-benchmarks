# Session Continuation Prompt
**Generated:** 2026-11-01
**Ending phase:** Research complete: Strix Halo next intake queued as issues #30-#34
**Starting phase:** Framework testing, driven by Gemini, working from #30, #31 and #34

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (a cheap model tier is fine) to run the Section-scoped reads below and return a digest of at most 2K words. ONLY that digest enters main context. Switch the main thread to a higher model tier only when implementation starts. Every path in this prompt is ABSOLUTE. (Cross-harness doctrine: vvt-omnigent ADR 0005.)

We're working on the vtt-hw-benchmarks repo at C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks.
Branch: develop. The feature branch `feature/model-research-2026-11` has an open PR for the MODELS-TO-TEST update.

## Feature completed

Research on what to benchmark next, published as a MODELS-TO-TEST section plus five Forgejo issues.

| Issue | Purpose |
|---|---|
| #30 | Audit which build 10687 rows really ran speculation |
| #31 | Runtime bump to `b11985-mix-c116c32`, stock Vulkan `b12032` alongside, same-method re-baseline |
| #32 | G1a Coder-30B recheck for Windows power policy |
| #33 | Lane B first pass: EvalScope BFCL, Aider polyglot, reasoning set |
| #34 | First wave: Bolt, Ornith-122B, Flint, Kolibri-1, Nanbeige4.3-33B |

Kal's decisions: Studio mix plus stock Vulkan, top 5 first wave, Lane B only on Lane A winners plus Coder-30B.

## State found at the end of this session (verified 2026-11-01)

- **Framework runtime:** `b10687-mix-67dfc8b`, Fedora 43, kernel 7.2.13. `amd_iommu=off` and GTT settings are already on the boot line. tuned profile is `balanced`.
- **Disk:** `/mnt/ai-models` has 239 GB free. MiniMax-M3 and part of GLM-4.7-Flash were removed during this session, not by this session. `models-inventory.yaml` still lists MiniMax-M3 (task in #34).
- **Gemini's chain:** `~/chain_2026_11_01_mtp_sidecars.sh` on the Framework assumes no-MTP baselines exist on b10687. #30 questions that assumption, so read its deltas with care.
- **Main checkout:** carries uncommitted #28 work not made by this session: `docs/reference/PERFORMANCE-SUMMARY.md` and `results/sweeps/2026-09-07-gemma-ladder/`. Leave it to its owner.
- **G1a runtime:** `b11160-mix-a6922cc`.

## Corrections to the research report

The report at C:\Users\kalman9\.claude\plans\partitioned-hatching-snowflake-agent-a8c0d5963202fa196.md is useful for sources, but these claims are wrong or overstated:

- It calls the Framework vanilla b10830. It is `b10687-mix`.
- Its successor column fails the retention policy's evidence gate. gpt-oss-120b is exempt, Coder-30B has a recorded niche, and Qwen3-Next-80B is no longer on disk.
- It treats 18 to 40 t/s as a Framework gap. That is a G1a Windows smoke result.
- It treats 96 vs 69 t/s as a backend gap. The methods differ (`llama-bench` tg128 vs our task battery), so #31 tests it.
- Its disk figures (about 95% full) are out of date.

## Deferred / follow-up work

- #28 harvest and #23 close (the #28 work is uncommitted in the main checkout)
- Full G1a MTP pair, can share a docked session with #32
- #27 remainder: Playwright captures, LoggedModel linkage, system metrics, figures, traces
- `run_manifest.py` gaps: `rung`, `hardware`, `repo_git_sha` are empty, `node: fedora`
- Worktree cleanup: `charming-pare-45cbae` is a leftover. `track2a-stream-b` has uncommitted work, so don't remove it blind
- Remote branch `forgejo/feature/mlflow-metadata-27` still exists after PR #29 merged
- #22 could take a comment that upstream PRs #27773 and #29928 partly lift its blocker

## What to do next

1. Review and merge the MODELS-TO-TEST PR.
2. Finish Gemini's sidecar chain, then do #30.
3. Do #31, which gates #34.
4. Run #34 one model at a time, then send winners to #33.

## Section-scoped reads

- C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\docs\reference\MODELS-TO-TEST.md § "Next Intake Candidates - 2026-11": candidates with sizes and links
- C:\Users\kalman9\.claude\plans\partitioned-hatching-snowflake-agent-a8c0d5963202fa196.md: sources for runtime, Halogen and harness findings, read with the corrections above
- Forgejo issues #30, #31 and #34 on vvc/vtt-hw-benchmarks: tasks and success criteria

## Blockers

None. #34 is gated on #31 by order of work.

## Pending system-evolution items

None.
