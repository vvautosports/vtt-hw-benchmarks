# Performance Summary — VVC Local Model Roster

**Date:** 2026-08-27 | **Hardware:** Framework Desktop (AMD Strix Halo, Radeon 8060S iGPU, 128GB UMA, GTT unlock active ≈122 GB usable) | **Serving:** Unsloth Studio (`unsloth run`, wraps llama-server)

This is the current picture of "which local model should I point a task at." Full narrative, root-cause writeups, and every intermediate run live in [UNSLOTH-DIRECTION.md](UNSLOTH-DIRECTION.md); this doc is the fast-reference summary. Every number below is traceable to a `results/sweeps/2026-08-27-*/manifest.yaml`.

**Read the trust notes at the bottom before using these numbers to make a serving decision** — there is a live token-economy caveat affecting some of the figures.

---

## Roster leaderboard

Battery: 3 fixed tasks (multi-step reasoning with a verifiable answer, code with doctest requirements, faithful 5-bullet summarization). Request config: `thinking` profile, `reasoning_effort: low`, seed 42, max_tokens 8192, unless noted. t/s is given as reasoning / code / summarize. All rows below are from the **cleanest available run** for that model — preferring isolated (fresh-server-per-task) or `umfix` (unified-memory-fix) runs over earlier contaminated ones. The "run" column tells you which.

| Model | Size | Quant | t/s (reason/code/summ) | Quality | Run (source) |
|---|---|---|---|---|---|
| **Nemotron-3.5-Lightning-30B-A3B** (default flags) | 30B-A3B | UD-Q8_K_XL | **56.0 / 56.3 / 53.2** | 3/3 | [`2026-08-27-b10639-umfix-batch`](../../results/sweeps/2026-08-27-b10639-umfix-batch/manifest.yaml) |
| Ornith-1.5-35B-A3B | 35B-A3B | Q8_0 (non-UD) | 54.1 / 52.7 / 56.6 | 3/3 | [`2026-08-27-b10639-rebaseline-batch`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/manifest.yaml) |
| Qwen3.6-35B-A3B-MTP (isolated) | 35B-A3B | UD-Q8_K_XL | 54.8 / 57.7 / 48.9 | 3/3 | [`2026-08-27-bleed-order-test`](../../results/sweeps/2026-08-27-bleed-order-test/manifest.yaml) (isolated variant) |
| **Qwen3-Coder-30B-A3B-Instruct** | 30B-A3B | UD-Q8_K_XL | 39.9 / **74.5** / 38.2 | 3/3 | [`2026-08-27-b10639-rebaseline-batch`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/manifest.yaml) |
| Qwen3-Coder-Next (isolated) | — | — | 27.9 / 42.2 / 25.7 | 2/3 (code fails — phantom-prior-turn defect, bleed-related) | [`2026-08-27-bleed-order-test`](../../results/sweeps/2026-08-27-bleed-order-test/manifest.yaml) |
| gemma-4-26B-A4B-it | 26B-A4B MoE | UD-Q8_K_XL | 35.7 / 38.0 / 35.5 | 3/3 | [`2026-08-27-b10639-rebaseline-batch`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/manifest.yaml) |
| gpt-oss-120b | 120B | F16 (native MXFP4 MoE) | 27.3 / 32.0 / 31.2 | 3/3 | [`2026-08-27-baselines-235b-oss120b`](../../results/sweeps/2026-08-27-baselines-235b-oss120b/manifest.yaml) (isolated) |
| GLM-4.7-Flash (umfix) | — | UD-Q8_K_XL | 31.7 / 36.1 / 31.8 | 3/3 | [`2026-08-27-b10639-umfix-batch`](../../results/sweeps/2026-08-27-b10639-umfix-batch/manifest.yaml) |
| Nemotron-3-Nano-30B-A3B (umfix) | 30B-A3B | UD-Q8_K_XL | 39.5 / 45.3 / 41.3 | 2/3 (summarize near-miss: missing literal "TL;DR" label, substance fine) | [`2026-08-27-b10639-rebaseline-batch`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/manifest.yaml) |
| MiniMax-M2.5 (UD-Q3, rebaseline) | — | UD-Q3_K_XL | 21.2 / 25.1 / 21.6 | 2/3 | [`2026-08-27-b10639-rebaseline-batch`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/manifest.yaml) — **caveat:** bleed-order-test showed this "pass" is flattered by leaked context; the isolated code result fails (capped, incoherent). Q3 copy is genuinely fragile |
| **Qwen3.8-Flash-Next** (thinking/low) | 125B-A6B MoE | UD-Q4_K_XL | 15.6 / 22.3 / 17.1 | 3/3 | [`2026-08-27-b10639-umfix-batch`](../../results/sweeps/2026-08-27-b10639-umfix-batch/manifest.yaml) — first clean grades ever for this model; the earlier 204–225 t/s figures were garbage-generation artifacts of the unified-memory bug and should never be cited |
| Qwen3.8-Flash-Next (instruct, fastest config) | 125B-A6B MoE | UD-Q4_K_XL | tokens 308/1384/351, wall 107s | 3/3 | [`2026-08-27-qwen38-settings-matrix`](../../results/sweeps/2026-08-27-qwen38-settings-matrix/manifest.yaml) |
| Qwen3.8-27B | 27B | UD-Q8_K_XL | 13.5 / 13.5 / 13.2 | 3/3 | [`2026-08-27-roster-validation`](../../results/sweeps/2026-08-27-roster-validation/manifest.yaml) run2, `b10472` (not yet re-baselined on b10639) |
| Qwen3-235B-A22B-Instruct-2507 | 235B-A22B MoE | UD-Q3_K_XL | 13.6 / — / 10.4 | 2/3 — code cell invalid (tools-injection contamination, see below), reasoning + summarize clean | [`2026-08-27-baselines-235b-oss120b`](../../results/sweeps/2026-08-27-baselines-235b-oss120b/manifest.yaml) |
| gemma-4-31B-it | 31B dense | UD-Q8_K_XL | 5.6 / 5.8 / 5.4 | 3/3 | [`2026-08-27-roster-validation`](../../results/sweeps/2026-08-27-roster-validation/manifest.yaml), `b10472` — dense control, ~6.5× slower than the A4B MoE of similar footprint |
| MiniMax-M3 | — | — | cannot load | — | needs ~181 GB, box has ~122 GB usable — stays on disk for a future dual-machine RPC-pool test |

**Note on runtimes:** all `umfix`/`rebaseline`/isolated rows above are on `b10639-mix-f6f92fe` with `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` set (see [SERVING-GOTCHAS-STRIX-HALO.md](SERVING-GOTCHAS-STRIX-HALO.md)) — that is the current production config. Rows explicitly marked `b10472` predate the runtime upgrade and have not yet been re-run on the new stack; treat them as provisional until re-baselined.

---

## Which model for which job

- **Fast general workhorse:** **Nemotron-3.5-Lightning-30B-A3B, default flags** — 56 t/s across the board, 3/3 clean, current roster speed leader. (Do not add `--speculative-type off` — that was a workaround for an env-corruption bug that is now fixed; default flags are the best config.)
- **Code generation:** **Qwen3-Coder-30B-A3B-Instruct** — 74.5 t/s on the code task, the single highest per-task figure measured in this whole study, 3/3 clean. Its larger successor Qwen3-Coder-Next does not beat it (see Retired/demoted below).
- **Long-context thinker / interrupt-driven agent:** **Qwen3.8-Flash-Next**, 125B-A6B MoE, 262K ctx claim. Use the `reasoning_effort` dial: `low` as the idle/default (15.6/22.3/17.1 t/s, tight token economy), `xhigh` when you need the most thorough answer (2.9× the cost of `low` for no grade gain on this battery, but the most doctests on code). `instruct` mode is the fastest config (107s battery wall) and still passes everything — use it for non-reasoning workloads.
- **Memory-tight / fastest small MoE:** **gemma-4-26B-A4B-it** — 26GB footprint, ~36 t/s, 3/3, stable across both runtime versions and both GTT states tested. Best choice when the box is also running something else.
- **Large-model anchor / when you need the biggest thing that still runs cleanly:** **gpt-oss-120b** — 120B-class, 27–32 t/s, 3/3, tight token economy. The "software maturity" reference point: most-optimized runtime path in the study, used to judge how much headroom newer/less-optimized architectures still have.
- **Dead heat alternative to Nemotron/Coder-30B at the ~55 t/s tier:** Ornith-1.5-35B-A3B and Qwen3.6-35B-A3B-MTP — both 3/3 clean when isolated. Qwen3.6 needs a fresh server per task to stay reliable (see cross-request bleed note below); Ornith does not carry that caveat.

---

## Retired / demoted models

| Model | Reason | Evidence |
|---|---|---|
| GLM-4.7-Flash-REAP-23B-A3B | No niche: smaller on disk but slower **and** worse on every axis measured against the full GLM-4.7-Flash champion (1/3 quality). Deleted 2026-08-27. | [`2026-08-27-b10472-batch`](../../results/sweeps/2026-08-27-b10472-batch/manifest.yaml) |
| gemma-3-27b-it | No speed or quality niche — gemma-4-26B-A4B is 5.5× faster at identical (3/3) grades. **Deleted 2026-08-27** (benchmarks banked first); its `mmproj` vision niche passes to the queued Muse-Glimmer-30B, dense-control role to gemma-4-31B. | [`2026-08-27-b10472-batch`](../../results/sweeps/2026-08-27-b10472-batch/manifest.yaml) |
| Qwen3-Coder-Next | Looked like a generational inversion vs Coder-30B on first measurement (0/2), but that run was confounded by a concurrent download **and** the unified-memory corruption bug. Rehabilitated to 3/3 in isolation — but its code task still fails under the cross-request state-bleed defect at 2/3, and it never beats Coder-30B's throughput. No promotion pending a bleed fix. | [`2026-08-27-b10472-batch`](../../results/sweeps/2026-08-27-b10472-batch/manifest.yaml), [`2026-08-27-bleed-order-test`](../../results/sweeps/2026-08-27-bleed-order-test/manifest.yaml) |
| Nemotron-3-Nano-30B-A3B | Niche eroding, not yet formally retired (Kal's call pending). Its selling point was "runs correctly on default flags" while 3.5-Lightning needed a workaround — that workaround is now gone, so 3.5-Lightning runs default flags at 56 t/s, 3/3, strictly better. | [`2026-08-27-b10639-rebaseline-batch`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/manifest.yaml) |
| MiniMax-M2.5 (UD-Q3_K_XL copy) | Indicted as fragile independent of the runtime bugs: first-request code runs to the 8192 cap with incoherent output, and its earlier "pass" was flattered by cross-request context bleed. Only UD-Q3 model in an otherwise Q8 field — indicts the quant copy, not necessarily the family. **Copy deleted 2026-08-27** (successor: MiniMax-M3 on disk, or a Q8 re-pull if the comparison is revived). | [`2026-08-27-bleed-order-test`](../../results/sweeps/2026-08-27-bleed-order-test/manifest.yaml) |
| Qwen3.8-Flash-Next @ 204–225 t/s claim | Never a real number — those figures were the unified-memory corruption generating garbage tokens at high speed while never terminating (0/3, all capped). Superseded by the umfix batch (15.6–22.3 t/s, 3/3). Cite only the umfix figures. | [`2026-08-27-b10639-batch`](../../results/sweeps/2026-08-27-b10639-batch/manifest.yaml) (garbage run) vs [`2026-08-27-b10639-umfix-batch`](../../results/sweeps/2026-08-27-b10639-umfix-batch/manifest.yaml) (real run) |

---

## Trust notes

- **Grades are deterministic content-channel checks** on a fixed 3-task battery (verifiable-answer reasoning, doctest-compliant code, structure-checked 5-bullet summary) — a programmatic grader, not a judge model. A "3/3" means the battery's specific checks passed, not a general quality claim. Grading reads the `content` channel a real API consumer would see, not a whole-transcript grep — this matters because some models leak answers into `reasoning_content` or fail on formatting alone (e.g. Nemotron-3-Nano's missing "TL;DR" label).
- **Tools-injection caveat (open, un-resolved as of 2026-08-27):** `unsloth run` enables server-side tools (web search, code execution) by default. A full-corpus scan found 48 records with prompt_tokens in the 2,000–16,000 range where the battery prompt is ~100 tokens — evidence of injected tool-schema content or spontaneous tool invocation (confirmed on the Qwen3-235B code cell, which triggered a server-side code-execution loop and returned a non-answer). **Any t/s or token-economy comparison made before the `--disable-tools` re-baseline lands should be treated with caution** — content-channel pass/fail grades are unaffected (they measure what the consumer actually received), but wall-clock and token-count comparisons may be measuring tool-loop overhead rather than raw generation. This affects, at minimum, the version-sweep code-cell token-bloat finding. Re-baseline under `--disable-tools` is queued but not yet run.
- **Cross-request state bleed on `b10639`** (confirmed 2026-08-27, see [SERVING-GOTCHAS-STRIX-HALO.md](SERVING-GOTCHAS-STRIX-HALO.md)) means any multi-request server session can leak context between unrelated requests. All figures above from `rebaseline`/`umfix`/non-isolated batches carry this risk for models known to be sensitive to it (Qwen3.6-MTP, Qwen3-Coder-Next, MiniMax-M2.5); rows explicitly marked "isolated" are immune and should be preferred when available.
- **Tool-calling is untested.** Everything in this document is prose/code generation via plain chat completion. Whether these models can reliably drive tool-call plumbing (function selection, multi-turn chains, distractor rejection) is the next benchmarking track and has no data yet — do not infer tool-calling reliability from these grades.
- **Runtime build is an output-changing axis, not just a speed axis** — a same-model, same-quant, same-prompt comparison across `b10472` → `b10639` changed both token economy and instruction-following before the unified-memory fix was found. Always check which runtime build a number came from (recorded in each manifest) before comparing across rows from different dates.
