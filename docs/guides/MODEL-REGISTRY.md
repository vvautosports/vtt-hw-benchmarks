# Model Registry

How the GGUF roster is registered in MLflow, how the `champion-<slot>` /
`challenger-<slot>` aliases are set, and how a registered version joins back to the
sweep runs that justify it.

**Server:** <http://192.168.7.241:5000> (MLflow 3.x, Postgres backend)
**Experiment:** `hwbench/model-registry`
**Script:** `scripts/utils/register_models.py`
**Slot source of truth:** `docs/reference/model-slots.yaml`
**Model source of truth:** `models-inventory.yaml`

---

## What the registry is for

The reference architecture
([EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md](../reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md) §6)
splits the job across two systems:

- **MLflow registry — the alias and tag authority.** `champion-coding`,
  `challenger-thinker` and friends live here. This is what a serving script or an agent
  config should resolve when it asks "which model for this job".
- **Unity Catalog OSS — the governed three-level name** (`vvc.evidence.<name>`), a
  *mirror* step. UC OSS has no aliases and no tags, so it cannot answer the slot
  question; it only records that the name exists under governance.

**Pointer models, not copies.** A registered version's artifact is a small
`model_card.json` holding the manifest row and the on-node path. No GGUF bytes move
through MLflow — a 182 GB model registers in the same time as a 13 GB one.

**One version per `(gguf_file × runtime_build × host)`.** That tuple is the join key the
reference architecture names (it calls it "one LoggedModel per GGUF × runtime build ×
flags × host"). The same GGUF served on a different runtime build, or on the G1a instead
of the Framework, is a different version of the same registered model — not a new model.

---

## How to run it

The script is stdlib + `mlflow` + `pyyaml`. Never run it with Windows-native Python.

### Dry-run from the HP (devcontainer / Docker)

Prints the complete plan — models to create, versions to create or skip, aliases to
set — and touches nothing.

```bash
docker run --rm \
  -v "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks:/work" -w /work \
  mcr.microsoft.com/devcontainers/python:1-3.12-bookworm \
  bash -c "pip -q install 'mlflow>=2.19' pyyaml && \
           python scripts/utils/register_models.py --dry-run"
```

From Git Bash on Windows, prefix the command with `MSYS_NO_PATHCONV=1` or the `-w /work`
argument gets rewritten into a Windows path and Docker rejects it.

Drop `--dry-run` to write to the live server. The run is **idempotent** — a second
invocation reports `versions_created=0 versions_skipped=15` and re-asserts the aliases.

### Full run from the Framework (podman, with the model store mounted)

The HP does not mount `/mnt/ai-models`, so `gguf_sha256` and `gguf_size_bytes` register
as the literal string `unavailable`. Run this from the Framework to fill them in:

```bash
podman run --rm \
  -v /mnt/ai-models:/mnt/ai-models:ro \
  -v "$PWD:/work" -w /work \
  docker.io/library/python:3.12 \
  bash -c "pip -q install 'mlflow>=2.19' pyyaml && \
           python scripts/utils/register_models.py --refresh"
```

`--refresh` updates tags on versions that **already exist** — it only ever replaces
`unavailable`, never a value that is already populated, so it is safe to re-run. The
refreshable tags are `gguf_sha256`, `gguf_size_bytes`, `params_total`, `params_active`,
`params_source`, `context_len`, `license`, `source_results`, `flags`.

The sha256 is read from the Hugging Face download metadata sidecar
(`<dir>/.cache/huggingface/download/<file>.metadata`), exactly as
`log_sweep_to_mlflow.py` does it. It is **never** a rehash — nothing re-reads 180 GB.

### Flags

| Flag | Default | Notes |
|---|---|---|
| `--tracking-uri` | flag → `MLFLOW_TRACKING_URI` → `http://192.168.7.241:5000` | |
| `--inventory` | `models-inventory.yaml` | reads `light_models`, `default_models`, `all_models` |
| `--slots` | `docs/reference/model-slots.yaml` | |
| `--models-root` | `/mnt/ai-models` | prefix for the inventory's `path` field |
| `--runtime-build` | `10687` | part of the version identity |
| `--host` | `kalman9-framework-01` | part of the version identity |
| `--arch` / `--studio-version` | `gfx1151` / `unsloth 2026.8.22` | recorded on the card |
| `--dry-run` | off | print the plan, write nothing |
| `--refresh` | off | fill `unavailable` tags on existing versions |
| `--uc URL` | off | attempt the Unity Catalog mirror |
| `--uc-catalog` / `--uc-schema` | `vvc` / `evidence` | |
| `--no-scan-results` | off | skip the `results/sweeps/*/manifest.yaml` scan |
| `--no-aliases` | off | register only, leave aliases alone |

---

## Naming

### `model_key` — the canonical identity

```
model_key = "<hf_repo_id>#<quant>"
```

`hf_repo_id` is the `hf_repo` field from `models-inventory.yaml`. `quant` is parsed out of
the GGUF filename with the **same regex** `log_sweep_to_mlflow.py` uses, and the case is
taken **verbatim from the filename**. That is deliberate: it is what makes a registered
version join to a sweep run's `quant` tag. It is also why the roster contains both
`ornith-ai/Ornith-1.5-35B-A3B-GGUF#Q8_0` and
`unsloth/Qwen3-8B-128K-GGUF#q8_0` — the two upstream repos capitalise their filenames
differently. Do not "normalise" it.

### Registered model name

MLflow names are the `model_key` with `/` and `#` replaced by `__`:

```
unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF#UD-Q8_K_XL
  -> unsloth__Qwen3-Coder-30B-A3B-Instruct-GGUF__UD-Q8_K_XL
```

The original `model_key` is kept as a tag on both the registered model and every version,
so nothing is lost to the mangling.

### Unity Catalog name

UC OSS additionally rejects periods: *"Name cannot contain a period, space,
forward-slash, or control characters"* (verified against the deployed 0.6.0). The mirror
therefore maps `.` → `_` for the UC leaf name only, and records the MLflow name in the UC
model's `comment` so the two can be joined back:

```
unsloth__Qwen3.8-Flash-Next-GGUF__UD-Q4_K_XL
  -> vvc.evidence.unsloth__Qwen3_8-Flash-Next-GGUF__UD-Q4_K_XL
```

---

## Alias semantics

Aliases are `champion-<slot>` and `challenger-<slot>`, set on the **latest version** of
the named registered model. Slots are `coding`, `reasoning`, `tool-calling`,
`long-context`, `memory-tight`, `thinker`.

```python
from mlflow.tracking import MlflowClient
c = MlflowClient("http://192.168.7.241:5000", "http://192.168.7.241:5000")
mv = c.get_model_version_by_alias(
    "unsloth__Qwen3-Coder-30B-A3B-Instruct-GGUF__UD-Q8_K_XL", "champion-coding")
mv.tags["model_path"]      # what to hand `unsloth run`
mv.tags["runtime_build"]   # which build the claim was measured on
```

Reading these means:

- **champion** — the current best evidence-backed pick for that job. What a serving
  script or agent config should resolve by default.
- **challenger** — the model being raced against the champion. It is not a fallback and
  not a second-best-for-production; it is the next promotion candidate.
- **no alias** — a roster model that is registered (it exists on disk, and the registry
  records what exists) but holds no slot. Controls, demoted models, and models that
  simply lost live here. `model-slots.yaml` lists them under `controls:` and `retired:`
  with the reason.

A slot entry with `model_key: null` is **unregisterable** — the evidence names a winner
that has no row in `models-inventory.yaml`, so there is nothing to alias. The script
prints `[skip ] <alias> -> UNREGISTERABLE <reason>` rather than silently picking someone
else. Two slots are in that state today; see *Known gaps*.

Aliases are re-asserted on every run, so they always match `model-slots.yaml`. Never move
an alias by hand in the MLflow UI — the next run would revert it and the file would no
longer describe the registry.

---

## Promoting a new champion

The evaluation-driven promotion loop from the reference architecture, in the OSS parts we
actually have:

1. Run the battery cell(s) and grade them deterministically.
2. Log the sweep with `scripts/utils/log_sweep_to_mlflow.py` so the run ids exist.
3. If the challenger beats the champion on the agreed view, **edit
   `docs/reference/model-slots.yaml`**: swap `champion`/`challenger`, and update the
   `evidence:` and `runs:` fields to cite the runs that justify the move.
4. Open a Forgejo PR with that edit. The PR *is* the approval gate — the diff shows the
   old and new evidence lines side by side.
5. After merge, re-run `register_models.py`. Aliases move; nothing else changes.

A promotion whose `evidence:` field does not point at a run in `results/sweeps/` is not a
promotion, it is an opinion. The field is mandatory for that reason.

---

## How the registry joins to sweep runs

`log_sweep_to_mlflow.py` tags every benchmark run with the same identity fields this
script writes onto every model version, so the two sides join without a lookup table:

| Field | On the sweep run | On the model version |
|---|---|---|
| `hwbench.run_id` | the `results/sweeps/<dir>` id | — (use `source_results`) |
| `model_key` | `<hf_repo_id>#<quant>` **or the inventory `name`** (see caveat) | always `<hf_repo_id>#<quant>` |
| `hf_repo_id` | derived from the served path | the inventory's `hf_repo` |
| `gguf_file` | GGUF basename | GGUF basename |
| `quant` | `QUANT_RE` on the basename | same regex, same casing |
| `runtime_build` | from the manifest | `--runtime-build` |
| `host` | from the record / manifest `node` | `--host` |

The reliable join is **`gguf_file` + `runtime_build` + `host`** — that is the tuple the
script itself uses for idempotency, and every field in it is derived identically on both
sides.

Two caveats before joining on `model_key` or `hf_repo_id` directly:

- `log_sweep_to_mlflow.model_identity()` prefers the inventory's **`name`** for
  `model_key` when it can match a row, falling back to `repo#quant` only otherwise. The
  registry always uses `repo#quant`. So run-side `model_key` may read
  `Qwen3-Coder-30B-A3B-Instruct` where the registry reads
  `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF#UD-Q8_K_XL`. Versions carry an
  `inventory_name` tag to bridge this; join on that when the run-side value is a bare name.
- The run-side `hf_repo_id` is derived from the **on-disk path**, which is not always the
  HF repo. Qwen3-235B lives under `Qwen/qwen3-235b-a22b/` on disk but comes from
  `unsloth/Qwen3-235B-A22B-Instruct-GGUF`. Versions carry both: `hf_repo_id` (the HF
  repo, from the inventory) and `hf_repo_dir` (the path-derived form).

Each version also carries `source_results` — a comma-separated list of
`results/sweeps/<dir>` whose `manifest.yaml` mentions that model. It is a best-effort
substring scan, useful as a pointer, not as proof; the authoritative citation for a slot
is the `runs:` field in `model-slots.yaml`.

---

## Model card fields

`runs:/<run_id>/model_card/model_card.json`, mirrored one-for-one into the version tags:

`model_key`, `registered_name`, `hf_repo_id`, `hf_repo_dir`, `gguf_file`,
`gguf_relpath`, `model_path`, `quant`, `gguf_sha256`, `gguf_size_bytes`,
`runtime_build`, `studio_version`, `host`, `arch`, `flags`, `params_total`,
`params_active`, `params_source`, `context_len`, `license`, `inventory_name`,
`inventory_sections`, `size_gb`, `parts`, `test_strategy`, `use_case`,
`source_results`, `models_root`, `pointer_only`.

Anything unresolvable from where the script ran is the literal string `unavailable` —
never a guess, never omitted. `params_total` / `params_active` are derived from the model
*name* (`30B-A3B` → `30B` / `3B`) and are marked `params_source: derived-from-name`;
treat them as a convenience, not as authority.

---

## Unity Catalog mirror

```bash
python scripts/utils/register_models.py --uc http://192.168.7.241:8080
```

Status as of 2026-09-06 against the deployed UC OSS: **works**. The
`/api/2.1/unity-catalog/models` endpoints are present and functional, and MLflow's
`uc:http://192.168.7.241:8080` registry URI resolves against it. All 15 roster models
mirror into `vvc.evidence.*`.

The mirror is **names only**. UC OSS has no aliases and no tags, so the slot question can
only be answered by the MLflow registry. Do not point a serving script at UC.

The script does **not** create catalogs or schemas — that is an infra change, not a
registration step. If `--uc-catalog` / `--uc-schema` do not already exist it prints the
exact `CATALOG_NOT_FOUND` response and skips.

---

## Known gaps

- **Two slots have no challenger.** `challenger-long-context` (DeepSeek-V4-Flash-0731)
  and `challenger-thinker` (gpt-oss-120b) are both blocked because those models are on
  the 2026-08-28 leaderboard but have **no row in `models-inventory.yaml`**. The registry
  is built from the inventory, so no `model_key` can be formed without inventing one. For
  gpt-oss-120b, no `hf_repo` id appears anywhere in this repo. Fix: add the rows (confirm
  the real repo ids on the Framework first), re-run, then fill in the `model_key` fields
  in `model-slots.yaml`.
- **`gguf_sha256` / `gguf_size_bytes` are `unavailable`** for every version registered
  from the HP. Clear them with a `--refresh` run from the Framework.
- **`context_len` and `license` are `unavailable` for the whole roster** — the inventory
  has no such fields. They would have to come from GGUF metadata (`gguf-py`'s
  `GGUFReader`) or the HF model card.
- **`model_key` disagrees between this script and `log_sweep_to_mlflow.py`** for models
  the latter can match to an inventory row. See the join caveats above. Worth
  reconciling on one convention.
- **All versions are for one host and one build** (`kalman9-framework-01` / `10687`). The
  G1a is a trustworthy graded node too; registering its versions is a matter of re-running
  with `--host` and `--runtime-build` set for that box.
