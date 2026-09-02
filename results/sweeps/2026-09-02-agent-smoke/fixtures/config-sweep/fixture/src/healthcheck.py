"""Liveness probe for the metrics listener."""
import urllib.request

METRICS_URL = "http://127.0.0.1:8471/metrics"


def probe(timeout_s=2.0):
    with urllib.request.urlopen(METRICS_URL, timeout=timeout_s) as response:
        return response.status == 200
