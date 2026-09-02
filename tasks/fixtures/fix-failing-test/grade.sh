#!/usr/bin/env bash
# Execution grade for fix-failing-test: the full suite must pass. cwd = scratch copy.
set -u
python3 -m pytest -q tests/
