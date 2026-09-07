"""Prove the CT 241 → Framework Desktop SSH hop, and nothing else.

Read-only: it names the host, shows how much room /mnt/ai-models has left, and
counts listeners on :8888. Safe to trigger at any time, including while a manual
chain is running — it starts nothing and kills nothing.

Trigger this first after `airflow-bootstrap.sh` prints its public key and you
install it on the Framework. If this DAG is green, `framework_ssh` works and any
later failure in hwbench_intake_row is about the run, not the plumbing.
"""

from __future__ import annotations

import pendulum
from airflow.models.dag import DAG
from airflow.providers.ssh.operators.ssh import SSHOperator

with DAG(
    dag_id="framework_ssh_smoke",
    description="Read-only SSH reachability check against the Framework Desktop",
    doc_md=__doc__,
    schedule=None,
    start_date=pendulum.datetime(2026, 9, 1, tz="America/Denver"),
    catchup=False,
    max_active_runs=1,
    tags=["hwbench", "framework", "smoke"],
    default_args={"owner": "hwbench", "retries": 0},
) as dag:

    SSHOperator(
        task_id="smoke",
        ssh_conn_id="framework_ssh",
        # Deliberately NOT in the framework_gpu pool: this touches no model and
        # must stay runnable while the pool slot is held by a battery.
        command="hostname; df -h /mnt/ai-models | tail -1; ss -ltn | grep -c 8888 || true",
        # SSHOperator's cmd_timeout default is 10 seconds — always set it.
        cmd_timeout=60,
    )
