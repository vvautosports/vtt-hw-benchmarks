# Sweep harness

The drivers that produce everything under [`results/sweeps/`](../../results/sweeps/).
Committed 2026-08-27 (issue #8, harness-backend item) — before that they lived only on the
Framework box and the runs were not reproducible from the repo alone.

## Deployment model

These run **on the inference host**, not on your workstation. They are `scp`'d to the
box's `$HOME` and executed there, because `sweep_phase2.py` and the batch drivers import
`sweep_phase1` from `$HOME` and read the studio API key out of `~/unsloth-serve.log`.

```bash
scp scripts/sweeps/*.py scripts/sweeps/*.sh framework:/home/kalman9/
scp scripts/sweeps/specs/*.json framework:/home/kalman9/
ssh framework 'sed -i "s/\r$//" ~/*.py ~/*.sh ~/*.json'   # Windows checkouts are CRLF
```

That `sed` matters: `core.autocrlf` is on for Windows clones, so a straight `scp` from a
Windows working tree ships CRLF line endings and Python/bash both choke.

Detached launches over tailscale SSH:

```bash
ssh -n framework 'setsid nohup python3 ~/roster_batch.py ~/spec.json ~/rundir > ~/run.log 2>&1 < /dev/null & disown'
```

## What each one does

| script | role |
|---|---|
| `sweep_phase1.py` | Per-request axes: 2 sampling profiles × 4 `reasoning_effort` levels × 3 tasks. **Owns the canonical `TASKS`, `PROFILES` and `run_one()`** — everything else imports them, which is what makes runs comparable across months. |
| `sweep_phase2.py` | Server axes (`--speculative-type` × `--parallel`). Owns `kill_serve()` / `wait_loaded()` / `refresh_key()`, reused by the batch drivers. |
| `overnight_run.py` | Unattended roster run: downloads a model list, load-tests each, restores the baseline. Zero-session-involvement by design. |
| `roster_batch.py` | **Preferred driver.** Spec-file-driven batch over `{name, path, flags, tag}` entries, one output dir per entry. Use this for new work. |
| `battery.py` | Runs the 3-task battery against whatever is currently serving, and records the runtime build. Used for the llama.cpp-version sweep. |
| `nemotron_retest.py` | One-off root-cause matrix for the Nemotron-3.5 MTP defect. Kept as the worked example of an A/B config matrix. |
| `fetch_roster.sh` | Downloads a model list to `/mnt/ai-models`, logging sizes and free space. Downloads only — deliberately decoupled from testing. |

Grading lives separately at [`../utils/grade_sweep.py`](../utils/grade_sweep.py) — analysis,
not execution. Run it on your workstation against the harvested run directory.

## The trampling rule

`roster_batch.py` gives **every entry its own output directory** (`outputs/<name>__<tag>/`).
This is not cosmetic. Two earlier runs lost quality data because repeat passes over the same
model overwrote each other's transcripts — once on 2026-08-26 (phase 2 writing into phase 1's
paths) and again on the 2026-08-27 roster run, where a pre-reboot and post-reboot pass
collided and left *mixed* provenance. `grade_sweep.py` detects the residue and marks it
`graded=False, reason="transcript_trampled"`, but the data is gone. Any new driver must keep
output paths unique per run *and* per config.

## Environment gotchas these encode

- This llama-server build **ignores SIGTERM** — `kill_serve()` escalates to `SIGKILL`.
- `pgrep -f` / `pkill -f` over tailscale SSH match **themselves**, because tailscaled embeds
  the command string in its own argv. Always bracket: `[l]lama-server`, `[s]tudio update`.
- The studio API key is scraped from `~/unsloth-serve.log`. It never appears in argv and must
  never be echoed.
- `unsloth run` auto-selects context length and speculation per model. Neither is pinned, so
  cross-model comparisons carry an unpinned KV-footprint variable — pin `-c` explicitly when
  that matters.

## Spec files

`specs/*.json` are the exact inputs used for the committed runs, kept so those runs can be
re-executed verbatim. Entry shape:

```json
{"name": "Qwen3.6-35B-A3B-MTP", "tag": "specoff",
 "path": "/mnt/ai-models/unsloth/.../model.gguf",
 "flags": "--speculative-type off"}
```

`flags` is passed through to `unsloth run`. Empty means studio's auto-selection — which is
what a "default" measurement should be.
