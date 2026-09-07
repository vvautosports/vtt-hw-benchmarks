# 2026-09-06 — Intake rows, MLflow live, Airflow spike: handoff

Standing rule: **Execute the startup block first; honor read scoping literally; apply documented environment workarounds on the first attempt.**

## ▶ FIRST MOVE
Spawn ONE Explore subagent (cheap tier) to run the startup block and the section-scoped reads below, returning a ≤1.5K-word digest. Only the digest enters the main thread. Switch the main thread to a higher tier only when implementation starts.

## Startup block (copy-paste)

```bash
cd /c/Users/kalman9/Documents/vvc/vtt-hw-benchmarks && git worktree list && git -C .claude/worktrees/intake-2026-09 status -sb | head -5 && git -C .claude/worktrees/intake-2026-09 log --oneline -3
ssh -o BatchMode=yes framework 'ls ~/runs/*.DONE | xargs -n1 basename | tr "\n" " "; echo; ss -ltn | grep -c ":8888"; df -h /mnt/ai-models | tail -1; ip route get 192.168.7.241 | head -1; grep -c airflow@denver-mlops-01 ~/.ssh/authorized_keys 2>/dev/null; ~/.unsloth/llama.cpp/build/bin/llama-server --version 2>&1 | head -1'
curl -s -m 5 http://192.168.7.241:5000/health; echo; curl -s -m 5 http://192.168.7.241:8081/health | head -c 160; echo
```

## State at handoff (2026-09-06 evening)
- Branch `feature/bench-2026-09-intake` in worktree `.claude/worktrees/intake-2026-09` (from develop `1bc4a85`). Commit/PR status: see the last commit line above; if uncommitted, everything below is staged work awaiting Kal's review.
- Intake rows (hwbench #20) DONE on build 10687: Qwen3.8-27B UD-Q8 (~16 t/s), gemma-4-31B-it-qat UD-Q4 (~25 t/s, 17.3G), Qwen3.6-27B-MTP UD-Q8 baseline (~14 t/s), gemma-4-31B-it UD-Q8 re-run (~5.9 t/s). All 3/3 text, 7/7 Tier-2 on raw AND healing-on rungs. Evidence `results/sweeps/2026-09-06-intake/` (12 rundirs; serve logs redacted).
- Purge (#21) DONE: Flash-Next UD-IQ4_XS + UD-Q2_K_XL deleted, 196G free after; downloads added Qwen3.6-27B-MTP UD-Q8 and gemma-4-31B-it-qat UD-Q4 + mtp drafter.
- MLflow LIVE at `http://192.168.7.241:5000` (docs said `.30` = MS-01 host). Experiments `hwbench/text-sweeps` (2), `hwbench/toolcall` (4), `hwbench/model-registry`, `hwbench/community-evalscope` (if the pilot landed). Registry: 15 models / 15 versions / 10 aliases (`docs/reference/model-slots.yaml`), UC mirror `vvc.evidence.*`.
- Shim + manifest v2 (#6 slice 1): `scripts/utils/log_sweep_to_mlflow.py`, `scripts/sweeps/run_manifest.py` wired into roster_batch/toolcall_battery, `pyproject.toml`, `.devcontainer/`. **Shipped to the Framework 2026-09-07** (`~/run_manifest.py`, `~/roster_batch.py`, `~/toolcall_battery.py`, `~/sweep_phase1.py`; node backups in `~/drivers-backup-2026-09-07/`). Manifest smoke passed: `~/runs/2026-09-07-manifest-smoke/manifest.auto.yaml` (gemma-4-26B-A4B, 3 cells, ~37 t/s). Tag refresh done from the node: all 12 intake rundirs have `gguf_sha256`/`gguf_size_bytes`; registry 14/15 versions refreshed. Scripts staged at `framework:~/hwbench-scripts/`.
- EvalScope pilot (#15) DONE: GLM-4.7-Flash gsm8k 20/20, ARC 39/40, perf ladder shows queueing at concurrency 2; logged under `hwbench/community-results` (id 5). Adapter `scripts/utils/evalscope_to_records.py`, guide `docs/guides/EVALSCOPE-PILOT.md`. Flags: `--eval-type openai_api`; perf `random` dataset needs `--tokenizer-path` + prompt-length bounds.
- Airflow 2.10.5 spike on CT 241 `:8081` (infra #219, branch `feature/mlops-airflow-spike`): webserver + scheduler healthy, DAGs `hwbench_intake_row` (paused) and `framework_ssh_smoke` parse, pool `framework_gpu`, connection `framework_ssh`. Blocked on two manual Framework steps Kal runs (accept-routes off + authorized_keys append), then trigger the smoke DAG.
- Runtime facts (#14): studio-bundled `~/.unsloth/llama.cpp/build/bin/llama-server` 10687 has NO `--spec-type draft-mtp`; G1a build 10639 HAS it; unsloth 2026.9.x pins nothing (resolves latest; pin via `UNSLOTH_LLAMA_RELEASE_TAG`).
- GLM-5.3-Flash deferred (#22). Quant ladder planned (#23). Typed spec + /bench-run (#24). Ansible provisioning (#25).

## Section-scoped reads (grep + offset; never full files)
- `docs/reference/PERFORMANCE-SUMMARY.md` §Roster leaderboard (4 new rows), §Trust notes (gemma UD-Q8 anomaly), §Retired / demoted models.
- `docs/guides/MLFLOW-LOGGING.md` §Running on the Framework (podman command, `--refresh-tags`).
- `docs/guides/MODEL-REGISTRY.md` §Promotion / aliases.
- `orchestration/airflow/README.md` §Never-contend + files expected on the node.
- `.claude/session-prompts/2026-09-06-standouts-gaps-next-tests.md` §0 Ground truth, §3 Coverage gaps, §4 Next test set.
- `docs/guides/EVALSCOPE-PILOT.md` (if present) — results + dashboard command.

## Environment workarounds (apply first time)
- `hf download` needs one `--include` per pattern.
- Tool specs must carry `--disable-tools --disable-tool-call-healing --disable-tool-call-nudging` to be leaderboard-comparable; text specs `--disable-tools`. roster_batch adds neither.
- Serve logs under a rundir contain the studio key: before copying results into the repo run `grep -rlE 'sk-unsloth-[A-Za-z0-9_-]{8,}' <dir> | xargs -r sed -i -E 's/sk-unsloth-[A-Za-z0-9_-]+/sk-unsloth-<redacted>/g'`.
- Docker on Git Bash: prefix `MSYS_NO_PATHCONV=1`; devcontainer image `mcr.microsoft.com/devcontainers/python:1-3.12-bookworm` with `-v "<worktree>:/work" -w /work`; grader sha via `-e HWBENCH_GRADER_VERSION=<sha>`.
- The auto-mode classifier blocks Framework auth/network changes and CT secret/key steps — hand those to Kal as a bash block; everything else (SSH read-only, scp, pct resize/backup, compose up) passed.
- Waiting: no bare local `sleep`; wait remotely `ssh framework 'for i in $(seq 1 45); do [ -f MARKER ] && break; sleep 10; done'`.
- Detached chains: `setsid nohup bash ~/chain_X.sh > ~/runs/chain_X.log 2>&1 < /dev/null &`; drivers run from `$HOME` on the node.
- Podman on the Framework (Fedora, SELinux enforcing): bind mounts need `--security-opt label=disable` (or `:z`), else every file in the mount is "Permission denied". Working invocation: `podman run --rm --security-opt label=disable -v /mnt/ai-models:/mnt/ai-models:ro -v "$HOME/runs:/runs" -v "$HOME/hwbench-scripts:/work" -w /work -e MLFLOW_TRACKING_URI=http://192.168.7.241:5000 docker.io/library/python:3.12 bash -c 'pip -q install "mlflow>=2.19" pyyaml && python scripts/utils/log_sweep_to_mlflow.py /runs/<rd> --spec /runs/<rd>/spec.json --refresh-tags --models-root /mnt/ai-models'`.
- `manifest.auto.yaml` gaps to close: `node` is the bare hostname (`fedora`, not `kalman9-framework-01`), `hardware` empty, `repo_git_sha` empty on the node, `forgejo_issue` needs `HWBENCH_FORGEJO_ISSUE` in the chain env.

## Next work (ordered)
1. infra #219: confirm the two manual Framework steps, trigger `framework_ssh_smoke`, paste the log; decide mesh vs LAN for CT→node SSH.
2. (done 2026-09-07) Fix the `manifest.auto.yaml` gaps above (host map, hardware string, `HWBENCH_FORGEJO_ISSUE`); add gpt-oss-120b and DeepSeek-V4-Flash rows to `models-inventory.yaml` so the two missing challenger aliases can be set.
3. #14: MTP on/off pair on the **G1a** (build 10639 has draft-mtp): Qwen3.6-27B-MTP embedded head (`--spec-type draft-mtp --spec-draft-n-max 2`), gemma-4-31B-it-qat with `mtp-gemma-4-31B-it.gguf` (`--spec-draft-n-max 4`); then bump the Framework with a pinned `UNSLOTH_LLAMA_RELEASE_TAG` and re-baseline.
4. #23 quant ladder on Qwen3-Coder-30B-A3B (UD-Q4_K_XL, UD-Q6_K_XL vs UD-Q8).
5. #10/#12 Track 2A unblock (cache-ram env) once the node is idle.
6. #24 typed spec + `bench_run.py` + `/bench-run` skill (skill-creator); wire the Airflow DAG to it.
7. #15 EvalScope: widen datasets, run `evalscope app` as a supporting container on MS-01 if it earns its keep.
8. #6 second half: Delta bronze via vvc-evidence; reconcile `model_key` convention between shim (inventory name) and registry (repo#quant).
9. #22 GLM-5.3-Flash: watch llama.cpp #27754.

## Issues
| # | Title |
|---|---|
| [hwbench #20](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/20) | intake rows (done; close with PR) |
| [hwbench #21](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/21) | purge (done; close with PR) |
| [hwbench #22](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/22) | GLM-5.3-Flash deferred |
| [hwbench #23](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/23) | Coder-30B quant ladder |
| [hwbench #24](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/24) | typed spec + /bench-run |
| [hwbench #25](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/25) | Ansible node provisioning |
| [hwbench #6](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/6) | MLflow + Delta (slice 1 shipped) |
| [hwbench #14](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/14) | MTP / runtime pin |
| [hwbench #15](https://git.vvautosports.com/vvc/vtt-hw-benchmarks/issues/15) | EvalScope community lane |
| [infra #219](https://git.vvautosports.com/vvc/vvt-infrastructure/issues/219) | Airflow spike on CT 241 |
| [infra #201](https://git.vvautosports.com/vvc/vvt-infrastructure/issues/201) | lakehouse Phase 0 acceptance (2 criteria lack evidence) |
