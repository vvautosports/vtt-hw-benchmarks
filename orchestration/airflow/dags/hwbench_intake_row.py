"""One model in, one graded + logged row out — the hwbench intake row as a DAG.

Runs on the Airflow instance in CT 241 (denver-mlops-01); every step that touches
a model actually executes on the Framework Desktop over SSH. See
../README.md for what this DAG assumes is already installed there.
"""

from __future__ import annotations

import pendulum
from airflow.models.dag import DAG
from airflow.models.param import Param
from airflow.operators.bash import BashOperator
from airflow.providers.ssh.operators.ssh import SSHOperator
from airflow.utils.trigger_rule import TriggerRule

# --------------------------------------------------------------------------- #
# Constants
# --------------------------------------------------------------------------- #

POOL = "framework_gpu"          # size 1 — the Framework's :8888 is single-tenant
SSH_CONN = "framework_ssh"
TRACKING_URI = "http://192.168.7.241:5000"
LANDING = "/opt/airflow/landing"

# mlflow client pinned to the server's major/minor; PyYAML is the shim's only
# other hard dependency (log_sweep_to_mlflow.py declares both as its `mlflow` extra).
MLFLOW_PIP = "'mlflow==3.4.0' 'PyYAML>=6'"

# Airflow run_ids look like `manual__2026-09-06T17:04:11.123456+00:00`. The colon
# is the killer: `rsync host:path` treats it as the host separator, so a raw
# run_id in a path silently breaks the collect step. Slugify once, use everywhere
# — spec filenames, run dirs, and the landing dir all derive from this.
SLUG = "{{ run_id | replace(':', '-') | replace('+', '-') | replace('.', '-') }}"

FOUR_HOURS = 4 * 60 * 60

# --------------------------------------------------------------------------- #
# Task bodies
# --------------------------------------------------------------------------- #

# Poll for the marker the download helper drops when a model finishes fetching.
# exit 99 + skip_on_exit_code=99 marks the task SKIPPED (not succeeded), which is
# why serve_gate below must use trigger_rule=none_failed.
WAIT_DOWNLOAD = r"""
set -euo pipefail
{% if params.skip_download %}
echo "skip_download=true — model is assumed present, not waiting"
exit 99
{% endif %}
marker="$HOME/runs/DL-{{ params.model_name }}.DONE"
echo "waiting for $marker"
{% if params.download_repo %}
echo "provenance: repo={{ params.download_repo }} include={{ params.download_include }}"
if [ ! -f "$marker" ]; then
  echo "if nothing is fetching it yet, this is the command:"
  echo "  hf download {{ params.download_repo }}{% if params.download_include %} --include '{{ params.download_include }}'{% endif %} \
--local-dir /mnt/ai-models/{{ params.download_repo }} && touch \"$marker\""
fi
{% endif %}
deadline=$(( $(date +%s) + 14400 ))
while [ ! -f "$marker" ]; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "timed out after 4h waiting for $marker" >&2
    exit 1
  fi
  sleep 60
done
echo "marker present: $(ls -l "$marker")"
"""

# Hard stop: if anything already holds :8888 this run would kill it out from under
# whoever started it. Never weaken this into a warning.
SERVE_GATE = r"""
set -euo pipefail
if ss -ltnp | grep -q ':8888'; then
  echo "REFUSING TO RUN: something is already listening on :8888 —" >&2
  echo "a manual chain is probably in flight. Nothing was touched." >&2
  ss -ltnp | grep ':8888' >&2
  exit 1
fi
echo ":8888 is clear"
"""

# Spec file paths — one pair per DAG run, so two runs can never clobber each
# other's spec even if someone unpauses concurrency later.
TEXT_SPEC = "$HOME/batch___SLUG___text.json".replace("__SLUG__", SLUG)
TOOL_SPEC = "$HOME/batch___SLUG___tool.json".replace("__SLUG__", SLUG)

# Two one-entry specs in the roster_batch registry shape:
#   text  --disable-tools   (the toolsoff rebaseline convention: no tool schema
#                            in the prompt, so the 3-task battery is comparable
#                            to every other toolsoff run in results/sweeps/)
#   tool  no flags          (server-side tool handling ON — healing and nudging
#                            included; this is NOT the tier-2 "raw" rung, which
#                            also passes --disable-tool-call-{healing,nudging})
# The quoted heredocs are deliberate: Jinja renders the JSON before bash ever
# sees it, so bash must not expand anything further.
WRITE_SPECS = r"""
set -euo pipefail
cat > "__TEXT_SPEC__" <<'EOF'
[
  {
    "name": "{{ params.model_name }}",
    "tag": "{{ params.tag }}",
    "path": "{{ params.gguf_path }}",
    "flags": "--disable-tools",
    "env": {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}
  }
]
EOF
cat > "__TOOL_SPEC__" <<'EOF'
[
  {
    "name": "{{ params.model_name }}",
    "tag": "{{ params.tag }}",
    "path": "{{ params.gguf_path }}",
    "flags": "",
    "env": {"UNSLOTH_DISABLE_UNIFIED_MEMORY": "1"}
  }
]
EOF
# Fail here rather than 40 minutes into a battery on a typo'd param.
for f in "__TEXT_SPEC__" "__TOOL_SPEC__"; do
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f"
  echo "--- $f"; cat "$f"
done
test -f "{{ params.gguf_path }}" || {
  echo "gguf_path does not exist on the Framework: {{ params.gguf_path }}" >&2
  exit 1
}
""".replace("__TEXT_SPEC__", TEXT_SPEC).replace("__TOOL_SPEC__", TOOL_SPEC)

TEXT_BATTERY = (
    "set -euo pipefail\n"
    "python3 ~/roster_batch.py "
    '"' + TEXT_SPEC + '" '
    '"$HOME/runs/' + SLUG + '-text"\n'
)

TOOL_BATTERY = (
    "set -euo pipefail\n"
    "python3 ~/toolcall_battery.py "
    '"' + TOOL_SPEC + '" '
    '"$HOME/runs/' + SLUG + '-tool" '
    "--cases ~/toolcall_cases_tier2.json\n"
)


def grade_cmd(suffix: str) -> str:
    """grade_sweep annotates results.jsonl in place; `cfg` is the axis both
    drivers write (`<name>__<tag>`), so --layout cfg is correct for either."""
    return (
        "set -euo pipefail\n"
        "python3 ~/hwbench-scripts/grade_sweep.py "
        '"$HOME/runs/' + SLUG + "-" + suffix + '" results --layout cfg\n'
    )


def mlflow_cmd(suffix: str) -> str:
    """The shim runs in a throwaway python:3.12 container so the Framework's
    system python is never polluted with an mlflow client. /mnt/ai-models is
    mounted read-only purely so the shim can resolve GGUF sha256/size tags."""
    return (
        "set -euo pipefail\n"
        "podman run --rm \\\n"
        "  -v /mnt/ai-models:/mnt/ai-models:ro \\\n"
        '  -v "$HOME/runs":/runs \\\n'
        '  -v "$HOME/hwbench-scripts":/work \\\n'
        "  python:3.12 \\\n"
        "  bash -lc \"pip install --quiet --no-cache-dir " + MLFLOW_PIP + " && \\\n"
        "    python /work/log_sweep_to_mlflow.py /runs/" + SLUG + "-" + suffix + " \\\n"
        "      --tracking-uri " + TRACKING_URI + " \\\n"
        "      {% if params.forgejo_issue %}--forgejo-issue {{ params.forgejo_issue }}{% endif %}\"\n"
    )


# Runs on the AIRFLOW worker, not the Framework: it PULLS. Pushing would need the
# Framework to hold a key for CT 241 as well, i.e. a second trust direction for no
# gain. `conn.framework_ssh` keeps host/login single-sourced from the connection.
COLLECT = (
    "set -euo pipefail\n"
    'SSH="ssh -i /opt/airflow/ssh/id_ed25519 -o BatchMode=yes '
    '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"\n'
    'DEST="' + LANDING + "/" + SLUG + '"\n'
    'mkdir -p "$DEST"\n'
    "for suffix in text tool; do\n"
    '  rsync -a --delete -e "$SSH" \\\n'
    '    "{{ conn.framework_ssh.login }}@{{ conn.framework_ssh.host }}:runs/'
    + SLUG + '-$suffix/" \\\n'
    '    "$DEST/' + SLUG + '-$suffix/"\n'
    "done\n"
    'find "$DEST" -maxdepth 2 -name results.jsonl -exec wc -l {} +\n'
    'du -sh "$DEST"\n'
)

# --------------------------------------------------------------------------- #
# DAG
# --------------------------------------------------------------------------- #

DOC_MD = """
### hwbench intake row

One model in → a graded text battery, a graded tool-calling battery, both logged
to MLflow, both copied back to the CT. This is the automated version of the
manual chain; it is not a replacement for judgement about *which* models to run.

**Contract with the Framework Desktop (192.168.4.214)**

| Needs | Where |
|---|---|
| `roster_batch.py`, `toolcall_battery.py`, `sweep_phase1/2.py`, `sweep_toolcall.py`, `run_manifest.py`, `toolcall_cases_tier2.json` | `~` |
| `grade_sweep.py`, `log_sweep_to_mlflow.py` | `~/hwbench-scripts/` |
| `podman`, `python3`, `ss`, `rsync` | on `PATH` |
| the GGUF named by `gguf_path` | usually under `/mnt/ai-models/` |

Keeping those files in sync is a **provisioning** concern, not this DAG's — see
`orchestration/airflow/README.md`.

**Parameters**

- `model_name` — the roster name; also names the DL marker (`~/runs/DL-<name>.DONE`)
- `gguf_path` — absolute path on the Framework; existence is checked in `write_specs`
- `tag` — spec tag, default `intake`. `cfg` = `<model_name>__<tag>` everywhere downstream
- `forgejo_issue` — tracking issue; tags the MLflow parent run. `0` = omit the flag
- `download_repo` / `download_include` — provenance only. **This DAG does not
  download anything**; it prints the `hf download` command and waits for the marker
- `skip_download` — skip the wait entirely (model already local)

**Shape**

    wait_download → serve_gate → write_specs → text_battery → tool_battery
                                      ├→ grade_text → mlflow_log_text ─┐
                                      └→ grade_tool → mlflow_log_tool ─┴→ collect

**Why it is safe to run twice**

Both drivers truncate `results.jsonl` and re-create `outputs/` per entry, so a
retried battery overwrites its own partial output rather than appending to it.
Both call `kill_serve()` before each launch, so a retry after a crashed server
recovers on its own. `log_sweep_to_mlflow.py` is idempotent by `record_key` — a
re-log creates nothing new.

**Why it is NOT safe to run alongside a human**

`:8888` is single-tenant and these drivers kill and relaunch it freely.
`serve_gate` refuses to start when the port is busy, but that is a backstop, not
a lock: a manual chain *between* model loads leaves the port momentarily free.
Pause this DAG before working on the Framework by hand.
"""

with DAG(
    dag_id="hwbench_intake_row",
    description="Text + tool-call batteries for one model on the Framework, graded and logged to MLflow",
    doc_md=DOC_MD,
    schedule=None,                  # trigger-only, always with params
    start_date=pendulum.datetime(2026, 9, 1, tz="America/Denver"),
    catchup=False,
    # One intake row at a time. The pool serialises tasks; this serialises runs.
    max_active_runs=1,
    tags=["hwbench", "framework", "mlflow"],
    default_args={
        "owner": "hwbench",
        "retries": 0,
        "depends_on_past": False,
    },
    params={
        "model_name": Param(
            "", type="string", minLength=1,
            title="Model name",
            description="Roster name, e.g. Qwen3.8-Flash-Next. Also names ~/runs/DL-<name>.DONE.",
        ),
        "gguf_path": Param(
            "", type="string", minLength=1,
            title="GGUF path on the Framework",
            description="Absolute path, e.g. /mnt/ai-models/unsloth/<repo>/<file>.gguf",
        ),
        "tag": Param(
            "intake", type="string", minLength=1,
            title="Spec tag",
            description="cfg = <model_name>__<tag>. Keep 'intake' unless re-running a variant.",
        ),
        "forgejo_issue": Param(
            0, type="integer", minimum=0,
            title="Forgejo issue number",
            description="Tags the MLflow parent run. 0 omits the flag.",
        ),
        "download_repo": Param(
            "", type="string",
            title="HF repo (provenance only)",
            description="Recorded in the task log; this DAG never downloads.",
        ),
        "download_include": Param(
            "", type="string",
            title="HF include glob (provenance only)",
        ),
        "skip_download": Param(
            False, type="boolean",
            title="Skip the download wait",
            description="True when the GGUF is already on /mnt/ai-models.",
        ),
    },
) as dag:

    wait_download = SSHOperator(
        task_id="wait_download",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=WAIT_DOWNLOAD,
        # SSHOperator's cmd_timeout defaults to TEN SECONDS. Every task in this
        # DAG must set it explicitly or it dies mid-command.
        cmd_timeout=FOUR_HOURS + 600,
        execution_timeout=pendulum.duration(hours=4, minutes=30),
        skip_on_exit_code=99,
    )

    serve_gate = SSHOperator(
        task_id="serve_gate",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=SERVE_GATE,
        cmd_timeout=60,
        # wait_download SKIPS itself when skip_download is set, and a skipped
        # upstream would cascade-skip this whole DAG under all_success.
        trigger_rule=TriggerRule.NONE_FAILED,
    )

    write_specs = SSHOperator(
        task_id="write_specs",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=WRITE_SPECS,
        cmd_timeout=120,
    )

    text_battery = SSHOperator(
        task_id="text_battery",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=TEXT_BATTERY,
        retries=1,
        retry_delay=pendulum.duration(minutes=10),
        execution_timeout=pendulum.duration(hours=4),
        cmd_timeout=FOUR_HOURS + 900,
    )

    tool_battery = SSHOperator(
        task_id="tool_battery",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=TOOL_BATTERY,
        retries=1,
        retry_delay=pendulum.duration(minutes=10),
        execution_timeout=pendulum.duration(hours=4),
        cmd_timeout=FOUR_HOURS + 900,
    )

    grade_text = SSHOperator(
        task_id="grade_text",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=grade_cmd("text"),
        cmd_timeout=900,
    )

    grade_tool = SSHOperator(
        task_id="grade_tool",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=grade_cmd("tool"),
        cmd_timeout=900,
    )

    mlflow_log_text = SSHOperator(
        task_id="mlflow_log_text",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=mlflow_cmd("text"),
        cmd_timeout=1800,
    )

    mlflow_log_tool = SSHOperator(
        task_id="mlflow_log_tool",
        ssh_conn_id=SSH_CONN,
        pool=POOL,
        command=mlflow_cmd("tool"),
        cmd_timeout=1800,
    )

    collect = BashOperator(
        task_id="collect",
        bash_command=COLLECT,
        pool=POOL,
        execution_timeout=pendulum.duration(hours=1),
    )

    wait_download >> serve_gate >> write_specs >> text_battery >> tool_battery
    tool_battery >> grade_text >> mlflow_log_text
    tool_battery >> grade_tool >> mlflow_log_tool
    [mlflow_log_text, mlflow_log_tool] >> collect
