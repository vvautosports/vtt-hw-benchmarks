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

- **Output-invariant axes** (speculative type, parallel slots): lossless by construction — they cannot change what the model says, only how fast. Speed-only measurement is *correct* here, not a shortcut.
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

## References

- "The 120GB ZBook" artifact — memory-unlock research + G1a Fedora runbook (session artifact, Kal has the link)
- [Unsloth Desktop docs](https://unsloth.ai/docs/desktop) · [AMD support](https://unsloth.ai/docs/basics/amd) · [API endpoint](https://unsloth.ai/docs/basics/api) · [Qwen3.8-Next guide](https://unsloth.ai/docs/models/qwen3.8-next)
- [llm-tracker Strix Halo](https://llm-tracker.info/_TOORG/Strix-Halo) · [strixhalo.wiki clustering](https://strixhalo.wiki/AI/Clustering) · [L1T inference notes](https://forum.level1techs.com/t/strix-halo-llm-inference-notes/249466)
- vvt-infrastructure: `MASTER-GUIDE-STRIX-HALO-LLM.md`, `workstation-strix-halo-runbook.md`, `services/mlops/`
