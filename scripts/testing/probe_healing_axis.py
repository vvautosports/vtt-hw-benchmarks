#!/usr/bin/env python3
"""Prove the tool-call healing axis is live, not inert.

Runs ON the inference host. The Track 1 rungs (raw / healed / full) differ only in
--enable/--disable-tool-call-healing and -nudging. Those flags only DO anything when a
model emits a malformed or text-form call, so a roster of well-behaved models produces
identical results at all three rungs -- which is indistinguishable from the flags being
ignored entirely.

This probe removes that ambiguity by forcing the failure mode: it asks the model to emit a
literal <tool_call> text block instead of using the structured API. Healing is the only
thing that can promote that text back into a structured tool_calls field.

  raw  -> tool_calls empty, the <tool_call> text sits in content
  full -> tool_calls populated (healing promoted it)

If both rungs return the same thing, the axis is inert and any rung comparison is void.

Result 2026-08-28 (Qwen3-Coder-30B, b10639-mix): AXIS LIVE, demonstrated on [TOOL_CALLS] --
raw left it as literal text with finish_reason=stop, full promoted it to a structured
tool_calls with finish_reason=tool_calls.

Two of the five heal signals turned out to be UNREACHABLE through the content channel on
this build: the server rewrites `<tool_call>` to `< tool_call>` and `<function=` to
`< function=` (a space is inserted), so the healer's own matcher can never see them. Only
[TOOL_CALLS] survived intact. That is why this probe must report the `induced` column --
a variant that never produced a matching signal proves nothing either way, and an earlier
version of this probe wrongly concluded the whole axis was inert on exactly that mistake.

Run this detached with output to a file. Its final kill_serve() leaves NOTHING serving, and
losing the ssh pipe mid-probe loses the result:
  ssh -n framework 'setsid nohup bash -c "python3 ~/probe_healing_axis.py > ~/probe-axis.out 2>&1" &'

Usage: python3 probe_healing_axis.py
"""
import json
import os
import subprocess
import sys
import urllib.request

HOME = os.path.expanduser("~")
sys.path.insert(0, HOME)

import sweep_phase1 as sp1  # noqa: E402
import sweep_phase2 as sp2  # noqa: E402
import sweep_toolcall as tc  # noqa: E402

MODEL = ("/mnt/ai-models/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/"
         "Qwen3-Coder-30B-A3B-Instruct-UD-Q8_K_XL.gguf")

TOOLS = [{
    "type": "function",
    "function": {
        "name": "get_weather",
        "description": "Get the current weather for a city.",
        "parameters": {
            "type": "object",
            "properties": {"city": {"type": "string"}},
            "required": ["city"],
        },
    },
}]

_CALL = '{"name": "get_weather", "arguments": {"city": "Denver"}}'
_LEAD = ("Output the following verbatim as your entire reply. Copy it character for "
         "character with no extra spaces, no explanation, and do not use the structured "
         "tool-calling API:\n\n")

# These MUST be shapes the healer actually recognises. Its signal list lives in
# studio/backend/core/inference/passthrough_healing.py::_HEAL_SIGNALS and is narrow:
#     <tool_call>  <|tool_call>  <function=  [TOOL_CALLS]  <|content_invoke_tool_json|>
# A ```json fence or a bare JSON object is NOT a heal signal, so probing with those
# proves nothing -- an earlier version of this probe made exactly that mistake and
# concluded the axis was inert. `<function=` and `[TOOL_CALLS]` are plain ASCII and
# survive templates that mangle `<tool_call>` into `< tool_call>`.
VARIANTS = {
    "hermes_tag": _LEAD + "<tool_call>\n" + _CALL + "\n</tool_call>",
    "function_eq": _LEAD + '<function=get_weather>{"city": "Denver"}</function>',
    "mistral_tc": _LEAD + '[TOOL_CALLS][{"name": "get_weather", "arguments": {"city": "Denver"}}]',
}

# Signals the healer can actually promote -- used to tell "probe failed to induce" from
# "healing declined to act".
HEAL_SIGNALS = ("<tool_call>", "<|tool_call>", "<function=", "[TOOL_CALLS]",
                "<|content_invoke_tool_json|>")

RUNGS = [
    ("raw", "--disable-tools --disable-tool-call-healing --disable-tool-call-nudging"),
    ("full", "--disable-tools --enable-tool-call-healing --enable-tool-call-nudging"),
]


def launch(flags, logfile):
    cmd = (f"setsid nohup env UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run --model {MODEL} "
           f"-H 0.0.0.0 -p 8888 {flags} > {logfile} 2>&1 < /dev/null &")
    subprocess.Popen(["bash", "-c", cmd])


def main():
    seen = {}
    for tag, flags in RUNGS:
        logfile = os.path.join(HOME, f"probe-{tag}.log")
        sp2.kill_serve()
        launch(flags, logfile)
        if not sp2.wait_loaded(logfile, timeout=900):
            print(f"{tag}: LOAD FAILED")
            continue
        key = sp1.KEY
        model = tc.resolve_model(key)
        print(f"--- {tag} ---")
        seen[tag] = {}
        for vname, prompt in VARIANTS.items():
            body = {
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "tools": TOOLS,
                "tool_choice": "auto",
                "max_tokens": 256,
                "seed": 42,
                "temperature": 0.0,
                "top_p": 1.0,
                "enable_tools": False,
            }
            req = urllib.request.Request(
                "http://localhost:8888/v1/chat/completions",
                data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json",
                         "Authorization": "Bearer " + key},
            )
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.loads(resp.read())
            choice = (data.get("choices") or [{}])[0]
            msg = choice.get("message", {}) or {}
            calls = msg.get("tool_calls")
            content = msg.get("content") or ""
            # Did the model emit a shape the healer can actually see? If it mangled the tag
            # (e.g. "< tool_call>"), no healer would match it and the variant proves nothing.
            induced = any(s in content for s in HEAL_SIGNALS)
            seen[tag][vname] = bool(calls)
            print(f"  {vname:<12} calls={'YES' if calls else 'no ':<3} "
                  f"induced={'yes' if induced else 'NO '} "
                  f"finish={choice.get('finish_reason')}")
            print(f"               content={content[:120]!r}")

    sp2.kill_serve()
    if len(seen) != 2:
        print("\nINCONCLUSIVE: a rung failed to load.")
        return 2
    diffs = [v for v in VARIANTS if seen["raw"].get(v) != seen["full"].get(v)]
    if diffs:
        print(f"\nAXIS LIVE: healing changed the outcome on {diffs}.")
        return 0
    print("\nAXIS NOT DEMONSTRATED: no variant separated raw from full.")
    print("That is NOT proof the flags are inert -- it can equally mean the model never")
    print("emitted a shape healing recognises. Check the `induced` column: if every")
    print("variant shows induced=NO, the probe failed to set up the test at all.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
