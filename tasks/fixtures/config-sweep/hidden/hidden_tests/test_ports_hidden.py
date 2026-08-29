import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

REAL_SITES = [
    "config/collector.yaml",
    "src/exporter.py",
    "src/healthcheck.py",
    "deploy/docker-compose.yaml",
    "docs/runbook.md",
]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_real_sites_updated():
    for rel in REAL_SITES:
        text = read(rel)
        assert "8471" not in text, f"stale port left in {rel}"
        assert "9302" in text, f"new port missing from {rel}"


def test_compose_port_mapping():
    assert '"9302:9302"' in read("deploy/docker-compose.yaml")


def test_decoys_untouched():
    assert "LEGACY_UPLINK_PORT = 8471" in read("src/gateway.py")
    assert read("archive/2025-field-capture.log").count("8471") == 2
    assert read("CHANGELOG.md").count("8471") == 2
