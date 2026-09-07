# 2026-09-06 — Standouts, learnings, coverage gaps, next test set

Written under a 9-minute session-reset budget. Two subagent digests (repo sweep + HF/web landscape scan) synthesized here. Uncommitted — review before commit.

## ▶ FIRST MOVE (next session)
Spawn ONE Explore subagent to read this file + `docs/reference/MODELS-TO-TEST.md` + the latest `results/` and `.claude/session-prompts/2026-09-03-*` files; digest only into main thread. Start in plan mode.

Still-pending infra items carried from `vvt-infrastructure/.claude/session-prompts/2026-09-03-evidence-lakehouse-leg-c-complete.md` (NOT done this session): merge infra PR #216 then #218 via Forgejo API (force_merge), post acceptance evidence + close infra #201, then MLflow/UC bumps → orchestration spike → Spark landing plan.

## 0. Ground truth (facts)
- **MLflow is live at `http://192.168.7.241:5000`** — docs previously said `.30`; that address is stale, use `.241`.
- **studio-bundled llama-server build 10687 lacks `--spec-type draft-mtp`** (G1a's build 10639 has it) — so MTP cells go to the G1a first (#14); today's Qwen3.6-27B-MTP row ran with the MTP head present in the GGUF but unused.
- **Airflow 2.10.5 spike deployed on CT 241 :8081** (`profile airflow`) with DAGs `hwbench_intake_row` (paused) and `framework_ssh_smoke`.
- **Registry has 15 models / 10 aliases** (`docs/reference/model-slots.yaml`).
- **Today's 4 intake rows (2026-09-06, intake #20, build 10687, Framework, seed 42, effort low):**

  | Model | Size | Quant | t/s (reason/code/summ) | Text quality | Tool (tier2, both rungs) |
  |---|---|---|---|---|---|
  | Qwen3.8-27B | 31.5G | UD-Q8_K_XL | 17.0 / 16.2 / 15.2 | 3/3 | 7/7 |
  | gemma-4-31B-it-qat | 17.3G | UD-Q4_K_XL | 27.3 / 26.8 / 22.8 | 3/3 | 7/7 |
  | Qwen3.6-27B-MTP (MTP unused) | 35.8G | UD-Q8_K_XL | 14.2 / 13.8 / 13.5 | 3/3 | 7/7 |
  | gemma-4-31B-it (re-run) | 35.0G | UD-Q8_K_XL | 5.9 / 6.0 / 5.8 | 3/3 | 7/7 |

- **Issues #20-#23:** [#20](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/20) (this intake batch), [#21](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/21) (Qwen3.8-Flash-Next quant purge), [#22](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/22) (GLM-5.3-Flash deferred), [#23](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/23) (Qwen3-Coder-30B-A3B quant ladder, planned).

## 1. Models standing out (as recorded in repo)
| Category | Standout | Evidence |
|---|---|---|
| Tool-calling (Tier 2, 7/7) | Qwen3-Coder-30B-A3B, Qwen3-Coder-Next, Qwen3.8-Flash-Next, GLM-4.7-Flash | all 7/7; Nemotron-3.5 6/7 (parallel-call serialization = model trait); gpt-oss-120b 5/7 + only model failing 60-deep chain |
| Coding quality | Qwen3-Coder-30B-A3B-Instruct | 3/3; true clean speed ~43.6 t/s (74.5 figure was tool-injection artifact) |
| Reasoning / general | Ornith-1.5-35B-A3B ≈ Nemotron-3.5-Lightning ≈ Qwen3.6-35B-A3B-MTP | ~61–64 scores, near-tied; Nemotron drops TL;DR label (2/3) |
| Long-context / thinker | Qwen3.8-Flash-Next (125B-A6B, 262K ctx) | reasoning_effort low for economy, xhigh for depth; DeepSeek-V4-Flash needle 3/3 to ~35k |
| Memory-tight / co-resident | gemma-4-26B-A4B-it | ~36 t/s, 26GB, 3/3, stable |
| Creative | **no separate category scores exist** | gap |

## 2. What we have learned so far
- **Size:** 30–35B-A3B MoE is the sweet spot. Dense 31B (gemma-4-31B UD-Q8) is ~6.5× slower at similar footprint. 120B/235B-class don't beat the A3B class on quality-per-t/s. 125B-A6B (Flash-Next) is the "thinker tier", not the daily driver.
- **Quant:** UD-Q8_K_XL is the clean standard row. Q3-class is fragile (MiniMax-M2.5 UD-Q3 retired, incoherent); UD-IQ3_XXS only when forced (DeepSeek-V4-Flash). **We have no same-model quant ladder (Q4_K_M / UD-Q4_K_XL / Q6_K / Q8) — so we cannot answer "optimal quant" and cannot compare to community numbers, which are almost all Q4_K_M/Q8.**
- **Runtime build is a first-class variable:** b10639 produced fake 200+ t/s numbers (unified-memory corruption). Pin the build in every result row.
- **Multi-model:** co-residency sweep JSONs exist (`2026-08-28-coresidency*.json`) but the dual-agent GLM+Coder thinker/executor config is in memory only — **not written up in the repo.** Write it up before extending.
- **Windows vs Linux:** one data point (Nemotron-3.5: Framework ~63 t/s vs G1a ~36 t/s). G1a coverage = 1 model.

## 3. Coverage gaps vs the community (HF trending + r/LocalLLaMA + Strix Halo YouTube/blog canon, 2026-09-06 scan)
Community Strix Halo content is dominated by: tok/s tables at Q4_K_M vs Q8, Vulkan-vs-ROCm-vs-HIP backend shootouts, MTP speculative-decoding speedups (~1.8× reported), prompt-processing vs generation split. Task benchmarks cited: SWE-bench Verified, aider polyglot, GPQA-diamond (last two unverified as current — treat as assumption).

Missing from our roster (unsloth GGUFs exist for most, pushed in last 2–5 days):
- GLM-5.3-Flash (new GLM gen; GLM-4.7-Flash was 7/7 → likely successor per retention policy)
- Qwen3.8-27B dense (HF #2 trending) and Qwen3.6-27B-MTP (reddit agentic-coding favorite)
- Gemma-4-31B-it **QAT int4** (community config; we only ran UD-Q8 dense = slow row)
- Kimi K2/K3, Mistral, Llama 4 — zero coverage of three reference families
- Granite-4.1-8B function-calling, Qwen3.5-0.8B, Spark-X2.5-4B — small executor candidates for dual-agent
- DeepSeek-V4-Flash-Vision-Exp — vision lane (behind Muse-Glimmer per-family config work)
Unverified names from the scan (do not chase without checking): "Qwen3.8 Max", "GPT-6 Astra", MiniMax-H3 params, GLM-5.3 full size.

Missing test axes: quant ladder, backend A/B, pp-vs-tg split (confirm we record pp t/s), MTP on/off, creative category, concurrency ladder (evalscope perf), EvalScope official-suite comparability (#15 — package still not installed).

## 4. Next test set — ordered by expected impact on our goals, cheapest-first within tier
Efficiency rule: every new model passes the **3-cell gate** (load + Tier-2 7-call tool test + 3 reasoning cells, UD-Q8 or QAT-native) before any deeper track. Two-lane rule stands: community lane never mixes into internal rankings.

1. **Unblock Track 2A** — one cell: `LLAMA_ARG_CACHE_RAM` env fix for the prefix-cache bug, then `--parallel 2`. Merge PR #17 first. (#10, #12). Agent-harness battery is the closest test to the real goal. **Untouched today (2026-09-06).**
2. **Quant ladder, one model** — Qwen3-Coder-30B-A3B at Q4_K_M / UD-Q4_K_XL / Q6_K / UD-Q8_K_XL: tool 7-call + 3 coding cells + tg t/s + pp t/s. Four cells; answers "optimal quant" and makes us community-comparable in one sweep.
3. **Runtime bump ≥ b10715 → MTP re-baseline (#14)** on Qwen3.6-35B-A3B-MTP and Qwen3.6-27B-MTP, MTP on vs off. Biggest single speed lever on the table.
4. **Backend + OS A/B on G1a** — Vulkan vs ROCm, same model/quant/build; then G1a vs Framework with 3 models (Nemotron-3.5, Qwen3-Coder-30B, gemma-4-26B). Turns the one-point Windows-vs-Linux lead into an axis.
5. **New-family intake via 3-cell gate** — GLM-5.3-Flash, Qwen3.8-27B, Gemma-4-31B QAT-int4, one Kimi and one Mistral at a fitting quant. Keep/retire per model-retention policy (designated successor rule). **Done for 3 of 5 families today (2026-09-06, intake #20):** Qwen3.8-27B and Gemma-4-31B QAT-int4 landed as planned, plus a bonus Qwen3.6-27B-MTP row and a gemma-4-31B-it (non-QAT) re-run on build 10687 — see §0 table. Still open: GLM-5.3-Flash (deferred, #22 — 320B-A18B IQ1-only fit, llama.cpp #27754 unmerged), one Kimi, one Mistral. **Raw-rung lesson:** tool specs must carry the raw flags (`--disable-tools --disable-tool-call-healing --disable-tool-call-nudging`) to be leaderboard-comparable — today's batch ran both the healing-on and raw rungs per model specifically to stay comparable with the existing Tier-2 leaderboard.
6. **Dual-agent write-up + executor trial** — document the GLM+Coder config in `docs/`; then test Granite-4.1-8B-FC or Qwen3.5-0.8B as co-resident executor under Qwen3.8-Flash-Next thinker: memory headroom, tool 7/7, end-to-end latency.
7. **EvalScope pilot (#15)** — install on box, run aider-polyglot subset + GPQA-diamond subset + `evalscope perf` concurrency ladder. Community lane only.
8. **Creative category** — add 3 graded creative cells to the standard battery so the top-3 reasoning tie can be broken.

Deferred: Track 2B server matrix (vLLM/Ollama/LM Studio) until 1–3 land; vision lane until Muse-Glimmer per-family config is done.

## Issues to touch
hwbench #10, #12, #14, #15, #17 (PR). New issues to file: quant-ladder sweep; backend/OS A/B; new-family intake batch; dual-agent write-up; creative category.
