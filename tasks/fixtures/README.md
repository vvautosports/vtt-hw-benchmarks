# Execution-graded fixture tasks (Track 2A)

Five micro-task repos for the agent battery. Grading is execution-based: pass =
the fixture's `grade.sh` exits 0 after the agent runs. No LLM judges, no
transcript grepping. Design: [TRACK2-HARNESS-BENCHMARKS.md](../../docs/reference/TRACK2-HARNESS-BENCHMARKS.md) § task battery.

| task | exercises | grade |
|---|---|---|
| `fix-failing-test` | debug loop | full pytest suite green |
| `implement-from-doctests` | spec-to-code (Track 1 `parse_ranges` promoted) | doctests + hidden contract tests |
| `refactor-rename` | multi-file coordinated edit | hidden tests: new API, keyword-only, old name gone |
| `config-sweep` | tool-heavy search-and-edit with decoys | hidden tests: all real sites changed, decoys untouched |
| `feature-with-tests` | feature + self-written tests | agent's tests AND hidden acceptance suite green |

## Layout per fixture

```
<task>/
  fixture/        what the agent gets — copied to a scratch git repo per cell
  hidden/         grading assets injected AFTER the agent runs (never visible to it)
  prompt.md       the one-shot prompt, versioned with the fixture
  grade.sh        deterministic grade, cwd = scratch copy, exit 0 = pass
  protected.txt   paths that must come back byte-identical (runner-enforced)
  solution/       reference-solution overlay — self-test only, never shipped to agents
```

## Rules

- The runner (`scripts/agents/agent_task_battery.py`) always copies `fixture/`
  to a scratch dir per cell — agents never run in this tree, and scratch dirs
  are never reused.
- `grade.sh` runs with cwd = the scratch copy and must use `python3 -m pytest`
  (puts the scratch root on sys.path).
- Tasks are deliberately boring and bespoke (freight manifests, SKUs, telemetry
  ports) so they don't collide with training-famous puzzles. Keep it that way
  when adding fixtures.
- Changing a fixture invalidates comparisons with earlier runs — the runner
  snapshots fixtures into each run dir, so old runs stay self-contained, but a
  changed task is a new task: note it in the run manifest.

## Verifying the graders (no inference host needed)

```bash
python3 scripts/testing/test_fixtures.py
```

Checks every fixture both ways: the pristine copy must FAIL its grade, and the
`solution/` overlay must PASS it (and must not violate `protected.txt`). Run it
before spending a matrix on graders that might be wrong — same philosophy as
`test_grade_toolcall.py`.
