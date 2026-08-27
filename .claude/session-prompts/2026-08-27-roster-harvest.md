# Session Continuation Prompt — Roster Harvest (2026-08-27)

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread

Spawn ONE Explore subagent (cheap tier — sonnet/haiku, NEVER fable) to run the
Startup block below and return a digest. ONLY that digest enters main context.
Switch tiers only when implementation starts.

## Where the last session ended (2026-08-26)

- PR #9 open (CI green, evidence posted, commit `038d903`) — awaiting Kal's
  review/merge. Issues: #8 (2 boxes ticked), #10 (roster queue), #11 (weighted
  score design). vvt-knowledge PR 52 UNMERGED — classifier-blocked; Kal merges
  manually at git.vvautosports.com/vvc/vvt-knowledge/pulls/52.
- GLM-4.7-Flash sweep done: winner thinking/low; spec=auto np=4 confirmed;
  canonical data `results/sweeps/2026-08-26-glm47-flash-param-sweep/`.
- Framework rebooted for the 120GB GTT unlock, then `~/overnight_run.py`
  launched detached: downloads the #10 queue (5 models, ~226G) and load-tests
  each (thinking/low battery), restores the GLM baseline serve at the end.
  Zero Claude involvement overnight by design — do NOT re-run it, just harvest.
- Discord thread for this feature: 1542400459300536440 (reply, don't create).

## Startup block (subagent, read-only, absolute paths)

1. Worktree state: `git -C C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction status` + last 3 log lines.
2. `ssh framework 'ls ~/overnight-2026-08-26/DONE 2>/dev/null; tail -25 ~/overnight-2026-08-26/log.txt; wc -l ~/overnight-2026-08-26/results.jsonl'`
3. `ssh framework 'grep -o "gttsize=[0-9]*" /proc/cmdline; df -h /mnt/ai-models | tail -1'`
4. GLM serve health: `ssh framework 'KEY=$(grep -oE "sk-unsloth-[A-Za-z0-9_-]+" ~/unsloth-serve.log | tail -1); curl -s -m 10 -H "Authorization: Bearer $KEY" http://localhost:8888/v1/models | head -c 300'`
5. `gh pr view 9 --json state,mergedAt -q .` and open-issue check on #8/#10.
6. Read `docs/reference/UNSLOTH-DIRECTION.md` sections "Param-tuning sweep" and "Metrics model" only.

## Overnight outcome (already known — do not re-derive)

Run completed 04:53, 26 records (run1 pre-reboot 62GB GTT, run2 post-reboot
128GB — records 0-12 vs 13-25; dedupe keeping BOTH, tagged by run). Loaded:
Qwen3.8-27B UD-Q8 (30G, ~13.4 t/s — no qwen4exp blocker on 27B!),
gemma-4-26B-A4B UD-Q8 (26G, ~36 t/s, stable both runs — beats GLM ~+12%),
Nemotron-3.5-Lightning UD-Q8 (36G — **41/52/45 t/s pre-reboot, then HTTP 500s
post-reboot**; likely transient compiled-cache rebuild — RETEST FIRST, title
challenger if run1 holds), gemma-4-31B UD-Q8 (33G, ~5.6 t/s dense control).
MiniMax-M3 UD-Q3 is 182G — exceeds even 128GB GTT, failed both runs cleanly;
Kal decides delete (reclaim 182G; disk at 81%) vs RPC-pool experiment.
Qwen3.8-27B MTP sidecar untested. Quality ungraded — grade content-channel
before any champion talk (gemma-31B's terse outputs especially).

## This session's scope

1. **Harvest**: pull `~/overnight-2026-08-26/{results.jsonl,log.txt,outputs/}`
   into `results/sweeps/2026-08-27-roster-validation/` (manifest.yaml in the
   2026-08-26 run's schema; note GTT state). Grade with the grade_sweep.py
   pattern (scratchpad copy died with the old session — recreate from the doc's
   Metrics model section; content-channel grading).
2. **Inventory**: add validated models to models-inventory.yaml; loaded=False
   models get DRIFT/blocked notes. Retention swaps (delete Nemotron-Nano-30B,
   MiniMax-M2.5) ONLY after Kal confirms per retention policy.
3. **Issue #10**: tick per results; comment the t/s table.
4. If qwen4exp released (check unslothai/llama.cpp releases vs
   `b10472-mix-4b653db`): `unsloth studio update` + serve Qwen3.8-Flash-Next.
5. Then (Kal's call): version-sweep suite / harness backend (#8), MLflow
   Phase 2, or /done to merge PR #9.

## Rules / workarounds (apply on first attempt)

- This llama-server build ignores SIGTERM — SIGKILL (`pkill -9`) required.
- `pkill -f`/`pgrep -f` over SSH: bracket trick (`[u]nsloth`) — tailscale ssh
  embeds the command string in its own argv.
- Git Bash mangles `$` in inline PowerShell — use .ps1/.py files, scp them.
- API keys stay on the box (grep from ~/unsloth-serve.log into shell vars).
- gh works for this repo (GitHub); Forgejo repos need the REST API.
- Windows: use `py` not python3; lint via WSL `Ubuntu-24.04`; CRLF phantom
  lint errors — check blobs with `git cat-file`.
- Commits: pause for Kal's review first. PRs: `--base develop`. Print links.
