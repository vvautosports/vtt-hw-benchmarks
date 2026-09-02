#!/usr/bin/env python3
"""Self-test for the Track 2A fixture graders in tasks/fixtures/.

Every fixture is exercised both ways with no inference host: the pristine copy
must FAIL its grade.sh, and the solution/ overlay must PASS it without touching
any protected.txt path. Reuses the runner's own inject/protect helpers, so those
are proven too. Needs bash + pytest (run under WSL or Linux, not native Windows).

Usage: python3 scripts/testing/test_fixtures.py
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FIXTURES = os.path.join(REPO, "tasks", "fixtures")
sys.path.insert(0, os.path.join(REPO, "scripts", "agents"))

from agent_task_battery import inject_hidden, protected_violations  # noqa: E402

checks = 0
failures = []


def ok(label, cond, detail=""):
    global checks
    checks += 1
    mark = "ok  " if cond else "FAIL"
    print(f"  {mark} {label}" + (f"  [{detail}]" if detail and not cond else ""))
    if not cond:
        failures.append(label)


def grade(fixture_dir, scratch):
    proc = subprocess.run(["bash", os.path.join(fixture_dir, "grade.sh")],
                          cwd=scratch, capture_output=True, text=True, timeout=300)
    return proc.returncode, (proc.stdout + proc.stderr)[-800:]


def overlay(src, dst):
    if os.path.isdir(src):
        shutil.copytree(src, dst, dirs_exist_ok=True)


def main():
    tasks = sorted(
        d for d in os.listdir(FIXTURES)
        if os.path.isdir(os.path.join(FIXTURES, d, "fixture"))
        and os.path.exists(os.path.join(FIXTURES, d, "grade.sh")))
    if len(tasks) != 5:
        print(f"WARNING: expected 5 fixtures, found {len(tasks)}: {tasks}")

    for task in tasks:
        fixture_dir = os.path.join(FIXTURES, task)
        print(f"{task}:")
        ok(f"{task}: prompt.md present",
           os.path.exists(os.path.join(fixture_dir, "prompt.md")))

        with tempfile.TemporaryDirectory() as tmp:
            scratch = os.path.join(tmp, "pristine")
            shutil.copytree(os.path.join(fixture_dir, "fixture"), scratch)
            inject_hidden(fixture_dir, scratch)
            code, tail = grade(fixture_dir, scratch)
            ok(f"{task}: pristine copy fails grade", code != 0, tail)

        with tempfile.TemporaryDirectory() as tmp:
            scratch = os.path.join(tmp, "solved")
            shutil.copytree(os.path.join(fixture_dir, "fixture"), scratch)
            overlay(os.path.join(fixture_dir, "solution"), scratch)
            violations = protected_violations(fixture_dir, scratch)
            ok(f"{task}: solution respects protected.txt", not violations,
               str(violations))
            inject_hidden(fixture_dir, scratch)
            code, tail = grade(fixture_dir, scratch)
            ok(f"{task}: solution passes grade", code == 0, tail)

    print()
    if failures:
        print(f"{len(failures)}/{checks} fixture checks FAILED: {failures}")
        sys.exit(1)
    print(f"all {checks} fixture checks passed")


if __name__ == "__main__":
    main()
