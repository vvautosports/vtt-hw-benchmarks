#!/usr/bin/env bash
# Execution grade for feature-with-tests: the agent's own tests (tests/) AND the
# hidden acceptance suite must pass; the hidden suite also asserts a new test file
# exercising build_sku exists under tests/. cwd = scratch copy; hidden_tests/
# injected by the runner before grading.
set -u
python3 -m pytest -q tests/ hidden_tests/
