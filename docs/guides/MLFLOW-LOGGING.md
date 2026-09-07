# MLflow logging — how to get a sweep dir into the lakehouse

`scripts/utils/log_sweep_to_mlflow.py` turns one committed `results/sweeps/<run>/`
directory into an MLflow parent run plus one nested child per JSONL record. It is
**read-only** against `results/` and it never re-grades anything: it reads the
manifest, the records, and the transcripts that are already on disk.

Tracking server: **<http://192.168.7.241:5000>** (MLOps LXC, CT 241 on MS-01).
Resolution order is `--tracking-uri` → `$MLFLOW_TRACKING_URI` → that default.

See `docs/reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md` §5–6 for the experiment
table, the mandatory-tag list, and the model-identity rules this shim implements.

---

## Experiment naming

| Lane | Experiment |
|---|---|
| `--lane bespoke` (default) | `hwbench/<family>` |
| `--lane community` | `hwbench/community-<harness>` |

`<family>` is detected from the manifest's `driver_script`, falling back to the
directory name:

| Signal | Family |
|---|---|
| `toolcall_battery.py`, `sweep_toolcall.py` | `toolcall` |
| `roster_batch.py`, `g1a_validation.py`, `sweep_phase*.py` | `text-sweeps` |
| dirname matches `*cacheram*` or `*-ab` | `serving-config` |
| `manifest.json` carries an `agents` key | `agent-battery` |
| anything else | `misc` (with a warning on stderr) |

`<harness>` comes from `--records` (its stem) or the directory name. The two lanes
are separate experiments **by design** — a community score must never be able to
land in a bespoke leaderboard.

---

## Dry runs on the HP (devcontainer)

Never install dev tooling natively on Windows. Either open the repo in the
devcontainer (`.devcontainer/devcontainer.json`, which runs
`pip install -e ".[mlflow,community]"` for you), or drive the same image directly:

```bash
docker run --rm \
  -v "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks:/work" -w /work \
  mcr.microsoft.com/devcontainers/python:1-3.12-bookworm \
  bash -c "pip install -q -e '.[mlflow]' && \
           log-sweep-to-mlflow results/sweeps/2026-08-28-g1a-validation --dry-run"
```

A dry run prints the experiment, the parent name, one line per child
(`params=`, `metrics=`, `tags=`, `key=`) and the totals. It touches nothing —
no network call, no writes.

Drop `--dry-run` to log for real, and add `--forgejo-issue N` to stamp the parent
with its tracking issue:

```bash
log-sweep-to-mlflow results/sweeps/2026-08-28-g1a-validation --forgejo-issue 6
```

Re-running the same command is a no-op: every child carries a `record_key`
(`sha1(run_id|model|tag|task|profile|effort|case)`), one `search_runs` up front
collects the keys already present, and the existing parent is reused. The second
run reports `children: skipped N, created 0`.

`--with-logs` additionally attaches `*.log` from the run dir (serve logs, memory
logs) to the parent. They are large and rarely wanted, hence opt-in.

---

## Live logging on the Framework (so sha/size resolve)

`gguf_sha256` and `gguf_size_bytes` need the actual model files. They live on the
Framework under `/mnt/ai-models`, so a log run from the HP records
`"unavailable"` for both. Run it **on the node**, in a container that mounts the
model tree read-only:

```bash
podman run --rm \
  -v /mnt/ai-models:/mnt/ai-models:ro \
  -v ~/runs:/runs \
  -v /path/to/vtt-hw-benchmarks:/work -w /work \
  python:3.12 \
  bash -c "pip install -q -e '.[mlflow]' && \
           log-sweep-to-mlflow /runs/<run-id> --models-root /mnt/ai-models"
```

`--models-root` is what the `hf_repo_id` derivation measures paths against: the
segments after it become `<org>/<repo>`, climbing one level when the GGUF's own
parent directory is itself a quant token (so
`.../unsloth/Qwen3.8-Flash-Next-GGUF/UD-Q4_K_XL/x-00001-of-00004.gguf` still
resolves to `unsloth/Qwen3.8-Flash-Next-GGUF`).

`gguf_sha256` is read from the Hugging Face download sidecar
(`<modeldir>/.cache/huggingface/download/<file>.metadata`) — never by rehashing
30 GB of weights.

### Backfilling identity later: `--refresh-tags`

A run already logged from the HP carries `"unavailable"` in the tags that needed
the model files. Nothing degrades silently and nothing has to be re-logged — re-run
the same command **on the node** with `--refresh-tags`:

```bash
log-sweep-to-mlflow /runs/<run-id> --refresh-tags --models-root /mnt/ai-models
```

Children already present are still skipped, but any tag whose stored value is the
literal `"unavailable"` is overwritten when a real value is now knowable. This is
the intended flow for `gguf_sha256`, `gguf_size_bytes`, `hf_repo_id`, `quant`, and
`grader_version`.

> `grader_version` is `git log -1 --format=%h -- scripts/utils/grade_sweep.py`.
> Inside a container that mounts only a git *worktree*, `.git` is a pointer file
> and git cannot resolve it, so the tag degrades. Either refresh it later or hoist
> it in from the host:
> `-e HWBENCH_GRADER_VERSION=$(git log -1 --format=%h -- scripts/utils/grade_sweep.py)`.

---

## What lands where

**Params** — manifest scalars (`run_id`, `date`, `node`, `hardware`, `backend`,
`api`, `isolation`, `axis`, `driver_script`, `rung`, `grading`), flattened
`request_constants.*`, the spec row (`model_name`, `model_path`, `tag`, `flags`,
one `env.<KEY>` each, plus any unknown spec keys), and the record's `task`,
`profile`, `effort`, `cfg`. All stringified, truncated at 500 chars.

**Metrics** — `wall_s`, `load_s`, `prompt_tokens`, `prompt_tokens_total`,
`completion_tokens`, `tps_wall`, `tps_server`, `prefill_tps`, `reasoning_chars`,
`content_chars`, `turns`, `n_calls`, `chain_depth_reached`, `args_parse_failures`.
From `quality`: `correct`, `n_calls`, `chain_depth_reached` stay flat; every other
numeric or boolean quality field is prefixed `q_` (`q_graded`, `q_calls_matched`,
`q_args_ok`, `q_tools_injection_suspect`, …). Booleans become 0/1; `None` is skipped.

**Tags** — the nine mandatory ones (`host`, `os`, `runtime_build`,
`studio_version`, `model_key`, `quant`, `isolation`, `lane`, `validity`) plus
`arch`, `backend`, `ctx`, `cache_ram`, `parallel`, `flags`, `env_json`,
`reasoning_effort`, `seed`, `temperature`, `top_p`, `track`, `tier`,
`finish_reason`, `grading_method`, `grader_version`, `hf_repo_id`, `gguf_file`,
`gguf_sha256`, `gguf_size_bytes`, `hwbench.run_id`, `hwbench.record_key`,
`hwbench.source_path`.

`validity` is computed, never asserted: `load_failed` when `loaded` is false,
`trampled` when the grader flagged `transcript_trampled`, `contaminated` on
`tools_injection_suspect`, `ungraded` when `graded` is false, else `ok`. Bad rows
are **flagged and kept**, never dropped.

**Artifacts** — parent: `manifest.yaml`, `manifest.json`, `manifest.auto.yaml`,
`manifest.notes.yaml`, `spec.json`, the records JSONL, `toolcall_cases*.json`,
`receipt_truth.json` (whichever exist), plus `*.log` under `--with-logs`. Child:
the record's transcript under `outputs/`.

---

## Manifests: hand-authored vs machine-written

`manifest.yaml` is the human narrative — why the run exists, what it proved,
caveats. `scripts/sweeps/run_manifest.py` writes the mechanical half at run time
to **`manifest.auto.yaml`** and never touches `manifest.yaml`. The shim merges
them with the hand-authored file on top:

```text
manifest.auto.yaml  <  manifest.json  <  manifest.yaml  <  the record itself
```

`roster_batch.py` and `toolcall_battery.py` call `write_start()` at the top of
`main()` and `finalize()` in the `finally` after the last flush, so a crashed run
still leaves a manifest. `run_manifest.py` is stdlib-only (the drivers run from
`$HOME` on the node with no venv) and ships to the node via
`bash scripts/sweeps/fetch_roster.sh --ship`.

If `manifest.notes.yaml` exists at finalize time, its raw text is appended under a
`notes:` block scalar — never parsed, so a half-written note cannot break the run.

---

## Hard failures

The shim exits non-zero with a clear message when the run directory has no records
file, e.g. `results/sweeps/2026-09-03-clean-baseline-ab`, whose JSONL lives under a
`run/` subdirectory. Point `--records` at the right file or log the subdirectory
directly. Silence there would be worse than a failure: a run that logs zero
children looks identical to a run that logged fine.
