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
| GLM-4.7 Flash / REAP-23B / REAP-218B | Pruning axis, two scales, one family |
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

## References

- "The 120GB ZBook" artifact — memory-unlock research + G1a Fedora runbook (session artifact, Kal has the link)
- [Unsloth Desktop docs](https://unsloth.ai/docs/desktop) · [AMD support](https://unsloth.ai/docs/basics/amd) · [API endpoint](https://unsloth.ai/docs/basics/api) · [Qwen3.8-Next guide](https://unsloth.ai/docs/models/qwen3.8-next)
- [llm-tracker Strix Halo](https://llm-tracker.info/_TOORG/Strix-Halo) · [strixhalo.wiki clustering](https://strixhalo.wiki/AI/Clustering) · [L1T inference notes](https://forum.level1techs.com/t/strix-halo-llm-inference-notes/249466)
- vvt-infrastructure: `MASTER-GUIDE-STRIX-HALO-LLM.md`, `workstation-strix-halo-runbook.md`, `services/mlops/`
