#!/usr/bin/env python3
"""Self-test for the receipt graders in scripts/utils/grade_sweep.py.

Synthesises passing and failing extractions for the battery receipts and asserts the
grader's verdict, including the historical failure modes from the banked
2026-08-27-receipt-battery-g1a run (gemma's judgment-call misses, Qwen's empty merchant,
Muse's unparseable/null responses). Needs no inference host and no Pillow -- truth comes
from receipt_battery_gen.RECEIPTS, whose image rendering imports lazily.

Also nails the battery's graded surface to exactly 31 fields, so the 29/31 -> 31/31
history stays comparable if anyone touches the battery definition.

Usage: python3 scripts/testing/test_grade_receipt.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "utils"))
sys.path.insert(0, os.path.join(REPO, "sweeps"))

import grade_sweep as gs  # noqa: E402
import receipt_battery_gen as rb  # noqa: E402

TRUTH = rb.truth_all()


def extraction(task, **overrides):
    """A fully-correct extraction for `task`, with optional field overrides."""
    rec = dict(TRUTH[task])
    rec.update(overrides)
    return json.dumps(rec)


# (task, label, expect_correct, content)
FIXTURES = [
    ("rcpt01_diner", "pass", True, extraction("rcpt01_diner")),
    ("rcpt01_diner", "pass-fenced-json", True,
     "```json\n" + extraction("rcpt01_diner") + "\n```"),
    ("rcpt01_diner", "pass-merchant-fuzzy", True,
     extraction("rcpt01_diner", merchant="The Test Diner, Columbus")),
    ("rcpt01_diner", "fail-wrong-total", False,
     extraction("rcpt01_diner", total=42.71)),
    # Qwen3.8-27B's round-1 mode: empty-string merchant, amounts perfect.
    ("rcpt01_diner", "fail-empty-merchant", False,
     extraction("rcpt01_diner", merchant="")),
    # gemma round-1 miss #1: "taxi" for an Uber receipt.
    ("rcpt02_uber", "fail-category-taxi", False,
     extraction("rcpt02_uber", category="taxi")),
    ("rcpt02_uber", "fail-qualifier-reversed", False,
     extraction("rcpt02_uber", qualifier="office")),
    # Nemotron-Omni's mode: only one night's hotel tax summed.
    ("rcpt03_hotel", "fail-single-night-tax", False,
     extraction("rcpt03_hotel", tax=32.13)),
    ("rcpt04_flight", "pass", True, extraction("rcpt04_flight")),
    # gemma round-1 miss #2: entry date instead of exit date on the parking stub.
    ("rcpt05_parking", "fail-entry-date", False,
     extraction("rcpt05_parking", date="2026-08-20")),
    # Muse-Glimmer's round-1 modes: empty response / schema-violating nulls.
    ("rcpt05_parking", "fail-empty-response", False, ""),
    ("rcpt05_parking", "fail-null-fields", False,
     extraction("rcpt05_parking", merchant=None, total=None, date=None)),
]

# Signals that must be visible in the record beyond the correct flag.
EXTRA = [
    ("rcpt05_parking", "unparseable-is-model-failure", "json_ok", False, "I see a receipt."),
    ("rcpt01_diner", "partial-credit-visible", "fields_ok", 6,
     extraction("rcpt01_diner", category="lunch")),
]


def main():
    failures = []
    for task, label, want, content in FIXTURES:
        q = gs.grade_receipt(task, content, TRUTH)
        got = q.get("correct")
        ok = got is want
        print(f"  {'ok  ' if ok else 'FAIL'} {task:<14} {label:<26} correct={got}")
        if not ok:
            failures.append(f"{task}/{label}: correct={got}, wanted {want} ({q})")

    print("  -- non-gating signals --")
    for task, label, key, want, content in EXTRA:
        q = gs.grade_receipt(task, content, TRUTH)
        got = q.get(key)
        ok = got == want
        print(f"  {'ok  ' if ok else 'FAIL'} {task:<14} {label:<26} {key}={got}")
        if not ok:
            failures.append(f"{task}/{label}: {key}={got}, wanted {want} ({q})")

    # A task with no truth definition must degrade, not crash.
    q = gs.grade_receipt("rcpt01_diner", "{}", None)
    ok = q == {"graded": False, "reason": "no_truth_definition"}
    print(f"  {'ok  ' if ok else 'FAIL'} missing truth definition -> {q}")
    if not ok:
        failures.append(f"missing-truth: {q}")

    # Registration gate: every battery receipt must route to the receipt grader.
    for name in TRUTH:
        reg_ok = name in gs.RECEIPT_TASKS
        print(f"  {'ok  ' if reg_ok else 'FAIL'} {name:<18} registered in RECEIPT_TASKS")
        if not reg_ok:
            failures.append(f"{name}: not in gs.RECEIPT_TASKS")

    # The battery's graded surface is exactly 31 fields (the historical 29/31 -> 31/31 frame).
    surface = sum(gs.grade_receipt(t, extraction(t), TRUTH)["fields_total"] for t in TRUTH)
    ok = surface == 31
    print(f"  {'ok  ' if ok else 'FAIL'} battery graded surface = {surface} (want 31)")
    if not ok:
        failures.append(f"graded surface: {surface} != 31")

    if failures:
        print(f"\n{len(failures)} FAILURE(S):")
        for f in failures:
            print("  " + f)
        return 1
    print(f"\nall {len(FIXTURES) + len(EXTRA) + 2 + len(TRUTH)} grader checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
