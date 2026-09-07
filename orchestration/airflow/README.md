# Airflow orchestration

The DAGs in `dags/` run on the Airflow instance that lives in the MLOps stack on
**CT 241** (`denver-mlops-01`, `192.168.7.241`), UI at
<http://192.168.7.241:8081>. They live *here*, in the hwbench repo, because they
encode hwbench's contract — spec shape, driver CLIs, grading layout — not the
container host's. The infrastructure side (compose services, image, bootstrap,
deploy runbook, rollback) is in **vvt-infrastructure**:
`datacenters/denver/services/mlops/README.md` § "Airflow spike".

| DAG | What it does |
|---|---|
| `framework_ssh_smoke` | Read-only reachability check. Trigger it first; safe any time. |
| `hwbench_intake_row` | One model → text battery + tool battery, graded, logged to MLflow, results copied back to the CT. |

## What the DAGs assume already exists on the Framework

Every task except `collect` is an `SSHOperator` running as `kalman9` on the
Framework Desktop (`192.168.4.214`). The DAGs install nothing. They assume:

| Path | Contents |
|---|---|
| `~/` | `roster_batch.py`, `toolcall_battery.py`, `sweep_phase1.py`, `sweep_phase2.py`, `sweep_toolcall.py`, `run_manifest.py`, `toolcall_cases_tier2.json` |
| `~/hwbench-scripts/` | `grade_sweep.py`, `log_sweep_to_mlflow.py` |
| `~/runs/` | run dirs, plus the `DL-<model>.DONE` markers the download helper drops |
| `/mnt/ai-models/` | the GGUF tree (mounted read-only into the MLflow shim's container) |
| `PATH` | `python3`, `podman`, `ss` (iproute2), `unsloth` |

`~/.ssh/authorized_keys` must contain the ed25519 public key that
`airflow-bootstrap.sh` generates on CT 241 and prints. That is the only manual
step in the whole deploy, and it is manual on purpose.

### Keeping those files in sync is a provisioning problem

Right now the Framework's `~` and `~/hwbench-scripts/` are hand-maintained copies
of `scripts/sweeps/` and `scripts/utils/` from this repo. Nothing enforces that
they match the checkout, and **the DAGs cannot tell**: an SSHOperator running a
six-week-old `roster_batch.py` succeeds and produces subtly wrong rows.

That is an **Ansible-shaped hole**, not something to paper over inside a DAG. A
small play that rsyncs `scripts/sweeps/*.py` → `~` and `scripts/utils/*.py` →
`~/hwbench-scripts/` from a known git ref, then records the ref, would close it
and give every run a provenance tag worth trusting. Until that exists, re-copy by
hand after touching either directory, and treat a surprising result as "check the
driver version first".

## How DAG files reach the CT

`dags/` is bind-mounted into both Airflow containers from
`/opt/mlops/airflow/dags` on CT 241, read-only. It is populated by the MLOps
`deploy.sh`, which takes a `HWBENCH_REPO` environment variable (or a single
positional argument) pointing at the **root of a vtt-hw-benchmarks checkout**:

```bash
# from vvt-infrastructure/datacenters/denver/services/mlops
HWBENCH_REPO=~/Documents/vvc/vtt-hw-benchmarks bash deploy.sh
```

That step tars `$HWBENCH_REPO/orchestration/airflow/dags` into the CT, replacing
the directory wholesale — a DAG deleted here disappears from the scheduler
instead of lingering as a parsed-forever orphan. Omit `HWBENCH_REPO` and the DAG
sync is skipped entirely; the rest of the MLOps deploy is unaffected.

Consequences worth internalising:

- **Never edit a DAG on the CT.** The mount is read-only and the next deploy
  overwrites it. Edit here, commit, re-run `deploy.sh`.
- A DAG change needs no container restart — the scheduler re-parses on its own.
  It does need the deploy, because the file has to physically arrive.
- After deploying, check `airflow dags list-import-errors` (command in the infra
  runbook). Empty output is the pass condition.

## The never-contend rule

**The Framework serves exactly one model on `:8888`, and the batteries kill and
relaunch that server freely.** Triggering `hwbench_intake_row` while a manual
chain is in flight will destroy the manual run's server mid-generation, and the
manual run will not obviously fail — it will produce garbage.

What protects you, and what does not:

| Mechanism | Protects against |
|---|---|
| `pool framework_gpu` (size 1) | Two Airflow **tasks** overlapping |
| `max_active_runs=1` | Two Airflow **runs** overlapping |
| `serve_gate` task | Starting when `:8888` is *currently* busy |
| — nothing — | **A human at a terminal** |

`serve_gate` is a backstop, not a lock. A manual chain between two model loads
leaves the port free for a few seconds and the gate will pass cleanly.

So, before any manual work on the Framework:

```bash
airflow dags pause hwbench_intake_row      # or the UI toggle
```

And before triggering the DAG:

```bash
ssh kalman9@192.168.4.214 "ss -ltnp | grep 8888"   # must print nothing
```

`framework_ssh_smoke` is exempt — it is read-only, holds no pool slot, and is
safe to run at any time.

## Gotchas that cost real time

- **`SSHOperator.cmd_timeout` defaults to 10 seconds.** Every task here sets it
  explicitly. A new task that forgets will die ten seconds in with a confusing
  timeout, not an error from the command.
- **`skip_on_exit_code` needs `apache-airflow-providers-ssh >= 3.1`.** The image
  pins the provider through the Airflow 2.10.5 constraints file, which is far
  newer than that, but a hand-rolled environment may not be.
- **A skipped upstream cascades.** `wait_download` marks itself *skipped* (exit
  99) when `skip_download` is set, so `serve_gate` uses
  `trigger_rule=none_failed`. Without that, setting `skip_download` skips the
  entire DAG and it looks like it "ran fine".
- **`run_id` contains colons.** `manual__2026-09-06T17:04:11+00:00` in a path
  breaks `rsync`, which reads `host:path`. Every run dir, spec file, and landing
  dir derives from the slugified `SLUG` constant at the top of the DAG — use it
  rather than `{{ run_id }}` in any task you add.
- **`collect` pulls, it does not push.** It runs on the Airflow worker and
  rsyncs *from* the Framework into `/opt/mlops/airflow/landing/<slug>/`. Pushing
  would require the Framework to hold a key for CT 241, i.e. a second trust
  direction for no benefit.
- **`--layout cfg` for both batteries.** `cfg` is `<model_name>__<tag>`; it is
  the axis field both drivers write. `--layout model` would mis-group a run that
  has more than one tag for the same model.
