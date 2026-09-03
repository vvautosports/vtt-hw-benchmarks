# Evidence Lakehouse — Reference Architecture

**Status:** vision / target architecture (2026-09-03). Nothing here is deployed beyond
Phase 0 (MinIO CT 239 + MLflow/UC/Postgres CT 241, infra #201). This document is the
thing we build toward; implementation lands piece by piece behind it.

**Guiding lights** (Kal, 2026-09-03):

- Databricks, *What is an open lakehouse? Open data standards explained*
  <https://www.databricks.com/blog/what-open-lakehouse-open-data-standards-explained>
- `open-lakehouse/open-lakehouse` — Databricks DevRel's composable OSS demo stack
  <https://github.com/open-lakehouse/open-lakehouse>
- openlakehouse.io — community/education portal for the same initiative
  <https://www.openlakehouse.io/>

Related: `UNSLOTH-DIRECTION.md` (master narrative), `TRACK2-HARNESS-BENCHMARKS.md`
(agent battery design), memory `project_evidence_lakehouse` (the 2026-08-28 design that
this supersedes as the written source of truth).

---

## 1. Definition and the principles we adopt

Databricks' definition, which we take verbatim as the bar: *an open lakehouse is one in
which every layer (storage, table format, engine, catalog, and the ML/AI tools on top) is
built on open standards, so no layer is locked to a single vendor.*

Three principles → three VVC commitments:

| Principle | What Databricks names | VVC commitment |
|---|---|---|
| **Open formats** | Delta Lake / Apache Iceberg on Parquet | **Delta** on MinIO. delta-rs writes the benchmark lane; Spark writes racestream. Iceberg/UniForm deferred (§8). |
| **Open engines** | Spark, DuckDB, Trino, PyIceberg — one copy of data, many readers | **DuckDB (+ delta extension)** and **Polars** as readers for benchmark evidence. **Spark** is the near-term target engine for the racestream / raceedge pipelines (Kal, 2026-09-03), so the lake must be Spark-readable from day one (Delta on S3 already is). |
| **Unified governance** | One catalog (Unity Catalog) for ACLs, lineage, audit | **Unity Catalog OSS** as the catalog of record for tables, volumes and models. |

Plus the two AI-layer projects the post calls out: **MLflow** (lifecycle: experiments,
tracing, evaluation, registry) and **open-weight models** served by an OSS runtime
(for us llama.cpp via Unsloth Studio, not vLLM/Ollama).

The demo repo is a *pattern source, not a parts list*: we borrow per-service compose files,
`.claude/` lifecycle skills + `AGENTS.md`, bronze/silver/gold prefixes on one bucket, and
scheduled compaction. Two of its services are in scope on Kal's direction (2026-09-03):
**Spark** (near-term engine for racestream/raceedge) and **Airflow** (evaluate early — a
CI runner is not an orchestrator, see §8). We do **not** adopt Kafka, SeaweedFS or the
Iceberg-primary choice.

---

## 2. Layered target architecture

```
┌──────────────── consumers ────────────────┐
│ DuckDB / Polars notebooks · gold views     │
│ PERFORMANCE-SUMMARY generator · dashboards │
│ Claude Code (MLflow MCP, later)            │
├──────────────── lifecycle ────────────────┤
│ MLflow 3.x  experiments · runs · LoggedModel · traces · eval datasets · judges · registry (aliases)
├──────────────── catalog ──────────────────┤
│ Unity Catalog OSS  catalog vvc → schema evidence → tables · volumes · models (three-level names)
├──────────────── table format ─────────────┤
│ Delta on Parquet  (delta-rs writer, aws_conditional_put=etag)     bronze → silver → gold
├──────────────── object storage ───────────┤
│ MinIO CT 239  buckets: lakehouse · mlflow-artifacts · datasets · models   (tenant keys, never root)
├──────────────── evidence producers ───────┤
│ sweep drivers · agent_task_battery.py · grade_sweep.py · EvalScope (community lane) · llama-server /metrics
├──────────────── serving ──────────────────┤
│ llama.cpp (pinned build) via Unsloth Studio on framework / G1a / AI server · GGUFs from /mnt/ai-models
└───────────────────────────────────────────┘
```

Per-layer state today vs target:

| Layer | Deployed (Phase 0) | Target | Gap |
|---|---|---|---|
| Object storage | MinIO RELEASE.2025-04, 4 buckets with quotas, tenant policies | same | none — S3 API is the contract |
| Table format | nothing written yet | Delta tables under `s3://lakehouse/{bronze,silver,gold}/` | writer (hwbench #6) |
| Catalog | UC OSS **0.3.0** on Postgres | UC OSS **≥ 0.4.x** (catalog-managed commits, external locations) | upgrade; register tables + models; vending blocked by UC #43 |
| Lifecycle | MLflow **3.4.0** (Postgres + MinIO artifact proxy) | MLflow **≥ 3.6** (OTLP trace ingest) → 3.12 track (AI Gateway, current GenAI eval) | infra compose bump |
| Engines | none | DuckDB delta ext + Polars, read-only over MinIO | wire secrets/endpoints |
| Producers | JSONL + hand-written `manifest.yaml` per sweep dir, committed to git | same files **plus** dual-write to MLflow + bronze | `vvc-evidence` SDK |
| Consumers | prose docs, archived Flask dashboard | gold views (utility score, frontier cross-ref, leaderboards) | none defined |

---

## 3. Concept map: Databricks → OSS reality → how we use it

| Databricks concept | OSS availability | Version gate | VVC use |
|---|---|---|---|
| Experiment / Run | MLflow OSS | any | One experiment per **benchmark family** (§5), one run per cell |
| **LoggedModel** (model-centric hub, `set_active_model`) | MLflow OSS | ≥ 3.0 | One LoggedModel per **GGUF × runtime build × flags × host** — the join key across MLflow and the lake |
| Tracing + Assessments (feedback / expectations) | MLflow OSS | ≥ 3.0; OTLP ingest ≥ 3.6 | Agent-harness traces (Claude Code OTel) once server ≥ 3.6 |
| Evaluation datasets (`mlflow.genai.datasets`) | MLflow OSS, SQL backend only | ≥ 3.4 | Fixture prompts + expected outcomes as a versioned dataset; export to silver table for lineage |
| `mlflow.genai.evaluate` + built-in judges, `make_judge` | MLflow OSS | ≥ 3.4 | **Community/creative lanes only.** The bespoke battery stays deterministic, execution-graded (no LLM judge) |
| Prompt registry | MLflow OSS (SQL backend) | 3.x | Versioned fixture prompts (`prompts:/config-sweep@v3`) |
| Model registry: three-level names, aliases | MLflow SQL registry: aliases+tags ✔ · UC OSS: names ✔, **no aliases/tags/search filters** | uc: URI needs mlflow ≥ 2.16.1 | **Split roles**: MLflow registry is the alias/tag authority (`champion`/`challenger` per slot); UC holds the governed three-level name (§6) |
| Eval dataset as a UC Delta table, lineage tab | Databricks-only | — | We create the lineage ourselves: dataset id + LoggedModel id as columns in silver |
| Deployment jobs / approval tags | Databricks-only | — | Forgejo issue + PR = the approval step |
| Feature Store | Databricks-only | — | not needed |
| Materialized views (gold) | Databricks-only | — | gold = delta-rs tables rebuilt by script, or DuckDB views over silver |
| MCP server (trace tools) | MLflow OSS | client `mlflow[mcp] ≥ 3.5.1` | later; needs server bump |
| AI Gateway | MLflow OSS | ≥ 3.9 | later; could front llama-server for judges |

---

## 4. Evidence data model (medallion)

Databricks' rule per layer, applied to benchmark evidence:

**Bronze — raw, never parsed in flight.** One Delta table per producer record shape, columns as
strings/JSON, append-only, one row per source record, plus provenance columns
(`sweep_dir`, `source_file`, `ingest_ts`, `git_sha`, `schema_version`). Two producer shapes exist
today and both land as-is:

- `bronze.sweep_records` — `phase1.jsonl` / `phase2.jsonl` / toolcall & roster `results.jsonl`
- `bronze.agent_cells` — Track 2A `results.jsonl` (exec grade + ~70 `llamacpp:*` counter deltas)
- `bronze.manifests` — every `manifest.yaml` / `manifest.json` as one JSON row
- `bronze.memory_curves` — `memory.log` rows (ts, avail, sunreclaim, gtt, children)
- `bronze.run_notes` — `CAVEATS.md` / `FINDING-*.md` / `DONE` markers as text rows (validity verdicts are evidence)

**Silver — schema-enforced, deduped, keyed.** Where the two record shapes get a **union
schema** and every row gets the three identity keys (§6): `model_key`, `logged_model_id`,
`host_key`. Trampled/ungraded/contaminated rows are *flagged* (`validity`, `contamination`,
`independence`), never dropped. Silver is where `grade_sweep.py` output lives.

**Gold — read-time views only** (decision already taken in hwbench #11 and the frontier
cross-reference plan): usage-weighted utility score, per-axis leaderboards
(text / tool-call / agentic), Windows-vs-Linux and box-vs-box deltas, community-lane vs
bespoke-lane side-by-side (never merged into one ranking). Weight vectors are versioned rows
in `gold.weight_vectors`, so any composite is reproducible.

**MLflow's role alongside the lake:** the same producer dual-writes. MLflow gets the run
(params from manifest, metrics from records, memory curve as step metrics, transcripts and
diffs as artifacts, linked to a LoggedModel). Delta gets the rows. MLflow is the tracking and
comparison UI; Delta is the analytical truth. Postgres is plumbing.

---

## 5. Experiment and run conventions

| Family | Experiment name | Run = | Parent/child |
|---|---|---|---|
| Text sweeps (phase1/2) | `hwbench/text-sweeps` | one model × rung | sweep dir = parent, rungs = children |
| Tool calling (Track 1) | `hwbench/toolcall` | one model × case set | tier = parent |
| Agent battery (Track 2A) | `hwbench/agent-battery` | one cfg × fixture cell | battery run = parent |
| Serving config (this session) | `hwbench/serving-config` | one serve config × cell (e.g. `cache_ram=32768`) | A/B = parent |
| Parallelism matrix (AI server) | `hwbench/parallelism` | one `(split_mode, n_servers, --parallel)` × cell | matrix = parent |
| Community lane | `hwbench/community-<harness>` | one EvalScope/inspect task run | **separate experiments, never mixed** |

Mandatory tags on every run: `host`, `os`, `runtime_build`, `studio_version`, `model_key`,
`quant`, `isolation`, `lane` (`bespoke` \| `community`), `validity`.

---

## 6. Model identity and registration

Today three uncoordinated identifiers exist (`models-inventory.yaml` name/path, the `gguf`
absolute path in records, the `cfg` string). The registry needs one.

**Canonical `model_key`** = `<family>/<variant>/<params>/<quant>` e.g.
`qwen3-coder/30b-a3b-instruct/30B/UD-Q8_K_XL`, resolved by a manifest row holding
`hf_repo`, `hf_file`, `hf_revision`, `sha256` (from HF LFS metadata, not a 30 GB rehash),
`gguf_metadata` (via the `gguf` package: arch, ctx, quant), `size_gb`, `baseline` flag,
`successor` (retention policy). Source of truth: `models-inventory.yaml`, promoted to a
silver table and to the registry.

**Pointer models, not copies.** A registered model version is a small MLflow model whose
artifacts are the manifest row + the path under `s3://models/` (the canonical GGUF repo)
and `/mnt/ai-models/` on each node. No GGUF bytes flow through the registry.

**Two registries, split roles**, until UC OSS grows aliases/tags:

- **MLflow registry (Postgres)** — authority for aliases per *slot*
  (`coder@champion`, `coder@challenger`, `thinker@champion` …) and tags; benchmark runs link
  to versions via `logged_model_id`.
- **Unity Catalog OSS** — governed name `vvc.evidence.<model_key>` and the volume holding the
  manifest; registration via `mlflow.set_registry_uri("uc:http://192.168.7.241:8080")` is a
  *mirror* step. UC's credential vending against MinIO is unproven (UC #43 open since 2024);
  we bypass vending with static tenant keys and record the outcome on infra #201.

**Evaluation-driven promotion loop** (Databricks' loop, OSS parts):
battery cell(s) → deterministic grade → run + LoggedModel → register version →
`challenger` alias → regression set beats `champion` on the agreed gold view →
alias reassigned in a PR that cites the run ids. Forgejo issue/PR is the approval gate.

---

## 7. Linked OSS projects — the minimal spine

| Project | Role | Integration point | Gotcha |
|---|---|---|---|
| **delta-rs** (`deltalake`) | bronze/silver writer | `write_deltalake(s3://…, storage_options={AWS_ENDPOINT_URL, AWS_ALLOW_HTTP, aws_conditional_put: etag})`, `schema_mode="merge"` | etag conditional put makes MinIO safe for concurrent writers without DynamoDB |
| **DuckDB + delta ext** / **Polars** | gold readers | `CREATE SECRET (TYPE s3, ENDPOINT, URL_STYLE path, USE_SSL false)`, `delta_scan()` | region/url_style must be explicit against MinIO |
| **MLflow ≥ 3.6** | lifecycle | Postgres + MinIO proxy (already), OTLP `/v1/traces` | 3.4 lacks OTLP ingest and MCP-compatible APIs |
| **Unity Catalog OSS ≥ 0.4** | catalog | REST `/api/2.1/unity-catalog`, `bin/uc`, `uc:` registry URI | no aliases/tags; vending ≠ MinIO (#43) |
| **gguf** (llama.cpp `gguf-py`) + `huggingface_hub` | model identity | `GGUFReader` metadata + HF LFS sha256 | stable |
| **inspect_ai + inspect-mlflow** | community-lane harness with native MLflow | OpenAI-compatible endpoint provider | the only harness with first-party MLflow runs+traces; EvalScope (#15) has no MLflow sink — wrap with `log_dict` |
| **OTel Collector** (later) | traces bridge | Prometheus receiver for `llamacpp:*` + OTLP from Claude Code (`CLAUDE_CODE_ENABLE_TELEMETRY=1`, `CLAUDE_CODE_PROPAGATE_TRACEPARENT=1` with a custom base URL) → MLflow | needs MLflow ≥ 3.6; OTEL env not inherited by Bash/MCP subprocesses |

Agentic-battery candidates for the community lane (all run against a local
OpenAI-compatible endpoint): Aider polyglot (225 exercises, cheapest), BFCL v4 (tool calling),
Terminal-Bench 2.0 via Harbor, SWE-bench Lite via mini-swe-agent (Docker, ~120 GB). tau2-bench
needs a user-simulator LLM (cost). These never mix into the bespoke ranking.

---

## 8. Scope decisions (Kal, 2026-09-03)

- **Spark is in scope, near term, for racestream / raceedge.** Those pipelines move toward
  Spark as much as possible; the benchmark-evidence lane keeps delta-rs + DuckDB because it is
  small and batch, but every table it writes must be readable by Spark (Delta on S3, UC as the
  catalog — both already are). Spark Connect + UC's Delta/Iceberg REST endpoints are the
  integration points to plan for; a Spark node placement (MS-01 vs Cincinnati) is an infra decision.
- **Orchestration is a real layer, not a runner.** Forgejo Actions runners execute jobs; they
  do not schedule DAGs, retry with backoff, track lineage, or backfill. **Evaluate Airflow early**
  (the demo stack runs Airflow 3.x for compaction/snapshot expiry): candidates to orchestrate are
  benchmark backfills, nightly battery runs, lake compaction/vacuum, and racestream ingest.
  Decide Airflow vs Temporal vs cron on an explicit spike, before the medallion work grows DAGs by hand.
- **Infra version bumps come before any medallion or table work** (§10 order).
- **No Kafka, no SeaweedFS.** Batch evidence has no streaming need yet; MinIO is the S3 layer.
- **No Iceberg-primary, no UniForm now.** delta-rs does not write UniForm metadata and every
  reader we have speaks Delta. Revisit only if an external consumer needs Iceberg REST; UC
  0.4+ already exposes an Iceberg REST endpoint if that day comes.
- **No LLM judge in the bespoke battery.** Deterministic, execution-graded; judges belong
  to the creative/thinking track and the community lane.
- **No 30 GB model copies through any registry.** Pointer models only; `s3://models` is
  distribution, `/mnt/ai-models` is serving, never the lake.
- **Name collision:** openlakehouse.io lists an "Omnigent" agent-harness project. Our
  `vvt-omnigent` predates our awareness of it; check before any public naming.

---

## 9. Gaps with no owner yet (become issues)

1. Canonical `model_key` + manifest schema; `baseline`/`successor` fields in `models-inventory.yaml`.
2. Silver **union schema** for the two record shapes (`sweep_records` vs `agent_cells`); `manifest.json` from the agent runner is far thinner than `manifest.yaml` and drops hardware/runtime provenance.
3. `manifest.yaml` has no schema/linter; keys drift per sweep.
4. The writer itself (`vvc-evidence`, hwbench #6): dual-write MLflow + bronze, CLI `log-sweep <dir>` for backfill of the ~30 committed sweep dirs with `validity`/`contamination`/`independence` flags.
5. Gold view definitions + weight-vector table (hwbench #11, frontier cross-ref).
6. Community-lane partition (hwbench #15): separate experiments and a `lane` column, EvalScope output shape → bronze.
7. Consumers: a `PERFORMANCE-SUMMARY.md` generator reading gold, replacing hand-maintained numbers.
8. Infra: MLflow 3.4 → ≥ 3.6, UC 0.3 → ≥ 0.4 (compose bumps, infra repo), record UC #43 vending outcome.

---

## 10. Build order (each piece lands behind this doc)

1. **Infra bumps first** (vvt-infrastructure) — MLflow 3.4 → ≥ 3.6 (3.12 line), UC 0.3 → ≥ 0.4;
   record the UC-vending-vs-MinIO outcome on infra #201. Kal's call 2026-09-03: bumps before any
   medallion or table work.
2. **Orchestration spike** (vvt-infrastructure) — Airflow vs Temporal vs cron for backfills,
   nightly batteries, compaction, racestream ingest. Output: a decision + one running DAG.
3. **Spark landing plan** (racestream / raceedge repos + infra) — where Spark runs, Spark Connect
   endpoint, UC as its catalog; the lake's Delta tables stay the shared contract.
4. **Identity + schemas** (hwbench) — `model_key`, manifest schema, silver union schema
   (doc + `scripts/utils/validate_manifest.py`).
5. **`vvc-evidence` writer** (hwbench #6) — `log_sweep.py`: one sweep dir → MLflow parent/child
   runs + LoggedModel + bronze append. Run from WSL/devcontainer against the mesh IPs; box runners
   stay stdlib-only. Backfill the committed dirs.
6. **Live wiring** — post-run hooks in `roster_batch.py` and `agent_task_battery.py`
   (env-gated on `MLFLOW_TRACKING_URI`); first consumers = serving-config A/B, parallelism matrix.
7. **Registry** — pointer-model registration + slot aliases in the MLflow registry; UC mirror.
8. **Gold** — DuckDB (and Spark, for racestream) views: utility score (#11), per-axis
   leaderboards, frontier cross-ref; summary generator.
9. **OTel bridge + MLflow MCP** for Claude Code (needs step 1).
10. **Community lane** — inspect_ai (native MLflow) first, EvalScope second (#15), Aider polyglot
    as the first agentic community benchmark.

---

## 11. Open decisions for Kal

- Confirm **Delta + delta-rs + DuckDB** as the format/engine commitment (vs Iceberg-first like the demo stack).
- Confirm the **split-registry** stance (MLflow aliases, UC names) rather than waiting for UC OSS aliases.
- Confirm the **community lane starts with inspect_ai** (native MLflow) rather than EvalScope, with #15 amended accordingly.
- ~~Whether the MLflow/UC version bumps go into infra now~~ — **decided 2026-09-03: now, before medallion/table work.**
- Orchestrator choice (Airflow / Temporal / cron) and what it orchestrates first.
- Where Spark runs for racestream/raceedge, and whether the benchmark lane ever moves off delta-rs.
