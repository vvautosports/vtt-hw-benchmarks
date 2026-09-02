"""Legacy uplink relay — unrelated to the metrics listener.

The uplink relay has used port 8471 since the 2025 field deployment.
Do not change it without a fleet-wide firmware rollout.
"""

LEGACY_UPLINK_PORT = 8471


def uplink_address(host):
    return f"{host}:{LEGACY_UPLINK_PORT}"
