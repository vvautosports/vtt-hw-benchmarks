# Telemetry runbook

## Checking the metrics listener

    curl -s http://<node>:8471/metrics | head

If the port does not answer, restart the collector service and check
`config/collector.yaml` for the configured port.
