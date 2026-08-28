# Unsloth Direction — Model Benchmarking v2

**Status:** Active | **Started:** 2026-08-26 | **Issue:** [#8](https://github.com/vvautosports/vtt-hw-benchmarks/issues/8)

The benchmarking repo's second act: adopt Unsloth as the serving/training layer on the Strix Halo fleet, benchmark it against raw llama-server, and grow the repo from one-shot hardware validation into a continuous benchmarking + fine-tuning-data program.

## Why Unsloth, why now

- **Already the de-facto model source.** 100% of models-inventory.yaml comes from `unsloth/*-GGUF` repos; UD dynamic quants for everything >30GB. Adopting their tooling ratifies existing practice.
- **The server is llama-server underneath.** `unsloth run --model unsloth/<repo>:<quant>` wraps our existing engine with auth (bearer keys), dual API dialects (OpenAI `/v1/chat/completions` + Anthropic `/v1/messages`), model management, monitoring (TTFT/throughput), and speculative-decoding modes (mtp/dspark/ngram). Extra flags forward to llama-server, so `-fa 1 -mmp 0 -ngl 999` carries over.
- **It kills the LM Studio problem.** Fully headless and scriptable; replaces the manual hand-recorded baseline workflow.
- **Training on our actual hardware.** Official Strix Halo (gfx1151) ROCm support on Windows + Linux, LoRA/QLoRA validated by AMD collab. Inference and fine-tuning converge on one stack.
- **Coverage limit:** RDNA 2+ only. Columbus/Cincinnati MI50s (gfx906) stay on the pinned llama.cpp Vulkan stack.

## Verified findings (2026-08-26)

| Finding | Evidence |
|---|---|
| Unsloth on **Windows** detects the G1a's Radeon 8060S | `Hardware detected: ROCm (HIP 7.13.99004)`; auto-installed `windows-x64-rocm-gfx1151` llama.cpp prebuilt (b10472). Supersedes the LM Studio CPU-only baseline |
| Headless serve works end-to-end on Windows | Qwen3.5-4B UD-Q4 downloaded + served + authenticated completion via studio API (port 8888/8889) |
| Windows GPU memory ceiling ~56GB | ROCm reports 57286→56262 MiB usable (≈50% of 128GB) — Linux + GTT unlock (120GB+) remains the real ceiling; see the "120GB ZBook" runbook artifact |
| Framework kernel 7.1.9 lost the GTT unlock args | Default `ttm.pages_limit` = 62GB; grubby re-apply staged, takes effect next reboot |
| Fedora GNOME auto-suspend killed a live download | 15-min AC idle suspend (user session AND GDM each have one). Fixed: suspend.target masked + `sleep-inactive-ac-type=nothing`; GDM override + WOL enablement pending |
| Framework serve up; Qwen3.8-Flash-Next **blocked on qwen4exp** | Serve attempt failed: `unsloth/llama.cpp` `b10472-mix-4b653db` lacks the `qwen4exp` arch. Serving champion **GLM-4.7-Flash UD-Q8_K_XL** (202K ctx) instead; release watch armed for any tag > `b10472-mix-4b653db` |

## Target architecture: dual-agent, two-node

Not tensor-split clustering — each node serves its own model at full local speed; coordination is API-level token traffic over the Headscale mesh (interconnect-irrelevant). llama.cpp RPC pooling (256GB) stays available as an occasional capability mode for >128GB models, not the default topology.

- **Thinker/driver node** (Framework): long-context fast MoE. Candidate: **Qwen3.8-Flash-Next 125B-A6B** (262K ctx, `reasoning_effort` dial — idle low while monitoring, xhigh to interrupt). Champion GLM-4.7-Flash holds the title until benchmarked.
- **Coder node** (G1a, post-dual-boot): best available coding model (Qwen3-Coder-Next on disk). Serves `/v1/messages` → Claude Code/OpenCode point at it directly.
- **Escalation tier**: local coder → local thinker review → cloud model on failure signals. Implemented as routing policy in the LiteLLM/omnigent layer (serving *policy* is omnigent ADR-0001 territory; this repo owns the measurement).

## Workstreams

### A. Unsloth validation (in progress)
- [x] G1a Windows: install, GPU detection, headless serve, authenticated completion
- [ ] Framework: Qwen3.8-Flash-Next serve + first delegated task over mesh
- [ ] Overhead benchmark: same model via `unsloth run` vs raw llama-server (t/s, TTFT delta)
- [ ] Post-reboot: full-GPU (120GB GTT) vs hybrid offload comparison
- [ ] `unsloth studio update` cadence decision (prebuilt was 11 days stale at first Framework run)

### B. Memory unlock + G1a dual-boot
Runbook lives in the "120GB ZBook" artifact (BIOS table, Ventoy steps, kernel args, RADV unified heap, swapfile). Blockers cleared 2026-08-26: BIOS confirmed 01.05.07 (suspend-bug version, workarounds known); C: cleanup path identified (368.8GB HF cache to relocate).

### C. Harness integration
- [ ] `unsloth` backend beside llama-bench/llama-server in the test scripts: bearer-key auth, studio port, same metrics out
- [ ] **llama.cpp-version sweep suite**: pin model+quant, vary runtime version weekly — measures the optimization curve (KV, MTP, kernels) of day-zero models separately from the model itself. Qwen3.8-Flash-Next is sweep target #1; mature Qwen3.5-9B(-MTP) anchors the optimized end
- [ ] `baseline:` axis tags in models-inventory.yaml (see retention policy below)
- [ ] Python/MLflow logging layer (repo currently has zero Python — see D)

### D. Infrastructure deploy
- [ ] MLflow Phase 2 on MS-01 (`scripts/deployment/docker-compose.mlflow.yml`) — reconcile with the near-duplicate compose in vvt-infrastructure `services/mlops/`, de-hardcode credentials, decide the MinIO story (bundled sidecar vs Cincinnati LXC 510)
- [ ] Experiment naming + run-tag schema (greenfield — design for node/backend/model/quant/runtime-version axes before first logged run)
- [ ] Framework `/mnt/ai-models` as fleet model store; new downloads land there (Qwen3.8 currently in HF cache on root — move after validation)

### E. Model-watch automation

**Roster expansion queue lives in [#10](https://github.com/vvautosports/vtt-hw-benchmarks/issues/10)** (Qwen3.8-27B w/ MTP sidecar, Gemma 4 suite incl. 26B-A4B MoE, Nemotron-3.5-Lightning successor swap, MiniMax-M3 successor swap; MiniMax-H3 excluded — video-gen, not an LLM). Downloads gated on Kal per the doctrine below.

Queue additions (Kal, 2026-08-27 evening):
- **DeepSeek-V4-Flash-0731** at **UD-IQ3_XXS (~104 GB)** — Q4_K_XL (~155 GB) exceeds the ~122 GB ceiling, IQ3_XXS matches the Qwen3.8-Q4 footprint that loads fine. "Makes sense in this latest flash round."
- **Muse-Glimmer-30B** (meta-models; unsloth GGUF + Q8 mmproj) — vision-native 30B; first modern contender for the vision/screenshot track; supersedes gemma-3-27b's mmproj niche (that model deleted same day, benchmarks banked).
- **Ornith-1.5-9B** (GGUF updated 2026-08-24) — flagged for the **MI50 fleet** (Columbus/Cincinnati gfx906, pinned Vulkan stack): if Ornith-1.5-35B keeps earning its co-leader spot, the 9B is the family's natural small-card representative.
Daily checks so new/updated models surface without manual trawling:
- [ ] HF poll: new repos + updated UD quants in `unsloth/` org (HF API; also catches new quant variants of tracked models)
- [ ] llama.cpp release tags + Unsloth changelog (day-zero support signals)
- [ ] Community pulse: r/LocalLLaMA, llm-tracker.info Strix Halo page, L1T inference-notes thread
- [ ] Surface: Discord post + auto-filed issue when a tracked-family successor or sweep-relevant runtime lands. Implement as scheduled Claude task or cron on MS-01; keep the check read-only, human decides downloads

### F. Nightly benchmark + fine-tuning data flywheel
Dedicate a nightly window (boxes are idle, suspend now masked) to continuous benchmarking:
- Rotating queue: version sweeps, day-one runs for new models, quant ladders, context sweeps, Vulkan-vs-ROCm, spec-decoding modes
- **Task-based evals drawn from VVC's real stack** (our repos' languages, frameworks, infra patterns, actual issues/diffs): scores measure what we actually care about, and graded transcripts accumulate into a **local fine-tuning corpus** (SFT + preference pairs) — which Unsloth can then train on, on the same hardware. Benchmark → data → LoRA → benchmark the LoRA.
- Results → MLflow (once D lands); scheduler = systemd timer on-node or scheduled Claude task
- Data stays local (fits the offline/dark-factory doctrine); curation rules TBD before first training run

## Retention policy (2026-08-26)

Models are deleted only with a **designated successor** (newer same-family gen on disk/registered, or an explicit era-successor recorded at deletion). **Small niche models stay.** `unsloth/` copies are canonical for duplicates. **Baseline/control models are exempt** — kept deliberately to isolate axes:

| Kept model | Controls for |
|---|---|
| gemma-3-27b (unsloth copy) | Dense-vs-MoE at ~27B |
| Qwen3-235B-A22B | Prev-gen large MoE / parameter scaling; family lineage vs Qwen3.8 |
| gpt-oss-120b + 20b | Fully-optimized MoE reference pair (software-maturity anchor) |
| GLM-4.7 Flash / REAP-218B | Pruning axis (REAP-23B deleted 2026-08-27 — no niche, datapoint recorded) |
| Apriel-1.5-15B-Thinker | Small dense reasoning |
| Ministral-3-14B | Small dense instruct |

2026-08-26 cleanup: ~504GB deleted from `/mnt/ai-models` (98%→55% full). Deletions + designations logged in the issue and session memory.

## Param-tuning sweep — GLM-4.7-Flash UD-Q8_K_XL (2026-08-26)

Framework serve via `unsloth run`, 202K ctx, measured through the studio API (`/v1/chat/completions`, seed 42, max_tokens 8192). Battery: 3 fixed tasks — multi-step reasoning (verifiable count), code with doctest requirements, faithful 5-bullet summarization.

**Canonical data: [`results/sweeps/2026-08-26-glm47-flash-param-sweep/`](../../results/sweeps/2026-08-26-glm47-flash-param-sweep/)** — `manifest.yaml` (run context, keyed to map 1:1 onto MLflow params/tags), `phase{1,2}.jsonl` (per-request records → MLflow metrics), `outputs/` (raw transcripts — seed data for the workstream F fine-tuning corpus). The tables below are the human summary only. When MLflow Phase 2 (workstream D) lands, backfill by replaying the JSONLs; the manifest schema doubles as the first draft of D's run-tag schema.

### Metrics model

Two classes of axis, measured differently — never conflated:

- **Output-invariant axes** (parallel slots; speculative type *only* for draft-model and n-gram speculation): lossless by construction — they cannot change what the model says, only how fast. Speed-only measurement is *correct* here, not a shortcut.
  - **Amended 2026-08-27:** native-MTP speculation is **not** output-invariant in practice. The original claim rested on GLM-4.7-Flash producing byte-identical same-seed outputs across spec modes — but GLM has no native MTP head. Qwen3.6-35B-A3B-MTP, which does, produced materially different outputs with MTP on vs off (2947 vs 4432 tokens on reasoning) and its summarize grade **flipped from pass to fail**. So for any model with a native MTP head, treat speculative type as an output-changing axis and grade it.
- **Output-changing axes** (sampling profile, reasoning_effort, quant, model): quality must be measured alongside speed. Quality lives as a structured `quality` object per JSONL record (programmatic graders: verifiable answers, doctest compliance, structure checks — deterministic, no judge). Execution-based grading (actually running generated code) and judge-scored fidelity are workstream F.

**Planned: usage-weighted utility score.** Store only raw per-task/per-domain metrics (JSONL → MLflow); the composite ranking is a *view* — a versioned weight vector applied at read time, never baked into stored data. Weights derive from how VVC actually uses AI, recomputed per release from repo-activity signals: language/path mix of recent commits across VVC repos, new benchmarks added, prompts/references landed, open-issue emphasis. Re-ranking history under new weights is then free, and "best model" tracks what the org is actually doing rather than a static benchmark. Design tracked in issue #11.

### Phase 1 — per-request axes (sampling profile × reasoning_effort)

Raw throughput is flat (~28–35 t/s wall) regardless of sampling — the axis that matters is **token economy to a correct answer**. `reasoning_effort` is honored by the serve and scales reasoning length (xhigh ≈ 2× medium).

| profile/effort | mean t/s | total wall (3 tasks) | quality (graded on the **content** channel) |
|---|---|---|---|
| **thinking/low** ← pick | 33.3 | 121s | all correct in content; doctests a bit verbose (14) |
| thinking/xhigh | 32.5 | 141s | all correct; 2× reasoning tokens for no quality gain here |
| thinking/medium | 31.9 | 147s | **content-leak defect**: code + doctests written into `reasoning_content`, final content is a summary claiming the work ✗ |
| thinking/none | 31.8 | 261s | correct; ironically *more* total tokens than medium |
| instruct/low | 34.9 | 110s | fastest compliant run, but scattergun code (22 doctests) |
| instruct/medium | 28.3 | 390s | code bloat (8.5K tokens on one task) |
| instruct/xhigh | 33.8 | 246s | code **truncated** at the 8192 cap (`finish=length`) ✗ |
| instruct/none | 28.1 | 336s | code missing required doctest block ✗ |

Profiles: thinking = temp 1.0 / top-p 0.95 / top-k 20 · instruct = temp 0.7 / top-p 0.80 / presence 1.5. Two failure modes only content-channel grading catches: the presence-penalty profile degrades long structured output (bloat → truncation), and thinking/medium reproducibly **answers into the reasoning stream** on the code task — a whole-transcript grep scores it correct, an API consumer gets no code. **Recommended per-request config: thinking profile, `reasoning_effort: low` as the idle/default; xhigh for interrupts** (per the dual-agent design); treat medium as suspect for code delivery until re-tested on newer builds.

### Phase 2 — server axes (--speculative-type × --parallel)

Fixed request config: thinking/medium (chosen before the content-leak finding; irrelevant here — these axes are output-invariant, so the ranking stands). Same-seed runs across spec modes produced byte-identical reasoning/summarize outputs — determinism check passed.

| server config | mean t/s (single-stream) | 4-way aggregate t/s |
|---|---|---|
| **spec=auto, np=4** (studio default) | 33.2 | 31.0 |
| spec=mtp+ngram, np=4 | 33.1 | 31.1 |
| spec=ngram, np=4 | 31.9 | 30.8 |
| spec=mtp, np=4 | 28.2 | 26.5 |
| spec=off, np=4 | 26.4 | 27.9 |
| spec=auto, np=1 | 33.7 | 31.1 |
| spec=auto, np=8 | 32.6 | 31.1 |

Findings:

- **Studio's `auto` default is already optimal** — no server-flag change to the baseline serve. `mtp+ngram` ties it; pure `mtp` *hurts* on GLM-4.7-Flash (no native MTP head to exploit; verification overhead only).
- **Speculation is worth +26% overall and +69% on code** (auto 38.6 vs off 22.8 t/s on the code task) — structured text accepts drafts; keep it on for the coder-node use case especially.
- **Slot count is irrelevant on this hardware**: aggregate throughput pins at ~31 t/s for np=1/4/8 — classic bandwidth-bound MoE behavior (the summarize source passage's prediction, empirically confirmed). No reason to change np=4; concurrency neither helps nor costs aggregate.
- Ops gotcha, recorded for the harness backend: this llama-server build **ignores SIGTERM** — orchestration must escalate to SIGKILL.

## Roster validation — 5 models (2026-08-27)

Same battery, same request config as the param sweep (thinking / `reasoning_effort: low`, seed 42, max_tokens 8192), on `b10472-mix-4b653db`. The axis here is **model**. Canonical data: [`results/sweeps/2026-08-27-roster-validation/`](../../results/sweeps/2026-08-27-roster-validation/).

The driver ran the roster twice — once pre-reboot (62GB ttm) and once post-reboot with the 128GiB GTT unlock active. Both passes are kept and tagged; the delta between them is the finding, not noise.

| model | quant | t/s (reason/code/summ) | content-channel quality | verdict |
|---|---|---|---|---|
| **gemma-4-26B-A4B-it** | UD-Q8_K_XL | 36.6 / 36.8 / 35.0 | 3/3 pass | beats the GLM champion by ~+13%, stable across both GTT states |
| Nemotron-3.5-Lightning-30B-A3B | UD-Q8_K_XL | 41.4 / 51.8 / 45.5 (run1) | 2/2 gradeable pass | run2 broke — see the MTP section below |
| Qwen3.8-27B | UD-Q8_K_XL | 13.5 / 13.5 / 13.2 | 3/3 pass | no qwen4exp blocker at 27B — that is specific to Flash-Next |
| gemma-4-31B-it | UD-Q8_K_XL | 5.6 / 5.8 / 5.4 | 3/3 pass | dense control, ~6.5× slower than the A4B MoE of similar footprint |
| MiniMax-M3 | UD-Q3_K_XL | — | — | load failed both passes |

Three corrections to earlier assumptions, all of which had been recorded as something other than what they were:

- **MiniMax-M3 did not fail on architecture.** The driver logs `LOAD FAILED (arch unsupported or crash)` as a generic catch-all; the backend actually reported *"needs about 181 GB but only about 122 GB of memory is available"*. A plain capacity failure. The useful number here is **~122 GB usable**, not the nominal 128 GiB GTT. M3 stays on disk for the dual-machine RPC-pool test.
- **`gtt_used_mib` is a broken metric.** It reads 411–418 MiB for every model in both passes against 26–36 GB of resident weights. `/sys/class/drm/card*/device/mem_info_gtt_used` is not representative on this unified-memory APU. Do not cite it; `grep gttsize /proc/cmdline` is authoritative.
- **The transcript-trampling bug recurred.** Both passes wrote to the same `outputs/<model>/<task>--…txt` path, so only the last pass that produced output survives — and provenance is *mixed*, because Nemotron's two failed run2 tasks never overwrote run1's files. `grade_sweep.py` now encodes this: it grades only the last non-error record per group and marks the rest `graded=False, reason="transcript_trampled"`. Speed data survives; quality data does not. Fixed at the source in the batch driver, which gives every model/config its own output directory.

### MTP speculation is model-specific — and was a live defect on Nemotron-3.5

Nemotron-3.5's post-reboot HTTP 500s were **not** a transient compiled-cache rebuild (that line appears once at process start in both passes) and the server never crashed — it returned 500s at request time, then served the next task on the same PID. A two-config matrix ([`2026-08-27-nemotron-retest/`](../../results/sweeps/2026-08-27-nemotron-retest/)) settled it:

| config | reasoning | code | summarize |
|---|---|---|---|
| `--speculative-type off --parallel 4` | 43.2 t/s ✓ | 46.8 t/s ✓ | 46.9 t/s ✓ |
| `--speculative-type mtp --parallel 1` | HTTP 500 | HTTP 500 | 27.3 t/s, quality ✗ |

The second row is an **exact reproduction** of overnight run2 — same two tasks failing, same surviving task, same 1008-token output, same quality failure. So:

- **MTP is the cause; the `-np > 1` conflict is not.** The earlier hypothesis (that `--parallel 4` combined with `draft-mtp` was at fault) is disproven — dropping to `--parallel 1` while keeping MTP still fails identically.
- **The breakage is model-specific, not build-wide.** Qwen3.6-35B-A3B-MTP runs MTP on the same build with no errors and gains **+31–35%** from it (57.6/58.2/50.0 with MTP vs 43.8/43.1/41.6 with it off). Combined with the phase-2 finding that pure `mtp` *hurts* GLM-4.7-Flash (no native head, verification overhead only), the rule is: MTP pays only with a native head, and having one is no guarantee it works.
- **Operational consequence:** Nemotron-3.5 must be launched with `--speculative-type off` explicitly. Studio's auto-selection picks `draft-mtp` for it, and that path is broken on b10472 post-reboot. With speculation off it is a genuine contender at ~43–47 t/s with clean grades.
- Open second-order question: run1 (pre-reboot) ran MTP *successfully* at 41–52 t/s, so something about the post-reboot memory state tips it over. Not blocking; worth re-testing on b10639.

## Phase-2 candidates + generational control arm (2026-08-27)

Nine configurations, same battery, still on `b10472` so they share a frame with the roster above. Canonical data: [`results/sweeps/2026-08-27-b10472-batch/`](../../results/sweeps/2026-08-27-b10472-batch/).

The legacy models here are a **control arm, not a deletion queue**. Per Kal's directive (2026-08-27) a model is retired only once there is empirical evidence it holds no niche its successor cannot cover — this run is that evidence.

| config | t/s (reason/code/summ) | quality | verdict |
|---|---|---|---|
| **Qwen3.6-35B-A3B-MTP** (MTP on, default) | **57.6 / 58.2 / 50.0** | 3/3 | fastest validated model; ~+50% over the champion |
| **Ornith-1.5-35B-A3B** | 54.6 / 58.5 / 52.1 | 3/3 | dead heat with the above; non-UD quant |
| Qwen3.6-35B-A3B-MTP (MTP off) | 43.8 / 43.1 / 41.6 | 2/3 | MTP is worth +31–35% here |
| Nemotron-3-Nano-30B-A3B | 39.7 / 41.7 / 40.5 | 3/3 | prior generation; see below |
| **Qwen3-Coder-30B-A3B-Instruct** | 39.5 / **73.3** / 18.9 | 2/3 | highest single figure in the study; genuine specialist |
| GLM-4.7-Flash-REAP-23B-A3B | 30.6 / 31.3 / 24.3 | 1/3 | slower than the full champion *and* fails two graders |
| Qwen3-Coder-Next | 18.2 / **500** / 28.6 | 0/2 | fails every task; see confound |
| gemma-3-27b-it | 6.7 / 6.7 / 6.3 | 3/3 | correct but 5.5× slower than gemma-4-26B-A4B |
| MiniMax-M2.5 (UD-Q3) | 71.8 / 15.6 / 35.8 — all **capped** | 0/3 | never terminates; hit the 8192 cap on all three |

Generational verdicts, which is what the control arm was for:

- **Qwen3-Coder-30B → Coder-Next is an inversion.** The newer, 2.7× larger model loses on every axis: 145 tokens on reasoning (no answer at all), a 500 on code, 8,238 tokens on a five-bullet summary. The predecessor turns in the best code throughput measured anywhere in this study. **Coder-30B has a clear niche and stays.** Confound worth honouring: Coder-Next's 500 landed while the 104 GiB Flash-Next download was still running, and it used `--spec-default` (not MTP), so this is unrelated to the Nemotron failure — re-test on an idle box before calling it settled.
- **Nemotron 3-Nano → 3.5-Lightning is a real but modest gain** (+9–16%), both 3/3 clean. Nano's compensating niche: it runs correctly on *default* flags, while 3.5 returns 500s unless launched with `--speculative-type off`. For an unattended harness today, Nano is the safer of the two.
- **gemma-3-27b holds no speed or quality niche** — gemma-4-26B-A4B is 5.5× faster at identical grades. It does ship an `mmproj-F32.gguf` vision projector the gemma-4 GGUFs on disk lack; this text battery cannot see that, so a vision niche remains untested rather than disproven.
- **GLM-4.7-Flash-REAP-23B shows no niche at all** — smaller on disk, slower and worse on every axis measured against the full champion.
- **MiniMax-M2.5's on-disk copy is unusable for this battery**, but it is the only UD-Q3_K_XL model in an otherwise Q8 field, so that indicts the copy, not the model. Its intended comparison against M3 stays blocked while M3 cannot load on one node.

### llama.cpp-version sweep — first datapoint (issue #8, workstream C)

Same model, same quant, same prompts, same seed; only the runtime moves. [`2026-08-27-version-sweep/`](../../results/sweeps/2026-08-27-version-sweep/)

GLM-4.7-Flash, same quant, same prompts, same seed, same sampling — only the runtime moved. `unsloth studio update` also carried the studio package 2026.8.21 → 2026.8.22, so this measures "the upgrade", not llama.cpp in isolation.

| build | reasoning | code | summarize |
|---|---|---|---|
| `b10472-mix-4b653db` (2026-08-18) | 32.34 t/s · 2128 tok · 65.8s · ✓ | **38.64 t/s** · 6169 tok · 159.7s · ✓ | 33.28 t/s · 1905 tok · 57.2s · ✓ |
| `b10639-mix-f6f92fe` (2026-08-27) | 31.72 t/s · 908 tok · 28.6s · ✓ | 31.28 t/s · 12339 tok · **394.4s** · ✓ | 31.57 t/s · 870 tok · 27.6s · **✗** |

**b10639 is a net regression on this hardware.** Three separate things say so, and none of them would have been visible without the same-day control:

- **Throughput.** Down on all three tasks; code worst at −19.0%. On b10472 code was the *fastest* task (38.64 t/s) because speculation pays best on structured text — the phase-2 run measured +69% on code from speculation. On b10639 all three tasks land within 31.3–31.7 t/s, a flat profile that looks like speculation no longer helping. Worth a spec-type sweep on the new build to confirm.
- **Token economy moved both ways, and it dominates wall-clock.** Reasoning fell 2128 → 908 tokens (65.8s → 28.6s — a 2.3× end-to-end *win* despite lower t/s), while code rose 6169 → 12339 tokens (159.7s → 394.4s, a 2.5× *loss*). Ranking builds on t/s alone misses both.
- **Instruction-following broke, on two independent models.** GLM's summarize returned a prose paragraph with zero bullets of any style where b10472 produced the requested five. Qwen3.6-35B-A3B-MTP's code answer regressed from 6 doctests to **none** — it emitted a two-line reasoning summary ("All 8 doctests pass") and a markdown table describing eight test cases, with no function definition anywhere in *either* channel.

That last one is worth naming precisely: it is **not** the 2026-08-26 content-leak defect. Content-leak was a channel-routing problem — the answer landed in `reasoning_content` and a summary in `content`. Here the answer exists in neither channel; the model wrote as though it had already produced and run the code in an earlier turn. That shape points at chat-template or turn-boundary handling, which is exactly what a build carrying two *unmerged* upstream PRs can break.

**Consequence for the metrics model: runtime build is an output-changing axis.** It must be quality-graded, never ranked on speed alone. This also vindicates content-channel grading — a whole-transcript grep would have seen "doctests" mentioned in the Qwen3.6 answer and scored it correct.

### Post-upgrade batch on b10639

[`results/sweeps/2026-08-27-b10639-batch/`](../../results/sweeps/2026-08-27-b10639-batch/)

| model | t/s | quality | verdict |
|---|---|---|---|
| Qwen3.8-Flash-Next (UD-Q4) | 204.7 / 224.7 / 217.0 | 0/3, all **capped** | loads but unusable |
| Nemotron-3.5-Lightning (default) | 500 / 500 / 500 | — | worse than b10472 |
| Qwen3.6-35B-A3B-MTP (control) | 53.6 / 55.8 / 53.8 | 2/3 | regressed from 3/3 |

- **The qwen4exp blocker is genuinely lifted** — Qwen3.8-Flash-Next loads and generates, which b10472 could not do at all, and it is the fastest thing ever measured on this box (204–225 t/s, credible for a 125B-A6B MoE with ~6B active at Q4). But it **never terminates**: all three tasks ran to the 8192-token cap. A model that cannot stop is not usable, so those rates are not a ranking. Likely incomplete stop-token handling in an arch carried as an open PR. Re-test when ggml-org/llama.cpp#27742 merges.
- **The upgrade did not fix Nemotron's MTP defect — it worsened it.** b10472 failed 2 of 3 tasks; b10639 fails all 3. The workaround is unchanged and still mandatory: `--speculative-type off`.

**Recommendation: treat `b10472` as the production build and `b10639` as qwen4exp-experimental only.** Nothing currently depends on b10639 that works. Rollback is Kal's call; the upgrade also broke curated whisper.cpp dictation (installer: whisper requires the b10472 pairing; browser and Transformers dictation unaffected).

> **Superseded same day — root cause found.** The non-termination and (at least the structural half of) the quality regressions trace to `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1`, not to b10639's inference code. See the next section before acting on anything above.

## Root cause: unified-memory env corruption on Strix Halo (2026-08-27, PM)

The b10639 "net regression" and the Qwen3.8-Flash-Next non-termination share one root cause: **the studio wrapper auto-sets `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` for AMD unified-memory APUs, and under `b10639-mix-f6f92fe` on gfx1151 that corrupts inference itself.** Diagnosis chain (probe data on Framework `~/qwen38next-{eos,raw,umfix}-probe/`):

1. **Budget was not the issue.** At `max_tokens=32768` (4× the battery cap), effort=low, the model still spent every token inside reasoning and never closed it — kills the "verbose thinker, raise the cap" hypothesis.
2. **Non-thinking mode was garbage from token 1.** `reasoning_effort: none` and `enable_thinking: false` both produced pure `"/"` spam to the cap.
3. **The base LM itself was broken.** Template-free raw `/completion` ("Counting: one, two, three," greedy) → `"/"` spam. So: not a stop-token bug, not a chat-template bug, not an EOS-metadata bug. The forward pass was computing garbage.
4. **Community match.** HF `unsloth/Qwen3.8-Flash-Next-GGUF` discussion **#30**: gibberish on Strix Halo since Unsloth Desktop sets `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1`; workaround `UNSLOTH_DISABLE_UNIFIED_MEMORY=1`. Opt-out verified in studio source (`studio/backend/core/inference/llama_cpp.py`, `_unified_memory_opted_out`): ggml tests *presence* of the var, so `=0` is not an off switch — the opt-out must end in the name being unset. Confirmed live: our serving `llama-server` had the var in its environment.
5. **With the opt-out, everything works.** Greedy counting completes sanely; thinking-mode closes its reasoning at 653 tokens with the correct answer; `reasoning_effort: low` is honored (211-char reasoning); effort=none answers coherently with an `ANSWER:` line; and the **GLM-4.7-Flash summarize control on b10639 produces the exact 5-bullet + TL;DR structure** whose loss defined the b10639 quality regression.
6. **It is an interaction, not the var alone.** The var has shipped for Strix Halo since ~June (off switch added 2026-08-13, unslothai/unsloth #8680), so the clean b10472 batch almost certainly ran *with* it. Corruption = var × b10639-mix × gfx1151.

Caveats that survive the root cause:

- **The 204–225 t/s Qwen3.8-Flash-Next figures were artifacts of garbage generation** — discard them. A short fixed run measured ~20 t/s raw; real numbers come from the re-validation batch.
- Nemotron's MTP 500s and the whisper pairing break (stale `paired_llama_tag` after the in-place runtime update) are separate issues; the whisper one is metadata/linkage, not inference.
- HF discussion #27 ("Thinking Nightmare") reports this family still over-thinks at effort medium+ on healthy runtimes — effort=low stays the battery default.

**Consequences:**

- **The rollback decision is reopened.** The hybrid-split decision (b10472-mix standalone as production) was made on the pre-root-cause evidence. If the re-validation batch (below) comes back clean, b10639 + `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` is the production candidate and no rollback is needed. Either way, `b10472-mix-4b653db` is now staged standalone (sha256-verified against the release manifest) at Framework `~/llama-runtimes/b10472-mix-4b653db/` as a pinned A/B-fallback runtime; studio can front any external llama-server via Settings → Connections.
- **The per-family config registry is live** (Kal directive 2026-08-27: best model per task at its best-known config; uniformity is not a constraint). `roster_batch.py` spec entries now take an optional `"env"` dict recorded into every result record. First registry entries: `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` (all families, this hardware) and Nemotron's `--speculative-type off`.
- Upstream reporting — **decided (Kal, 2026-08-27): not filing a GitHub issue.** The written draft stays in the run dir (`upstream-issue-draft.md`) as source material for a possible HF forum/community post later. HF #30 already has the community's attention on the symptom; our addition would be the template-free repro and the subtle-GLM-degradation datapoint.

### Re-validation batch: b10639 + env fix (graded, 2026-08-27)

[`results/sweeps/2026-08-27-b10639-umfix-batch/`](../../results/sweeps/2026-08-27-b10639-umfix-batch/) — all entries launched with `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` via the new per-entry `env` registry in `roster_batch.py`.

| config | t/s (reason/code/summ) | quality | verdict |
|---|---|---|---|
| GLM-4.7-Flash (umfix) | 31.7 / 36.1 / 31.8 | **3/3** | summarize structure back, code bloat gone (5.9K tok vs 12.3K); residual −6.7% code t/s vs b10472 |
| **Qwen3.8-Flash-Next** (umfix) | 15.6 / 22.3 / 17.1 | **3/3** | **first clean grades ever** — terminates, tight economy (433/3847/497 tok). Real speed ~16–22 t/s; the 204–225 figures were artifacts |
| **Nemotron-3.5-Lightning (default!)** | **56.0 / 56.3 / 53.2** | **3/3** | the "MTP defect" was the env interaction — default flags now the best config, +20% over specoff. Also resolves the b10472 run1/run2 mystery (run1 pre-dated the GTT unlock) |
| Nemotron-3.5-Lightning (specoff) | 44.5 / 47.2 / 47.0 | 3/3 | control; slower |
| Qwen3.6-35B-A3B-MTP (umfix) | 54.3 / 56.1 / 54.2 | 2/3 — code ✗ | **the one genuine b10639 regression**: phantom-prior-turn code failure reproduces WITH the fix (chat-template/turn-boundary, this family) |

**Rollback picture inverted.** b10639 + env fix dominates b10472 for everything measured except Qwen3.6's code task — and the code specialist is Qwen3-Coder-30B, not Qwen3.6. Nemotron is now the roster speed leader on clean grades (56 t/s, default flags).

**Decisions taken (Kal, 2026-08-27):**

- **Env fix made permanent on the Framework**: `~/.bashrc.d/unsloth.sh` (`export UNSLOTH_DISABLE_UNIFIED_MEMORY=1` — covers interactive, ssh-command, and harness `bash -c` launches) + `~/.config/environment.d/50-unsloth.conf` (systemd user services / GUI sessions). Verified end-to-end: a prefix-free `unsloth run` relaunch produced a llama-server with the GGML var absent, healthy API, and sane greedy output. Apply the same pair on the G1a when it next serves.
- **No rollback.** b10639 + env fix is production. The pinned `b10472-mix-4b653db` standalone stays staged as A/B insurance ([LLAMA-RUNTIME-PINNING.md](LLAMA-RUNTIME-PINNING.md)).
- **Whisper curated dictation stays blocked upstream**: `unsloth studio verify-install` passes but does not re-pair (`paired_llama_tag` still `b10472-mix-4b653db`), and unslothai/whisper.cpp's latest prebuilt (v1.9.2-unsloth.11, 2026-08-18) predates b10639 — no compatible build exists to install. Re-check on the next whisper prebuilt release; browser/Transformers dictation unaffected. The staged b10472 libs would allow a manual re-link, deliberately not done (breaks update flow).

### Roster re-baseline on b10639 + fix (graded, 2026-08-27 evening)

[`results/sweeps/2026-08-27-b10639-rebaseline-batch/`](../../results/sweeps/2026-08-27-b10639-rebaseline-batch/) — idle box (Coder-Next confound removed), fix in every launch.

| config | t/s (reason/code/summ) | quality | verdict |
|---|---|---|---|
| Ornith-1.5-35B | 54.1 / 52.7 / 56.6 | 3/3 | holds its crown on the new runtime |
| **Qwen3-Coder-30B** | 39.9 / **74.5** / 38.2 | **3/3** | best-ever full result — code king confirmed, summarize now passes too |
| gemma-4-26B-A4B | 35.7 / 38.0 / 35.5 | 3/3 | stable across runtimes |
| Nemotron-3-Nano | 39.5 / 45.3 / 41.3 | 2/3 | summarize near-miss (missing "TL;DR" label only). Niche eroded: 3.5-Lightning now runs default flags 3/3 at ~56 t/s — retirement evidence exists, call is Kal's |
| Qwen3-Coder-Next (idle) | 27.9 / 42.2 / 25.7 | 2/3 | **rehabilitated from 0/2** — the "generational inversion" was confound + corruption. Code fails with the Qwen phantom-prior-turn defect |
| MiniMax-M2.5 | 21.2 / 25.1 / 21.6 | 2/3 | **rehabilitated from 0/3** — terminates everywhere; "unusable copy" verdict was wrong (it was the corruption) |

**The residual b10639 failures now cluster into one shape — and it smells like cross-request state bleed.** MiniMax's summarize answer literally addresses `parse_ranges`, the *previous request's* topic ("I don't see any mention of a parse_ranges function in the source material…"), and both Qwen3-family code failures are models claiming to have already written the code in a prior turn. Unified hypothesis: b10639-mix leaks state across requests (slot reuse / `--kv-unified` / slot-save interaction) and models rationalize the leaked context as conversation history. Discriminating test queued in the manifest: reorder the battery or restart the server between tasks — if failures follow request *order* rather than task, it's runtime leakage, which would retroactively explain the version-sweep instruction-following regressions and gate parallel-slot use on this build.

### Bleed-order test: cross-request state bleed CONFIRMED (2026-08-27 night)

[`results/sweeps/2026-08-27-bleed-order-test/`](../../results/sweeps/2026-08-27-bleed-order-test/) — three affected models, each run reversed (one server) and isolated (fresh server per task), driver [`bleed_order_test.py`](../../scripts/sweeps/bleed_order_test.py):

| model / task | forward | reversed | isolated |
|---|---|---|---|
| Qwen3.6-MTP code | ✗ (req 2) | ✗ (req 2) | **✓ 6 doctests** |
| Qwen3-Coder-Next code | ✗ (req 2, after reasoning) | ✓ (req 2, after summarize) | **✓ 6 doctests** |
| MiniMax-M2.5 summarize | ✗ (answered prior topic) | ✗ (no TL;DR label) | ✗ (no TL;DR label) |
| MiniMax-M2.5 code | ✓ (req 2) | ✓ (req 2) | **✗ capped 8192, incoherent** |

- **The bleed is real.** Both Qwen-family "b10639 regressions" dissolve in isolation — Qwen3.6-MTP and Coder-Next are 3/3 on a fresh server per task. The phantom-prior-turn shape is the model rationalizing leaked context as history. **b10639 + env fix's single remaining defect is the bleed itself.**
- **MiniMax-M2.5 UD-Q3 is genuinely fragile**, bleed aside: first-request code runs to the cap with incoherent output (fake tags, drifts into HTML diffs), and its rebaseline code "pass" was *flattered* by leaked context. The Q3 copy stays indicted.
- **Determinism held**: same seed + same session position reproduces token counts exactly across variants — position was the hidden variable, the harness is sound.
- Suspected mechanism (untested): `--parallel 4 --kv-unified --slot-save-path` slot save/restore + LRU slot reuse on a build carrying unmerged KV-tracking changes. b10472 is *not* fully exonerated (its batches were multi-request but graded clean — weak evidence); the pinned standalone makes a b10472 order-test cheap if wanted.

**Protocol consequence (harness + production):** on b10639, multi-request grading sessions are contaminated — **isolated (fresh server per task) is ground truth** until the bleed is fixed. Any server-reusing batch measures "model + session history". Production multi-request serving on this build carries the same risk; weigh the pinned b10472 standalone for anything stateful-sensitive.

### Qwen3.8-Flash-Next settings matrix: 12/12 (2026-08-27 night)

[`results/sweeps/2026-08-27-qwen38-settings-matrix/`](../../results/sweeps/2026-08-27-qwen38-settings-matrix/) — vendor-doc coverage (effort ladder + recommended instruct sampling), fresh server per task per the bleed protocol:

| config | tokens (r/c/s) | battery wall | quality |
|---|---|---|---|
| thinking / **low** | 433 / 1095 / 344 | 113s | 3/3 |
| thinking / medium | 514 / 2335 / 390 | 178s | 3/3 |
| thinking / xhigh (vendor default) | 553 / 5379 / 575 | 325s | 3/3 — most thorough code (9 doctests) |
| **instruct** (0.7/0.80/20, presence 1.5) | 308 / 1384 / 351 | **107s** | 3/3 |

All four configs are quality-equivalent on this battery — the differentiator is pure economy. xhigh costs 2.9× low for no grade gain; instruct is the fastest config and passes everything including reasoning. HF #27's "over-thinks at medium+" does **not** reproduce on the fixed runtime (even xhigh fits 8192 comfortably) — that report was observing the corruption. The dual-agent "idle low / xhigh interrupts" dial is validated. Battery default stays thinking/low. Also note: isolated effort-low code = 1095 tok vs 3847 sequential — even Qwen3.8's passing sequential numbers were session-history-inflated, reinforcing the fresh-server protocol.

## Scoping: frontier-benchmark cross-reference (2026-08-27)

Goal: place every local-roster verdict in the context of published scores, so "best local model for task X" can be read against "how far below frontier is that."

- **Sources, in trust order:** LiveBench (contamination-controlled, monthly), Aider polyglot leaderboard (matches the coder-node use case), LMArena Elo (human preference, coarse), vendor model cards (self-reported — always flagged as such).
- **Anchor rows:** current Claude/GPT frontier scores on the same public benchmarks, so the table reads local → open-frontier → closed-frontier in one sweep.
- **Comparison axes:** local battery grade vs published rank (do our deterministic graders order models the same way LiveBench does?); t/s-per-quality on this hardware (published scores are quality-only — our t/s column is the thing no leaderboard has); quant gap (published scores are fp16/fp8 — our Q8/Q4 measurements bound the quant tax when a family appears in both).
- **Deliverable shape:** one cross-reference table in this doc first (manual, ~10 roster models × 3-4 published sources); a refresh script only once the table has proven it earns its keep. Store source, date, and benchmark version per cell — leaderboards move.
- **What it will NOT do:** no cross-benchmark arithmetic (no averaging LiveBench with Arena Elo), no claiming our 3-task battery is comparable to any published suite. The mapping is directional context, not a score.

### First cross-reference table (2026-08-27)

Research snapshot 2026-08-27 (two web sweeps; primary leaderboards are JS-rendered, so unverifiable numbers are marked). Tags: **VC** = vendor/self-reported claim · **3P** = third-party measured · **NL** = not listed on that leaderboard · **~** = aggregator-sourced, unconfirmed against the primary site.

**The meta-finding:** our sub-40B local roster is largely ABSENT from LiveBench/Aider/LMArena — the honest common denominator is vendor-claimed SWE-bench (Verified/Pro), plus Arena Elo where a vendor cites it. Treat every VC number as marketing until we or a third party reproduce it.

| model | local grades (best clean run) | local t/s (r/c/s) | SWE-bench (VC) | other published |
|---|---|---|---|---|
| Qwen3.8-Flash-Next | 3/3 | 15.6 / 22.3 / 17.1 | Pro 62.5 | LiveCodeBench 91.9 VC; BenchLM composite 67.5 ~ ; Arena NL |
| Ornith-1.5-35B | 3/3 | 54.1 / 52.7 / 56.6 | **Verified 79** (VC, uncorroborated) | all major boards NL |
| Qwen3.6-35B-A3B | 3/3 (isolated) | 54.8 / 57.7 / 48.9 | Verified 73.4 | Artificial Analysis II 32 3P; Arena NL |
| Qwen3-Coder-Next | 3/3 (isolated) | 28.3 / 41.9 / 23.7 | Verified 74.2 | Aider figures conflict (71.2 vs 61.0 VC) — unreconciled |
| Qwen3-Coder-30B | 3/3 | 39.9 / 74.5 / 38.2 | — | Aider polyglot ~60.9 @Q4 3P-blog, not on official board |
| Nemotron-3.5-Lightning | 3/3 | 56.0 / 56.3 / 53.2 | Verified 51.6 | Artificial Analysis II 24, 293 tok/s 3P |
| gemma-4-26B-A4B | 3/3 | 35.7 / 38.0 / 35.5 | — | **Arena Elo 1441** (VC-cited from tech report) |
| gemma-4-31B | 3/3 (b10472) | 5.6 / 5.8 / 5.4 | — | **Arena Elo 1452** (VC-cited); LiveCodeBench v6 80.0 VC |
| GLM-4.7-Flash | 3/3 | 31.7 / 36.1 / 31.8 | Verified 59.2 | AIME25 91.6 VC; all boards NL |
| Qwen3.8-27B | 3/3 (b10472) | 13.5 / 13.5 / 13.2 | — | Code Arena #9 (1595) 3P; BenchLM 72.5 ~ |
| MiniMax-M3 | cannot load (181 GB) | — | Pro 59.0 | Arena "pending at launch" |

**Frontier anchors** (Arena.ai text Elo, snapshot 2026-08-27, 3P): claude-fable-5 **1507** (#1) · claude-opus-4-7-high 1502 · gemini-3.1-pro-preview 1487 · gpt-5.5-high 1482. LiveBench anchors exist only via a mirror with internal inconsistencies — recorded as low-confidence: Fable 5 0.783, Opus 4.8 0.772, Gemini 3.1 Pro 0.799, GPT-5.5 0.807. Aider's official board (page stamped 2025-11-20) predates the current frontier generation entirely.

**Directional reads (not score arithmetic):** the gemma-4 pair's vendor-cited Arena Elo (1441–1452) sits ~40–65 points under the closed frontier (1482–1507) — Elo compresses at the top, so this overstates closeness, but it is the only same-scale bridge we have. On vendor SWE-bench Verified the local cluster (52–79) spans a wide range, with Ornith's uncorroborated 79 the claim most worth an independent re-test. Benchmark-version bookkeeping: LiveBench rotates ~1/6 of questions monthly; Aider polyglot is a static 225-exercise set updated ad hoc — record snapshot dates on any refresh.

## Scoping: multi-dimensional test tracks (2026-08-27)

Priority order per Kal (2026-08-27): **tool-calling/agentic first**, then quant and context axes, then creative/thinking/art. Rationale: the dual-agent architecture (thinker + coder nodes) lives or dies on tool-call reliability, not prose quality.

### Track 1 — tool calling & agentic (FIRST)

The capability that gates every planned use: browser control, app control, screenshotting, browsing, transcribing — i.e., can the model drive tools through `/v1/chat/completions` tool-call plumbing?

- **Tier 1 (deterministic, harness-gradeable now):** single tool call — correct function selection + valid JSON args from a spec (grade: schema-validate, exact-match on expected call); multi-turn chain — tool result fed back, model must use it (grade: final answer contains value only obtainable from the tool result); distractor test — 5 tools offered, only one correct; refusal test — no tool fits, model must answer directly instead of hallucinating a call.
- **Tier 2 (scenario, semi-deterministic):** mock browser/app-control APIs (navigate/click/screenshot/read as tool specs with canned responses) — grade on action-sequence validity, not pixel outcomes. Transcription slots in as whisper.cpp round-trip fidelity (existing dictation stack), which is a runtime test more than a model test.
- **Runtime interaction to measure explicitly:** unsloth's tool-call healing layer (`--enable-tool-call-healing`, text-form `<tool_call>` promotion) — grade each model with healing on AND off; a model that only tool-calls through healing is a different (worse) tier than one that emits clean calls. Also relevant: llama.cpp upstream issue #19513 (Qwen3-Coder-Next premature EOS on tool calls) — this family has known tool-call-boundary bugs, so the sibling models need exactly this battery.
- **Fits the existing metrics model:** all output-changing, content-channel-graded, deterministic graders — extends `grade_sweep.py` with a `toolcall` task family.
- **Qwen-family intel for the build** (research 2026-08-27): Qwen models emit Hermes-style `<tool_call>{json}</tool_call>`; llama.cpp maps them to its Hermes-2-Pro parser **only with `--jinja`** (our serves pass it) — without it, raw XML/`<think>` tags leak into content. Known footguns to build regression tests for: ggml-org/llama.cpp#19513 (premature EOS after ~10–20 sequential tool calls — Qwen3-Coder-Next, also reported for MiniMax-M2 and GLM-4.5-Air; add a "survives 15+ chained calls" test), #19382 (invalid JSON tool calls), historically-broken Coder chat templates (unsloth ships patched ones — prefer recent unsloth quants). **KV-cache quant below q8 measurably degrades tool-calling** per llama.cpp's own docs — treat `-ctk/-ctv` as a graded axis in the context ladder, never a freebie. Grading rule: log raw completions and validate the parsed `tool_calls` field against them; if scores look far below Qwen's published BFCL/SWE-bench claims, suspect template/parser mismatch before the model. Client stacks (Qwen-Agent framework, qwen-code CLI — their Claude Code analog) are orchestration layers, not serving requirements; qwen-code pointed at our llama-server is a candidate Tier-3 end-to-end harness.

### Track 2 — quant ladder & context-length axes

Both were already in workstream F's queue; Kal elevated them (2026-08-27).

- **Quant ladder:** same model, same battery, quant as the only axis (e.g. Qwen3.8-Flash-Next UD-Q4_K_XL vs the UD-IQ quants on disk; GLM Q8 vs REAP). Grades + t/s + peak memory per rung. Feeds the cross-reference table's quant-gap column. HF #27's observation that different quants of the same model behaved differently on the same prompt is exactly this axis unlabeled.
- **Context ladder:** fixed model+quant, tasks executed at 4K/32K/128K/max fill (needle-style retrieval + task-at-depth, deterministic graders). Measures both quality-at-depth and the KV-cache t/s cliff on unified memory. Directly prices the thinker-node use case (262K ctx claim vs. usable reality).

### Track 3 — creative / thinking / art (after 1–2)

- Creative writing with hard constraints (form, length, banned-word) — constraint compliance is deterministically gradeable; aesthetic quality is not (needs judge-model channel, kept separate from deterministic grades per the metrics model).
- Game generation (single-file playable HTML) — grade: parses, runs headless, passes smoke asserts. Execution-based grading infrastructure from workstream F.
- Visual/spatial reasoning (text-form) — deterministic answers exist; true image input waits on the vision-projector question (gemma-3 mmproj niche, untested).
- Windows-vs-Linux stays an axis here (G1a stays Windows until its Windows datapoints are banked — standing decision).

## References

- "The 120GB ZBook" artifact — memory-unlock research + G1a Fedora runbook (session artifact, Kal has the link)
- [Unsloth Desktop docs](https://unsloth.ai/docs/desktop) · [AMD support](https://unsloth.ai/docs/basics/amd) · [API endpoint](https://unsloth.ai/docs/basics/api) · [Qwen3.8-Next guide](https://unsloth.ai/docs/models/qwen3.8-next)
- [llm-tracker Strix Halo](https://llm-tracker.info/_TOORG/Strix-Halo) · [strixhalo.wiki clustering](https://strixhalo.wiki/AI/Clustering) · [L1T inference notes](https://forum.level1techs.com/t/strix-halo-llm-inference-notes/249466)
- vvt-infrastructure: `MASTER-GUIDE-STRIX-HALO-LLM.md`, `workstation-strix-halo-runbook.md`, `services/mlops/`
