# EvalScope community-lane pilot (hwbench #15)

**Status:** pilot run, 2026-09-06. First live use of EvalScope against a VVC
node. This is the **community lane** — see `docs/reference/EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md`
§5-9 for why it is a separate MLflow experiment family from the bespoke sweeps
under `hwbench/text-sweeps`, `hwbench/toolcall`, etc., and never gets compared
against them directly.

Target: **GLM-4.7-Flash** (`unsloth/GLM-4.7-Flash-GGUF`, `UD-Q8_K_XL`), served
by Unsloth Studio on the Framework Desktop at `http://192.168.4.214:8888/v1`
(build 10687, `unsloth 2026.8.22`), `--parallel 1`.

---

## What ran

| Step | Command shape | Result |
|---|---|---|
| Smoke | `GET /v1/models` | model id **`GLM-4.7-Flash-UD-Q8_K_XL`** — this is the `--model` value for every EvalScope invocation below |
| Eval — GSM8K | `evalscope eval --datasets gsm8k --limit 20 --eval-batch-size 1` | **20/20 = 100% accuracy**, wall 481s (~8 min) |
| Eval — ARC | `evalscope eval --datasets arc --limit 20 --eval-batch-size 1` | **ARC-Easy 20/20 = 100%, ARC-Challenge 19/20 = 95%, OVERALL 39/40 = 97.5%**, wall 422s — `--limit` applies **per subset** (ARC-Easy + ARC-Challenge = 40 samples, not 20) |
| Perf ladder | `evalscope perf --parallel 1 2 --number 4 8 --dataset random --min/max-prompt-length 64/256` | see table below — `--parallel 2` against a server pinned to `--parallel 1` measures **queueing**, not real concurrency headroom |

### Perf ladder numbers

Total test time 74.8s, 1536 tokens generated, avg output rate 20.54 tok/s.

| Conc. | Num | Avg Latency (s) | p50 | p99 | Avg TTFT (ms) | p50 | p99 | Gen tok/s | Success |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 5.705 | 5.36 | 6.26 | 1269.1 | 1077.93 | 1716.72 | 22.43 | 100% |
| 2 | 8 | 12.299 | 12.83 | 14.03 | 7122.1 | 7631.31 | 8590.91 | 19.70 | 100% |

That is the queueing signature the ladder was built to show: dispatching at
client concurrency 2 against a server pinned to `--parallel 1` roughly
**doubles total latency and multiplies avg TTFT by 5.6x** (1269ms → 7122ms),
while per-token decode speed barely moves (28.6 → 24.5 tok/s decode) — the
requests are not computing slower, they are queued behind each other. Full
percentile tables, the HTML report, and raw SQLite are under
`results/community/2026-09-06-evalscope-pilot/perf/20260907_025151/GLM-4.7-Flash-UD-Q8_K_XL/`.

Full eval numbers (per-subset JSON, the HTML report) are under
`results/community/2026-09-06-evalscope-pilot/eval/*/reports/*/*.json`.

### Pitfall: bound `--min/max-prompt-length` on `--dataset random`

The first perf attempt used `--dataset random` with no prompt-length bounds.
EvalScope's `random` dataset then samples input length **uniformly across the
model's entire detected context window** — here `[0, 131068)` tokens — so one
of four requests can draw a near-context-length prompt and spend minutes just
on prefill before generating a single token. That request ran for **over 10
minutes** (vs. 77s for a normal-length sibling) with the server's own
`engine_stats` reporting `gen_tok_s: 0.0, running: 1` the entire time — which
looks identical to a genuine hang and is not distinguishable from one without
independently confirming the server is still healthy (`GET /v1/models`
returned 200 throughout; the request was legitimate work, not a stall). The
run was killed and redone with `--min-prompt-length 64 --max-prompt-length
256`, after which both rungs completed in 74.8s combined. **Always bound
prompt length on `--dataset random` for a perf ladder** — the ladder is
measuring server queueing/throughput behavior, not context-length scaling,
and an unbounded prompt length turns "smallest sensible ladder" into an
open-ended one.

## Reproduce

Docker Desktop on the HP, never native Windows Python:

```bash
KEY=$(ssh -o BatchMode=yes framework "grep -oE 'sk-unsloth-[A-Za-z0-9_-]+' ~/unsloth-serve.log | tail -1")

MSYS_NO_PATHCONV=1 docker run --rm \
  -v "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks:/work" -w /work \
  -e OPENAI_API_KEY="$KEY" python:3.12 bash -c '
    pip install -q "evalscope[perf]"
    evalscope eval \
      --model GLM-4.7-Flash-UD-Q8_K_XL \
      --api-url http://192.168.4.214:8888/v1 \
      --api-key "$OPENAI_API_KEY" \
      --eval-type openai_api \
      --datasets gsm8k \
      --limit 20 --eval-batch-size 1 \
      --work-dir /work/results/community/2026-09-06-evalscope-pilot/eval
  '
```

Perf ladder — same key-handling rule, plus `--tokenizer-path` and bounded
prompt length (see the pitfall below):

```bash
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks:/work" -w /work \
  -e OPENAI_API_KEY="$KEY" python:3.12 bash -c '
    pip install -q "evalscope[perf]"
    evalscope perf \
      --url http://192.168.4.214:8888/v1/chat/completions --api openai \
      --model GLM-4.7-Flash-UD-Q8_K_XL --api-key "$OPENAI_API_KEY" \
      --tokenizer-path zai-org/GLM-4.7-Flash \
      --parallel 1 2 --number 4 8 --dataset random \
      --min-prompt-length 64 --max-prompt-length 256 \
      --min-tokens 64 --max-tokens 128 \
      --outputs-dir /work/results/community/2026-09-06-evalscope-pilot/perf
  '
```

**Key handling rule** (never breakable): retrieve the key over SSH in the same
shell command that uses it, pass it via `-e OPENAI_API_KEY="$KEY"` on the
`docker run` line, reference it inside the container as `$OPENAI_API_KEY`
(single-quoted `bash -c '...'` so the *host* shell never expands it into a
command line that gets logged or echoed). Never print it, never write it to a
file. If a tool ever echoes it back, pipe through
`sed -E 's/sk-unsloth-[A-Za-z0-9_-]+/<redacted>/g'`. EvalScope's own
`configs/task_config.yaml` dump already masks it as `'**********'`, which is
why that file is safe to commit as an artifact.

**Deviations from the literal recipe:**

- `--eval-type service` is not a valid choice on EvalScope 1.11.1 (`llm_ckpt |
  openai_api | openai_responses_api | anthropic_api | litellm | mock_llm |
  text2image | text2speech | image_editing | custom`, or omit it and let it
  auto-infer from `--api-url`). This pilot used `--eval-type openai_api`
  explicitly.
- `evalscope perf --dataset random` refused to run at all without
  `--tokenizer-path` (`AssertionError: Tokenizer path is required for random
  data generation`) — this pilot passed `--tokenizer-path
  zai-org/GLM-4.7-Flash` (downloaded once from HF inside the container; no
  effect on the served model).
- `--min-prompt-length`/`--max-prompt-length` were added beyond the task's
  example flags — see the pitfall above; without them the ladder does not
  reliably finish.

## Dashboard

```bash
docker run --rm -p 7861:7861 \
  -v "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks:/work" -w /work \
  python:3.12 bash -c "pip install -q evalscope && evalscope app --outputs /work/results/community/2026-09-06-evalscope-pilot/eval"
```

Then open `http://localhost:7861`. It reads the `reports/` tree directly — no
separate ingest step — and is the fastest way to eyeball a run's per-subset
breakdown or diff two work-dirs against each other.

## The adapter: `scripts/utils/evalscope_to_records.py`

EvalScope has no MLflow sink of its own (§7 of the reference architecture)
and its report shape (`Report` → `Metric` → `Category` → `Subset`, one JSON
per `<model_id>/<dataset>.json` inside a `<YYYYMMDD_HHMMSS>/` run directory)
does not match the flat `task`/`case`/`score`/`quality` records the bespoke
sweep drivers write. This adapter bridges the two:

```bash
python scripts/utils/evalscope_to_records.py \
  results/community/2026-09-06-evalscope-pilot/eval \
  results/community/2026-09-06-evalscope-pilot/records
```

It walks every timestamped run directory under the given EvalScope work-dir,
reads each `reports/<model_id>/<dataset>.json` plus its sibling
`configs/task_config.yaml`, and writes:

- **`results.jsonl`** — one record per `(dataset, subset)` (aggregate/rollup
  subsets are skipped so they don't double-count), each carrying `task`,
  `case` (`<dataset>/<subset>`), `model`, `tag="evalscope-pilot"`,
  `profile="evalscope"`, `effort="n/a"`, `score`, `n` (sample count), an
  approximate `wall_s` (report JSON mtime minus the run dir's own timestamp —
  EvalScope does not persist a per-dataset wall-clock figure itself), and
  `quality: {graded: true, correct: null, score: <value>}`.
- **`manifest.yaml`** — `datasets`, `limit`, `api`, `eval_type` and
  `evalscope_version` are read back out of EvalScope's own
  `task_config.yaml` (so they can never drift from what actually ran); `node`,
  `backend`, `runtime_build`, `studio_version` and `forgejo_issue` are
  pilot-identity facts EvalScope has no concept of, so they default to this
  run's values and can be overridden with CLI flags for a different pilot.

Then hand the output to the same MLflow shim the bespoke lane uses, in
community mode:

```bash
pip install -q "mlflow>=2.19" pyyaml
python scripts/utils/log_sweep_to_mlflow.py \
  results/community/2026-09-06-evalscope-pilot/records \
  --lane community --records results.jsonl --forgejo-issue 15
```

`--lane community` routes to `hwbench/community-<harness>`, where `<harness>`
is the stem of `--records` (`results.jsonl` → `results`) — so this run lands
in **`hwbench/community-results`**, not `hwbench/text-sweeps` or
`hwbench/toolcall`. Check the printed experiment name after every run; a
community score landing in a bespoke experiment would be exactly the failure
mode §5 of the reference architecture exists to prevent.

This pilot's run: experiment `hwbench/community-results` (id 5), parent run
`2026-09-06-evalscope-pilot` —
<http://192.168.7.241:5000/#/experiments/5/runs/08cf29e41dbf4058b84eb4a3fa50db9a>
— 3 children (gsm8k/main, arc/ARC-Easy, arc/ARC-Challenge), tagged
`lane=community`, `validity=ok`.

## The two-lane rule

Community-lane results (EvalScope, and later inspect_ai / Aider polyglot /
BFCL, per §7-8 of the reference architecture) **never join the bespoke
leaderboard tables**. Different harness, different grading (EvalScope's own
pattern-match/LLM-judge scoring vs the bespoke battery's deterministic,
execution-graded checks), different sample sizes (`--limit 20` here vs full
fixture batteries elsewhere). They live in their own MLflow experiments
(`hwbench/community-*`) and, per §4, would land in their own bronze table —
comparable *within* the community lane, never merged into a cross-lane score.

## Reading the numbers against the model card

`zai-org/GLM-4.7-Flash`'s own README benchmark table does **not** report
GSM8K or ARC — it publishes AIME 25 (91.6), GPQA (75.2), LiveCodeBench v6
(64.0), HLE (14.4), SWE-bench Verified (59.2), τ²-Bench (79.5) and BrowseComp
(42.8), evaluated at the card's own settings (temperature 1.0, top-p 0.95, up
to 131072 new tokens — not this pilot's `temperature=0.0`, `--limit 20`
EvalScope defaults). GSM8K and ARC are both far easier than AIME/GPQA/HLE, so
a 100%-on-20-samples GSM8K score here is directionally consistent with the
card's strong math/reasoning numbers, not independent confirmation of them —
20 samples at `--limit 20` is a pilot smoke test, not a benchmark
reproduction, and every number in this pilot should be read as "the harness
works end to end," not "here is GLM-4.7-Flash's true GSM8K score."
