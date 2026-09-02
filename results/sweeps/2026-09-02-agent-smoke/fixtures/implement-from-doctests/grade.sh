#!/usr/bin/env bash
# Execution grade for implement-from-doctests: doctests AND the hidden contract tests
# must pass (the hidden tests keep a doctored docstring from grading itself).
# cwd = scratch copy; hidden_tests/ is injected by the runner before grading.
set -u
python3 -m pytest -q --doctest-modules ranges.py hidden_tests/
