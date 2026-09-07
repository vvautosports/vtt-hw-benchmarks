"""Off-node utilities: deterministic graders and the MLflow intake shim.

Exposed as the installable package `hwbench_intake` (see pyproject.toml
[tool.setuptools.package-dir]) so `log-sweep-to-mlflow` works after
`pip install -e .`. Every module here is still runnable directly by path --
`py scripts/utils/grade_sweep.py ...` is unchanged.
"""
