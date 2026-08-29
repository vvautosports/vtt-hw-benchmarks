#!/usr/bin/env bash
# Execution grade for config-sweep: hidden tests assert every real metrics-port site
# now reads 9302 with no 8471 residue, and every decoy still reads 8471. The runner
# additionally enforces protected.txt (decoys byte-identical) before this runs.
# cwd = scratch copy; hidden_tests/ injected by the runner before grading.
set -u
python3 -m pytest -q hidden_tests/
