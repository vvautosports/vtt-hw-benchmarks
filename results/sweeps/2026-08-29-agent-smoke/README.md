# 2026-08-29 agent smoke — Claude Code x Qwen3-Coder-30B (PARTIAL, 0/3)

First Track 2A smoke: `agent_task_battery.py`, Claude Code via `unsloth start
claude --yolo -p`, Qwen3-Coder-30B-A3B-Instruct UD-Q8_K_XL via studio :8888 on
the Framework. Fixtures pinned at commit `42f2fd3` (run-dir snapshot left on the
box with the scratch dirs).

## Result

| task | passed | wall_s | timeout | edits | ptok Δ | gtok Δ |
|---|---|---|---|---|---|---|
| config-sweep | no | 900 | yes | none (empty diff) | 65272 | 64221 |
| feature-with-tests | no | 900 | yes | none (empty diff) | 55403 | 89622 |
| fix-failing-test | no | 900 | yes | none (empty diff) | 22024 | 29153 |

Run killed by operator after cell 3 (cell 4 `implement-from-doctests` had
started — transcript captured, no graded record). **Verdict: tools never
execute on this path** — continuous generation at ~70-100 t/s, zero file edits,
every cell. A follow-up "create hello.txt" probe also failed (180s, no file).
Root-cause investigation: **issue #12** (studio Anthropic `/v1/messages` proxy
suspected). Do not read these numbers as a Claude Code capability ranking —
the harness path is broken, not the model.

The runner machinery all functioned: server-side `/metrics` token deltas,
process-group timeout kills, protected-path enforcement, per-record flush
(which is why 3 records survived the crash below).

## Incident

Killing the run mid-flight wedged the box (D-state /proc entries → all pattern
kills hung), and a serve relaunch on the wedged state crashed the box off. WOL
stirred it but the heal failed (ping without sshd); physical power cycle
recovered it 2026-08-30. The crashed boot's journal lost its final entries —
no amdgpu evidence survived. Full pattern + lessons:
`docs/runbooks/agentic-crash-recovery.md`; self-heal automation: issue #13.
