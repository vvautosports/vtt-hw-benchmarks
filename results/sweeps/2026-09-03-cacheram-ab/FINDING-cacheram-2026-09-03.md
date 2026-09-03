# FINDING — `LLAMA_ARG_CACHE_RAM=32768` does not restore prefix reuse (2026-09-03)

**Cell:** `config-sweep`, agent `claude`, Qwen3-Coder-30B-A3B UD-Q8_K_XL, framework
(fresh boot, 121 GB avail), `serve_pinned.sh` with `LLAMA_ARG_CACHE_RAM=32768` added.
Evidence in this directory: `child-env.txt` (env reached the llama-server child),
`child-cmdline.txt`, `llama-server.log`, `memory.log`, `results.jsonl`.

## Result — identical to the baseline

| | baseline A/B (08:20) | cache_ram=32768 (15:41) |
|---|---|---|
| passed | no (timeout 600 s) | no (timeout 600 s) |
| prompt tokens / cell | ~147k | 124,420 |
| generated tokens | 926 | 980 |
| wall tok/s | 1.54 | 1.63 |
| SUnreclaim at end | ~30 GB | 35.2 GB |
| avail at end | 5.4 GB | 7.3 GB |

The prompt-cache-size theory is **falsified as the sole cause**.

## What the llama-server log actually shows

Strict alternation of two prompts on the single slot, both fully reprocessed every time:

```
task  36: 24825 tok   task 253: 7284 tok
task 371: 25250 tok   task 472: 7617 tok
task 632: 25469 tok   task 704: 7950 tok
task 857: 25731 tok   task 965: 8230 tok
```

Every `prompt processing` line starts at `progress ≈ 0.16` (chunk 1 of a from-zero pass);
no `prompt_save` / `prompt_load` lines appear. The two streams grow in lockstep (~300 tok/turn)
and differ by ~17.5k tokens, which is roughly the size of Claude Code's 24 tool declarations.
**Hypothesis (unconfirmed): stream B is the same conversation rendered without tools.** Who
sends it is unknown — Claude Code's own side-requests and the studio's internal passes were
both checked below without finding it.

## Isolation probes (same serve, after the cell)

1. **llama-server direct** (`/v1/chat/completions` on the child port), two alternating
   24k-token system prompts A/B/A/B/A: turns 0–1 cost 35–45 s (full), turns 2–4 cost 0.8 s
   with `cache_n = 24105`. → The RAM prompt cache **works** and the env var is honored.
2. **Studio `/v1/messages`**, Claude-shaped 4-turn conversation (20k system + 12 tools,
   growing messages): turn 0 = 30 s, turns 1–3 = 0.3 s (26 new tokens each).
   → The studio's Anthropic→OpenAI path is **prefix-stable**.
3. **Replay of a captured real Claude Code request** 3×: first full, then 1 token.
   → Byte-identical Claude Code requests reuse.
4. **Captured 3 consecutive real Claude Code requests** via a logging proxy
   (`~/logproxy.py`, `~/cc-capture/`): system, tools (24, md5-identical) and message texts are
   identical across turns; the only mutation is the moving `cache_control` marker, which the
   studio converter ignores. All hit `/v1/messages?beta=true`; **no** `count_tokens` calls.
5. Studio token counting uses `/tokenize` + `/apply-template` (no generation);
   `passthrough_healing.py` is response-side only and issues no extra generation.

So none of: cache size, studio conversion, Claude Code history mutation, token counting,
tool-call healing explains stream B. The capture run itself was cut short by the OOM killer
(llama-server exited −9 at 16:00:55, studio respawned it on a new port; gnome-shell was
killed too) because the box was already at 11 GB avail with 35 GB of slab.

## Next test (needs a fresh boot, one cell)

Run the real battery cell with the logging proxy in the agent's env — the runner already
supports per-entry `env`:

```json
{"name": "claude", "tag": "capture",
 "cmd": ["unsloth", "start", "claude", "--yolo", "-p", "{prompt}"],
 "env": {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8899"}}
```

(verify `unsloth start` does not override `ANTHROPIC_BASE_URL`; if it does, launch `claude`
directly with the env `unsloth start claude --no-launch` prints). Then diff every captured
request with `~/diffreq.py` and correlate request timestamps with the llama-server tasks.
That identifies stream B and whichever field breaks the prefix. Also worth one variable each,
after that: `--parallel 2` (two slots, each keeps its own prefix), and
`CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT=1` / `CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536`
(Claude Code warned that the model is unrecognized and it is enforcing a 200k window).

## Operational notes

- Keep `LLAMA_ARG_CACHE_RAM=32768` in `serve_pinned.sh`: harmless, proven to work, and
  necessary once the prefix is stable.
- The slab ratchet (~3 GB/min during a cell) is still the memory bomb; it is tied to the
  full-reprocess pattern, so fixing reuse should fix it.
- Never pattern-kill by cmdline text over SSH: the `case "$c" in *"unsloth run"*)` loop
  matched its own SSH session and killed it (third occurrence). Kill the studio by the PID
  that owns `:8888` and children by `/proc/*/exe` only.
- Issue #12 still states the falsified OOM/context theory; rewrite it from this finding.
