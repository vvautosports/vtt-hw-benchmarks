#!/usr/bin/env python3
"""Tool-calling battery execution — owns the canonical cases and run_tool_case().

The Track 1 counterpart to sweep_phase1.py: that module owns TASKS/PROFILES/run_one()
for the 3-task text battery, this one owns the tool-call cases and the multi-turn loop.
Case definitions live in toolcall_cases.json (shared with grade_sweep.py so a harvested
run grades self-contained); this module owns the HTTP mechanics only.

Deployed to $HOME on the inference host alongside sweep_phase1.py / sweep_phase2.py.

What is under test is the CLIENT-TOOL PASSTHROUGH -- `tools:[...]` in the request. That
is a different mechanism from the server-side built-ins (web search, code exec) that
--enable-tools/--disable-tools governs. Server-side tools are pure noise here, so every
request sends enable_tools:false and every serve should also pass --disable-tools.
"""
import json
import os
import re
import time
import urllib.request

HOME = os.path.expanduser("~")
BASE = "http://localhost:8888"
CASES_FILE = os.path.join(HOME, "toolcall_cases.json")

# Written by the driver before each case so transcripts land in the right cfg dir.
OUTDIR = os.path.join(HOME, "toolcall-out")

TOOLCALL_TEXT = re.compile(r"<tool_call>|<\|tool_call\|>|```json\s*\{\s*\"name\"")


def load_cases(path=None):
    with open(path or CASES_FILE, encoding="utf-8") as f:
        return json.load(f)


def _key():
    """Current API key. sweep_phase2.wait_loaded() refreshes sweep_phase1.KEY per serve."""
    import sweep_phase1 as sp1
    return sp1.KEY


def resolve_model(key):
    """Alias of the loaded model. Each serve exposes exactly one."""
    req = urllib.request.Request(BASE + "/v1/models",
                                 headers={"Authorization": "Bearer " + key})
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read())
    entries = data.get("data", [])
    for m in entries:
        if m.get("loaded"):
            return m.get("id")
    return entries[0].get("id") if entries else None


def _post(body, key, timeout=1200):
    req = urllib.request.Request(
        BASE + "/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read())


def _tool_result(case, name, args, depth):
    """Canned tool response. The longchain counter is authoritative: it advances once per
    call regardless of the `n` the model passes, so a model cannot skip ahead to done."""
    if case["kind"] == "longchain":
        target = case["target_depth"]
        if depth >= target:
            return {"n": target, "done": True, "token": case["final_token"]}
        return {"n": depth, "done": False}
    results = case.get("tool_results", {})
    if name in results:
        return results[name]
    return {"error": f"unknown tool {name}"}


def _flatten(tool_calls):
    """Server tool_calls -> [{name, arguments}] with arguments parsed where possible."""
    out = []
    for tc in tool_calls or []:
        fn = tc.get("function", {}) if isinstance(tc, dict) else {}
        raw = fn.get("arguments")
        parsed, ok = raw, True
        if isinstance(raw, str):
            try:
                parsed = json.loads(raw)
            except (ValueError, TypeError):
                parsed, ok = raw, False
        out.append({"name": fn.get("name"), "arguments": parsed,
                    "arguments_raw": raw, "args_parsed": ok})
    return out


def run_tool_case(case_name, case, consts, outdir=None):
    """Run one tool-call case to completion. Returns the result record."""
    outdir = outdir or OUTDIR
    key = _key()
    model = resolve_model(key)

    messages = [{"role": "user", "content": case["prompt"]}]
    max_turns = case.get("max_turns", 1) if case["kind"] != "single" else 1

    turns = 0
    depth = 0                 # successful tool calls made
    all_calls = []
    contents = []
    reasonings = []
    prompt_tokens_first = None
    prompt_tokens_total = 0
    completion_total = 0
    tps_server = prefill_tps = None
    finish_reason = None
    error = None
    raw_text_detected = False

    t0 = time.monotonic()
    try:
        while turns < max_turns:
            body = {
                "model": model,
                "messages": messages,
                "tools": case["tools"],
                "tool_choice": "auto",
                "max_tokens": consts["max_tokens"],
                "seed": consts["seed"],
                "temperature": consts["temperature"],
                "top_p": consts["top_p"],
                "reasoning_effort": consts["reasoning_effort"],
                "enable_tools": consts["enable_tools"],
            }
            data = _post(body, key)
            turns += 1

            choice = (data.get("choices") or [{}])[0]
            msg = choice.get("message", {}) or {}
            finish_reason = choice.get("finish_reason")
            usage = data.get("usage", {}) or {}
            timings = data.get("timings", {}) or {}

            if prompt_tokens_first is None:
                prompt_tokens_first = usage.get("prompt_tokens")
            prompt_tokens_total += usage.get("prompt_tokens") or 0
            completion_total += usage.get("completion_tokens") or 0
            tps_server = timings.get("predicted_per_second") or tps_server
            prefill_tps = timings.get("prompt_per_second") or prefill_tps

            content = msg.get("content") or ""
            reasoning = msg.get("reasoning_content") or ""
            if content:
                contents.append(f"--- turn {turns} ---\n{content}")
            if reasoning:
                reasonings.append(f"--- turn {turns} ---\n{reasoning}")

            calls = _flatten(msg.get("tool_calls"))
            if not calls and TOOLCALL_TEXT.search(content):
                # Model emitted a text-form call that nothing promoted to structured.
                # At the `raw` rung this is exactly the "needs a crutch" signal.
                raw_text_detected = True

            if not calls:
                break

            all_calls.extend(calls)
            messages.append({
                "role": "assistant",
                "content": msg.get("content") or None,
                "tool_calls": msg.get("tool_calls"),
            })
            for tc, flat in zip(msg.get("tool_calls") or [], calls):
                depth += 1
                result = _tool_result(case, flat["name"], flat["arguments"], depth)
                messages.append({
                    "role": "tool",
                    "tool_call_id": tc.get("id"),
                    "name": flat["name"],
                    "content": json.dumps(result),
                })
    except Exception as e:  # noqa: BLE001 - record and move on, one cell must not kill a batch
        error = repr(e)[:300]

    wall = time.monotonic() - t0
    content_all = "\n".join(contents)
    reasoning_all = "\n".join(reasonings)

    rec = {
        "task": case_name,
        "profile": "toolcall",
        "effort": consts["reasoning_effort"],
        "wall_s": round(wall, 1),
        "prompt_tokens": prompt_tokens_first,
        "prompt_tokens_total": prompt_tokens_total,
        "completion_tokens": completion_total,
        "tps_wall": round(completion_total / wall, 2) if completion_total and wall > 0 else None,
        "tps_server": tps_server,
        "prefill_tps": prefill_tps,
        "reasoning_chars": len(reasoning_all),
        "content_chars": len(content_all),
        "finish_reason": finish_reason,
        "turns": turns,
        "n_calls": len(all_calls),
        "chain_depth_reached": depth,
        "raw_toolcall_text_detected": raw_text_detected,
        "args_parse_failures": sum(1 for c in all_calls if not c["args_parsed"]),
    }
    if error:
        rec["error"] = error

    meta = {k: rec[k] for k in ("finish_reason", "turns", "n_calls", "chain_depth_reached",
                                "raw_toolcall_text_detected", "args_parse_failures",
                                "prompt_tokens")}
    meta["case"] = case_name
    if error:
        meta["error"] = error

    os.makedirs(outdir, exist_ok=True)
    fname = os.path.join(outdir, f"{case_name}--toolcall--{consts['reasoning_effort']}.txt")
    with open(fname, "w", encoding="utf-8") as f:
        if reasoning_all:
            f.write("=== REASONING ===\n" + reasoning_all + "\n\n")
        f.write("=== CONTENT ===\n" + content_all + "\n\n")
        f.write("=== TOOLCALLS ===\n" + json.dumps(
            [{"name": c["name"], "arguments": c["arguments"],
              "arguments_raw": c["arguments_raw"], "args_parsed": c["args_parsed"]}
             for c in all_calls], indent=1) + "\n\n")
        f.write("=== META ===\n" + json.dumps(meta, indent=1) + "\n")
    return rec
