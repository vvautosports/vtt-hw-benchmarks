# 2026-09-02 agent smoke — read the cells with these caveats

Claude Code x 5 fixtures x Qwen3-Coder-30B UD-Q8_K_XL, clean serve (fresh boot,
studio b10639, child `--parallel 4`, auto ctx 202752), `--timeout 600`. Runner:
`scripts/agents/agent_task_battery.py` (pre-preflight version — the preflight was
added in response to this run).

## Verdict: 1/5, but only cells 1-2 are valid measurements

| cell | result | validity |
|---|---|---|
| config-sweep | FAIL, 600s timeout, **zero edits** (empty diff), 37k ptok / 30k gtok | **valid** — genuine zero-edit spin on the tool-heavy task |
| feature-with-tests | **PASS**, 600s timeout, 158k ptok / 32k gtok | **valid** — full feature + tests written; killed at cap mid-postamble, work already grading green |
| fix-failing-test | FAIL, 600s timeout, zero edits, metrics None | **poisoned** — llama-server child OOM-killed mid-cell |
| implement-from-doctests | FAIL, 1.9s, agent_exit=1 | **poisoned** — studio proxy wedged post-respawn, instant 500 |
| refactor-rename | FAIL, 600s timeout, metrics None | **poisoned** — same wedged proxy |

## The serving incident (issue #12's real root cause)

At 23:09:01Z (during cell 3) the llama-server child (port 52225) was killed with
**code -9 — the kernel OOM killer**, mid-prompt-processing of a ~19k-token prompt.
Its own log shows normal operation to the last line (25k-token slots, a 2.3 GiB
prompt-cache eviction moments before death). The studio respawned a child (port
34567) but its Anthropic-proxy httpx client wedged permanently:
`RuntimeError: Cannot send a request, as the client has been closed` — every
subsequent `/v1/messages` returned 500. Logs: `serve log lines 269-291`, child
log `llama-1788388530-port-52225-try0.log` (on the box).

This is the same mechanism as the 2026-08-29 run (0/3, then box crash): memory
pressure from sustained agentic contexts kills the child; the wedged proxy turns
every later cell into spin-or-instant-fail.

## Mitigations for the next run

- Pin `-c` (auto-selected 202752 ctx is the memory bomb) and `--parallel 1` on
  battery serves.
- The runner now has a tool-call preflight that aborts on a wedged serve in
  seconds (`--no-preflight` to override) — added after this run.
- Scoring nuance to fix in the runner: `timeout=True` with a passing grade
  (cell 2) means the agent finished the work but not its final output before the
  cap — consider a completion-grace or separate "work-complete" flag.
