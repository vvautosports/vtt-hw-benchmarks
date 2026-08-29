"""Metrics exporter bootstrap."""
import argparse

METRICS_PORT = 9302  # default; overridden by --metrics-port


def build_parser():
    parser = argparse.ArgumentParser(description="telemetry exporter")
    parser.add_argument("--metrics-port", type=int, default=METRICS_PORT)
    return parser
