# Session Continuation Prompt

**Generated:** 2026-09-20
**Ending phase:** mlflow-metadata-expansion (#27) + gemma ladder kickoff (#28)
**Starting phase:** framework-remote-testing (Kal remote in Florida; HP G1a = config/smoke only)

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread

Spawn ONE Explore subagent (cheap tier) to run the Startup block and the Section-scoped reads, and return a ≤2K-word digest. ONLY the digest enters main context. Switch the main thread to a higher tier only when implementation starts. Every path below is ABSOLUTE. (Doctrine: vvt-omnigent ADR 0005.)

Repo: vtt-hw-benchmarks, worktree `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\mlflow-metadata`.
Branch: `feature/mlflow-metadata-27` — DIRTY, 7 uncommitted paths, never pushed. Kal reviews before any commit.

## Startup block

```bash
cd /c/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/mlflow-metadata && git status --short && git log --oneline -3
ssh -o BatchMode=yes -o ConnectTimeout=10 framework 'ls -d ~/runs/2026-09-07-gemma-ladder-*/; cat ~/chain_2026_09_07_gemma_ladder.log | grep -E "exit=|SKIP|done"; pgrep -fa "llama-server|chain_" | grep -v pgrep | cut -c1-100; df -h /mnt/ai-models | tail -1; free -g | sed -n 2p'
# expect: 8 rundirs, 8x "exit=0", "gemma ladder chain done", disk ~95% (62G free)
curl -s -m 5 -o /dev/null -w "mlflow %{http_code}\n" http://192.168.7.241:5000/health
```

## Status

### Completed this session

- #27 S-items in `scripts/utils/log_sweep_to_mlflow.py`: run descriptions (`mlflow.note.content`, child + parent), `mlflow.log_table` → `eval_results.json`, `mlflow.log_input` datasets, experiment note, `mlflow.source.*` tags, `--refresh-tags` back-fill, draft metrics, `HWBENCH_GIT_COMMIT` env fallback.
- New gate `scripts/testing/test_log_sweep_table.py`, wired into `.forgejo/workflows/ci.yml` (+`python3-yaml`). Passes in WSL alongside existing gates.
- Live back-fill (exit 0): 6 ladder parents (`--forgejo-issue 23`) + 12 intake parents (`--forgejo-issue 20`) now have description + table + dataset.
- G1a runtime is **b10830-mix-d5c17a0**. Driver `scripts/sweeps/g1a_mtp_pair.py` + spec `scripts/sweeps/specs/2026-09-07-g1a-mtp-pair.json`. Smoke in `results/sweeps/2026-09-07-g1a-mtp-smoke/` (keys scrubbed; 2 of 4 arms, stopped deliberately): Qwen3.6-35B-A3B-MTP reasoning 18.2 → 39.9 t/s with `mtp` n_max=2.
- Issue #28 filed; Framework chain finished: 8 rundirs `~/runs/2026-09-07-gemma-ladder-{UD-Q8_K_XL,qat-UD-Q4_K_XL,UD-Q4_K_XL,UD-Q6_K_XL}-{text,toolraw}`.

### Remaining

1. Harvest #28: scrub keys ON THE NODE, scp into `results/sweeps/2026-09-07-gemma-ladder/`, grade, log to MLflow `--forgejo-issue 28`, table in PERFORMANCE-SUMMARY, Q8-slowness verdict, close #28.
2. Queue the next Framework chains (stable/self-healing pattern — see decisions).
3. Kal reviews diff → commit → push to `forgejo` → PR to develop (`/ship`).
4. Close #23 (logged + table at PERFORMANCE-SUMMARY line ~43, issue still open).
5. Worktree cleanup never done: `intake-2026-09` (clean, merged), infra `airflow-spike` (stale). `track2a-stream-b` has uncommitted work — do not remove blind.

### Deferred

- Full G1a MTP pair (4 arms × 10 cells): only when docked; drop `--only`. Then Framework runtime bump (#14).
- #27 rest: Playwright UI captures, LoggedModel linkage, system metrics, figures, traces.
- `run_manifest.py` gaps: `rung`, `hardware`, `repo_git_sha` empty; `node: fedora`.

## Key decisions

- HP G1a gets config + smoke only while Kal travels; long runs go to the Framework.
- Chain pattern: detached `setsid nohup`, on-disk rungs first, per-rung `.DONE` skip, each download waited individually with a timeout then SKIP (never fatal), driver failure logged and chain continues.
- Stability over depth: queue several simple chains rather than one complex one.
- Studio `--speculative-type mtp` maps to llama-server `--spec-type draft-mtp`; the studio proxy strips `timings`, so tps_wall is the comparable number.
- G1a scripted serves use port 8899 (Desktop app holds 8888).

## What to do next

1. Subagent digest (above).
2. Harvest + grade + log #28 (step 1 of Remaining).
3. Propose 2–3 Framework chain candidates to Kal with recommendations BEFORE launching (disk is 95% — prefer on-disk models; any download needs a purge per the retention policy). Candidates: gemma-4-26B-A4B ladder; Qwen3.6-27B-MTP baseline re-run; healing-on rung for the gemma ladder.
4. Launch approved chains; leave a log + `CHAIN.DONE` marker for check-in.

## Section-scoped reads

- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\session-prompts\2026-09-07-intake-mlflow-airflow-prep.md` §"Gotchas"/environment workarounds — podman `--security-opt label=disable`, `MSYS_NO_PATHCONV=1`, key-scrub one-liner, never `pkill -f "unsloth run"` over ssh.
- Framework `~/chain_2026_09_07_gemma_ladder.sh` — read FULL (short); template for new chains.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\mlflow-metadata\docs\reference\PERFORMANCE-SUMMARY.md` lines ~35–60 — #23 ladder table format to mirror for #28.
- MLflow logging invocation that worked this session: devcontainer image `mcr.microsoft.com/devcontainers/python:1-3.12-bookworm`, `pip install "mlflow>=2.19" pyyaml`, env `MLFLOW_TRACKING_URI=http://192.168.7.241:5000 HWBENCH_GIT_COMMIT=<sha>`.

## Blockers

- None hard. Framework `/mnt/ai-models` at 95% (62G free). MCP_DOCKER failed to connect last session (Discord via that path unavailable).

## Pending system-evolution items

None.

## Discord Thread

(not posted)
