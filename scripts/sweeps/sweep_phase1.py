#!/usr/bin/env python3
"""Phase 1 param sweep vs the live unsloth-studio serve (per-request axes only).

Runs 2 sampling profiles x 4 reasoning_effort levels x 3 fixed tasks against
GLM-4.7-Flash-UD-Q8_K_XL on localhost:8888. Writes incremental JSONL results
to ~/sweep-results-phase1.jsonl and full outputs to ~/sweep-out/.
Touches ~/sweep_phase1.done when finished.
"""
import json, os, re, time, urllib.request, urllib.error

HOME = os.path.expanduser("~")
BASE = "http://localhost:8888"
MODEL = "GLM-4.7-Flash-UD-Q8_K_XL"
OUT = os.path.join(HOME, "sweep-results-phase1.jsonl")
OUTDIR = os.path.join(HOME, "sweep-out")
DONE = os.path.join(HOME, "sweep_phase1.done")

# Import-safe: on a box with no baseline serve log (e.g. the G1a driver importing this
# module only for TASKS/PROFILES), KEY stays None; sweep_phase2.wait_loaded() refreshes it
# per serve before any request goes out.
try:
    with open(os.path.join(HOME, "unsloth-serve.log")) as f:
        keys = re.findall(r"sk-unsloth-[A-Za-z0-9_-]+", f.read())
    KEY = keys[-1] if keys else None
except OSError:
    KEY = None

SUMMARY_SOURCE = """
Speculative decoding accelerates autoregressive inference by letting a cheap
draft mechanism propose several tokens which the target model then verifies in
a single batched forward pass. Accepted tokens land at large-model quality but
near draft-model cost; a rejection truncates the proposal and the target model
resumes from the last accepted position, so outputs remain distributionally
identical to standard decoding. The draft can be a separate small model, an
n-gram lookup over the prompt and generation history, or - in newer designs -
a multi-token-prediction (MTP) head trained jointly with the target model that
predicts a short window of future tokens from the same hidden state.

The economics differ sharply by workload. Code and structured text repeat long
spans, so n-gram drafting achieves high acceptance rates almost for free.
Open-ended prose accepts fewer speculative tokens, and a poorly matched draft
model can make generation slower than running the target alone, because every
rejected batch wastes a full verification pass. MTP heads sit in between: they
add a small amount of memory and compute per step, but their acceptance rates
tend to be stable across domains because the head sees the exact context the
target sees.

Mixture-of-experts models complicate the picture. An MoE layer routes each
token to a small subset of experts, so the active parameter count per token is
a fraction of the total - which is why a model with tens of billions of
parameters can decode quickly on integrated GPUs with unified memory. But
speculative verification batches several positions together, and each position
may route to different experts, pulling more expert weights through memory per
step. On bandwidth-bound hardware this erodes the batching advantage that makes
speculation profitable in the first place, so the break-even acceptance rate is
higher for MoE targets than for dense ones.

Server-side parallelism interacts with all of this. Slot-based servers split
the KV-cache budget across concurrent sequences; more slots raise aggregate
throughput while lowering per-stream speed, and speculation competes with
extra slots for the same compute headroom. Tuning therefore has to treat
speculative mode, slot count, and sampling settings as one joint configuration
rather than three independent knobs, and measure end-to-end tokens per second
on representative tasks instead of trusting microbenchmarks.
""".strip()

TASKS = {
    "reasoning": (
        "Three delivery trucks all arrive at a warehouse together at 6:00 AM. "
        "Truck A returns every 12 minutes, truck B every 18 minutes, and truck C "
        "every 30 minutes. Between 6:00 AM and 6:00 PM inclusive, how many times "
        "do all three trucks arrive at the same moment? Show your reasoning, then "
        "state the final count on its own line as 'ANSWER: <n>'."
    ),
    "code": (
        "Write a Python function parse_ranges(s: str) -> list[int] that parses a "
        "string like '1-3,5,7-9' into [1, 2, 3, 5, 7, 8, 9]. Requirements: ignore "
        "whitespace around numbers and commas; a reversed range like '9-7' raises "
        "ValueError; empty or whitespace-only input returns []. Include a doctest "
        "block with at least 5 examples covering all requirements."
    ),
    "summarize": (
        "Summarize the following technical passage as exactly 5 bullet points "
        "followed by a one-sentence TL;DR. Be faithful to the source; do not add "
        "claims it does not make.\n\n---\n" + SUMMARY_SOURCE
    ),
}

PROFILES = {
    "thinking": {"temperature": 1.0, "top_p": 0.95, "top_k": 20},
    "instruct": {"temperature": 0.7, "top_p": 0.80, "presence_penalty": 1.5},
}

EFFORTS = ["xhigh", "medium", "low", "none"]


def run_one(task, prompt, profile_name, profile, effort):
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 8192,
        "seed": 42,
        "reasoning_effort": effort,
    }
    body.update(profile)
    req = urllib.request.Request(
        BASE + "/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + KEY},
    )
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=1200) as resp:
            data = json.loads(resp.read())
        wall = time.monotonic() - t0
    except Exception as e:
        return {"task": task, "profile": profile_name, "effort": effort,
                "error": repr(e)[:300], "wall_s": round(time.monotonic() - t0, 1)}

    usage = data.get("usage", {})
    timings = data.get("timings", {})
    msg = (data.get("choices") or [{}])[0].get("message", {})
    content = msg.get("content") or ""
    reasoning = msg.get("reasoning_content") or ""
    comp = usage.get("completion_tokens")
    rec = {
        "task": task, "profile": profile_name, "effort": effort,
        "wall_s": round(wall, 1),
        "prompt_tokens": usage.get("prompt_tokens"),
        "completion_tokens": comp,
        "tps_wall": round(comp / wall, 2) if comp and wall > 0 else None,
        "tps_server": timings.get("predicted_per_second"),
        "prefill_tps": timings.get("prompt_per_second"),
        "reasoning_chars": len(reasoning),
        "content_chars": len(content),
        "finish_reason": (data.get("choices") or [{}])[0].get("finish_reason"),
    }
    fname = os.path.join(OUTDIR, f"{task}--{profile_name}--{effort}.txt")
    with open(fname, "w") as f:
        if reasoning:
            f.write("=== REASONING ===\n" + reasoning + "\n\n")
        f.write("=== CONTENT ===\n" + content + "\n")
    return rec


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    if os.path.exists(DONE):
        os.remove(DONE)
    n = len(TASKS) * len(PROFILES) * len(EFFORTS)
    i = 0
    with open(OUT, "w") as out:
        for profile_name, profile in PROFILES.items():
            for effort in EFFORTS:
                for task, prompt in TASKS.items():
                    i += 1
                    print(f"[{i}/{n}] {task} / {profile_name} / {effort}", flush=True)
                    rec = run_one(task, prompt, profile_name, profile, effort)
                    out.write(json.dumps(rec) + "\n")
                    out.flush()
                    print("   ->", {k: rec.get(k) for k in
                          ("wall_s", "completion_tokens", "tps_server", "error")
                          if rec.get(k) is not None}, flush=True)
    with open(DONE, "w") as f:
        f.write("done\n")
    print("SWEEP PHASE 1 COMPLETE", flush=True)


if __name__ == "__main__":
    main()
