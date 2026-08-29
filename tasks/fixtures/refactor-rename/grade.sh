#!/usr/bin/env bash
# Execution grade for refactor-rename: hidden tests assert the new API works, the
# keyword-only signature, old-name absence from every source file, and that all
# call sites still compute correctly. cwd = scratch copy; hidden_tests/ injected
# by the runner before grading.
set -u
python3 -m pytest -q hidden_tests/
