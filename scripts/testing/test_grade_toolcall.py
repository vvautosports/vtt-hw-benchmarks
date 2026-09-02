#!/usr/bin/env python3
"""Self-test for the toolcall graders in scripts/utils/grade_sweep.py.

Synthesises a passing and a failing transcript for each of the five Tier 1 cases and
asserts the grader's verdict. Runs in about a second and needs no inference host -- the
point is to prove the graders before spending 90 model loads on a matrix they would
misgrade.

Usage: python3 scripts/testing/test_grade_toolcall.py
"""
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(REPO, "utils"))

import grade_sweep as gs  # noqa: E402

CASES = json.load(open(os.path.join(REPO, "sweeps", "toolcall_cases.json"),
                       encoding="utf-8"))["cases"]
# Tier 2 lives in its own file (keeps the saturated Tier 1 baseline reproducible). Merge it
# so one run of this self-test covers both batteries against the same grader.
TIER2 = json.load(open(os.path.join(REPO, "sweeps", "toolcall_cases_tier2.json"),
                       encoding="utf-8"))["cases"]
CASES = {**CASES, **TIER2}


def write(tmp, name, content, calls, meta):
    path = os.path.join(tmp, f"{name}.txt")
    with open(path, "w", encoding="utf-8") as f:
        f.write("=== CONTENT ===\n" + content + "\n\n")
        f.write("=== TOOLCALLS ===\n" + json.dumps(calls, indent=1) + "\n\n")
        f.write("=== META ===\n" + json.dumps(meta, indent=1) + "\n")
    return path


def call(name, args, parsed=True):
    return {"name": name, "arguments": args,
            "arguments_raw": json.dumps(args), "args_parsed": parsed}


def meta(**kw):
    base = {"finish_reason": "tool_calls", "turns": 1, "n_calls": 0,
            "chain_depth_reached": 0, "raw_toolcall_text_detected": False,
            "args_parse_failures": 0, "prompt_tokens": 189}
    base.update(kw)
    return base


# (case, label, expect_correct, content, calls, meta)
FIXTURES = [
    ("tc_single", "pass", True, "", [call("get_weather", {"city": "Denver"})],
     meta(n_calls=1)),
    ("tc_single", "fail-wrong-tool", False, "", [call("send_email", {"to": "x"})],
     meta(n_calls=1)),

    ("tc_distractor", "pass", True, "",
     [call("convert_currency", {"amount": 250, "from_currency": "USD", "to_currency": "EUR"})],
     meta(n_calls=1)),
    ("tc_distractor", "fail-distractor-chosen", False, "",
     [call("get_weather", {"city": "Paris"})], meta(n_calls=1)),

    ("tc_refusal", "pass", True, "The capital of France is Paris.", [],
     meta(finish_reason="stop", n_calls=0)),
    ("tc_refusal", "fail-hallucinated-call", False, "",
     [call("get_weather", {"city": "Paris"})], meta(n_calls=1)),

    ("tc_chain", "pass", True, "--- turn 2 ---\nRESULT: 9462",
     [call("get_inventory_count", {"sku": "AX-19"})],
     meta(finish_reason="stop", turns=2, n_calls=1, chain_depth_reached=1)),
    ("tc_chain", "fail-guessed-value", False, "--- turn 2 ---\nRESULT: 8000",
     [call("get_inventory_count", {"sku": "AX-19"})],
     meta(finish_reason="stop", turns=2, n_calls=1, chain_depth_reached=1)),

    ("tc_longchain", "pass", True, "TOKEN: ZEPHYR-7731",
     [call("step", {"n": i}) for i in range(20)],
     meta(finish_reason="stop", turns=21, n_calls=20, chain_depth_reached=20)),
    ("tc_longchain", "fail-premature-eos", False, "",
     [call("step", {"n": i}) for i in range(9)],
     meta(finish_reason="stop", turns=10, n_calls=9, chain_depth_reached=9)),

    # --- Tier 2 ---
    ("tc_parallel", "pass", True, "",
     [call("get_weather", {"city": "Denver"}), call("get_weather", {"city": "Boston"}),
      call("get_weather", {"city": "Seattle"})], meta(n_calls=3)),
    ("tc_parallel", "fail-only-two", False, "",
     [call("get_weather", {"city": "Denver"}), call("get_weather", {"city": "Boston"})],
     meta(n_calls=2)),
    ("tc_parallel", "fail-dup-city", False, "",
     [call("get_weather", {"city": "Denver"}), call("get_weather", {"city": "Denver"}),
      call("get_weather", {"city": "Seattle"})], meta(n_calls=3)),

    ("tc_nested", "pass", True, "",
     [call("create_order", {"customer": {"name": "Ada Lovelace", "tier": "gold"},
                            "items": [{"sku": "AX-19", "qty": 2}, {"sku": "BX-7", "qty": 5}],
                            "rush": True})], meta(n_calls=1)),
    ("tc_nested", "fail-missing-item", False, "",
     [call("create_order", {"customer": {"name": "Ada Lovelace", "tier": "gold"},
                            "items": [{"sku": "AX-19", "qty": 2}], "rush": True})],
     meta(n_calls=1)),

    ("tc_union", "pass", True, "",
     [call("set_reminder", {"note": "x", "when": {"date": "2026-09-01", "time": "14:30"}})],
     meta(n_calls=1)),
    ("tc_union", "fail-enum-branch", False, "",
     [call("set_reminder", {"note": "x", "when": "afternoon"})], meta(n_calls=1)),

    ("tc_distractor_p1", "pass", True, "",
     [call("convert_currency", {"amount": 250, "from_currency": "USD", "to_currency": "EUR"})],
     meta(n_calls=1)),
    ("tc_distractor_p3", "pass", True, "",
     [call("convert_currency", {"amount": 250, "from_currency": "USD", "to_currency": "EUR"})],
     meta(n_calls=1)),

    ("tc_ambiguous", "pass", True, "",
     [call("get_flight_status", {"flight_no": "UA448"})], meta(n_calls=1)),
    ("tc_ambiguous", "fail-route-search", False, "",
     [call("search_flights", {"origin": "DEN", "destination": "SFO"})], meta(n_calls=1)),

    ("tc_coercion", "pass", True, "",
     [call("convert_currency", {"amount": 1500, "from_currency": "USD", "to_currency": "EUR"})],
     meta(n_calls=1)),
    ("tc_coercion", "fail-word-string", False, "",
     [call("convert_currency", {"amount": "fifteen hundred", "from_currency": "USD",
                                "to_currency": "EUR"})], meta(n_calls=1)),
]

# Behaviours that must be visible in the record even though they do not flip `correct`.
EXTRA = [
    ("tc_single", "injection-flagged", "tools_injection_suspect", True,
     "", [call("get_weather", {"city": "Denver"})], meta(n_calls=1, prompt_tokens=4200)),
    ("tc_single", "args-unparseable", "correct", False,
     "", [call("get_weather", "{city: Denver", parsed=False)],
     meta(n_calls=1, args_parse_failures=1)),
    ("tc_longchain", "survived-but-no-token", "completed", False,
     "", [call("step", {"n": i}) for i in range(16)],
     meta(finish_reason="stop", turns=17, n_calls=16, chain_depth_reached=16)),
    # Order-insensitive multi-call matching: two of three cities matched, so calls_matched=2
    # even though n_calls=3 -- the partial credit is visible without flipping correct.
    ("tc_parallel", "partial-two-of-three", "calls_matched", 2,
     "", [call("get_weather", {"city": "Denver"}), call("get_weather", {"city": "Denver"}),
          call("get_weather", {"city": "Seattle"})], meta(n_calls=3)),
]


def main():
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        for case, label, want, content, calls, m in FIXTURES:
            path = write(tmp, f"{case}--{label}", content, calls, m)
            q = gs.grade_toolcall(case, path, CASES)
            got = q.get("correct")
            ok = got is want
            print(f"  {'ok  ' if ok else 'FAIL'} {case:<14} {label:<24} correct={got}")
            if not ok:
                failures.append(f"{case}/{label}: correct={got}, wanted {want} ({q})")

        print("  -- non-gating signals --")
        for case, label, key, want, content, calls, m in EXTRA:
            path = write(tmp, f"{case}--{label}", content, calls, m)
            q = gs.grade_toolcall(case, path, CASES)
            got = q.get(key)
            ok = got is want
            print(f"  {'ok  ' if ok else 'FAIL'} {case:<14} {label:<24} {key}={got}")
            if not ok:
                failures.append(f"{case}/{label}: {key}={got}, wanted {want} ({q})")

        # A case with no definition must degrade, not crash.
        path = write(tmp, "orphan", "", [], meta())
        q = gs.grade_toolcall("tc_single", path, None)
        ok = q == {"graded": False, "reason": "no_case_definition"}
        print(f"  {'ok  ' if ok else 'FAIL'} missing case definition -> {q}")
        if not ok:
            failures.append(f"missing-definition: {q}")

        # Registration gate: every case in either battery must route to the toolcall grader.
        # grade_toolcall is exercised directly above, so an unregistered name would still
        # "pass" the fixtures while silently grading as graded:False in a real run.
        for name in CASES:
            reg_ok = name in gs.TOOLCALL_TASKS
            print(f"  {'ok  ' if reg_ok else 'FAIL'} {name:<18} registered in TOOLCALL_TASKS")
            if not reg_ok:
                failures.append(f"{name}: not in gs.TOOLCALL_TASKS")

    if failures:
        print(f"\n{len(failures)} FAILURE(S):")
        for f in failures:
            print("  " + f)
        return 1
    print(f"\nall {len(FIXTURES) + len(EXTRA) + 1} grader checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
