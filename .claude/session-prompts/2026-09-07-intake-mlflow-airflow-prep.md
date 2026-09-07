# Session Continuation Prompt
**Generated:** 2026-09-07
**Ending phase:** intake-mlflow-airflow (2026-09 intake shipped; MLflow + Airflow live; prep for next batteries)
**Starting phase:** mlflow-metadata-expansion + quant-ladder collection

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (a cheap model tier is fine) to run the Startup block below and
the Section-scoped reads, and return a ≤2K-word digest. ONLY that digest enters main
context — never read the files or run the startup block in the main thread. Switch the main
thread to a higher model tier only when implementation starts (switching mid-session
re-prices the whole history at the new rate). Every path below is ABSOLUTE. (Cross-harness
doctrine: vvt-omnigent ADR 0005.)

We're working on the vtt-hw-benchmarks repo (Forgejo-primary, `vvc/vtt-hw-benchmarks`;
remote `forgejo`, `origin` is the stale GitHub mirror). Main checkout:
`C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks` (on `develop`). Session worktree:
`C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\intake-2026-09`
(branch `feature/bench-2026-09-intake`, clean, pushed; PR #26 → develop).
Rule: hand startup to a subagent (▶ FIRST MOVE); then execute the startup block; honor
read scoping literally; apply documented environment workarounds on the first attempt.

## Startup block (the subagent runs this first; batch aggressively; ABSOLUTE paths)

```bash
# 1. PR / branch state (Forgejo API; token via credential fill, never echoed)
FJ_TOKEN=$(printf "protocol=https\nhost=git.vvautosports.com\n\n" | git credential fill | sed -n "s/^password=//p"); for rp in "vtt-hw-benchmarks 26" "vvt-infrastructure 220"; do set -- $rp; curl -s -H "Authorization: token $FJ_TOKEN" "https://git.vvautosports.com/api/v1/repos/vvc/$1/pulls/$2" | python -c 'import json,sys; d=json.load(sys.stdin); print(sys.argv[1], "#"+str(d["number"]), "merged" if d.get("merged") else d.get("state"), d["head"]["sha"][:7])' "$1"; done
# If #26 is merged: cd C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks && git fetch forgejo && git checkout develop && git merge --ff-only forgejo/develop && git worktree remove .claude/worktrees/intake-2026-09 && git branch -d feature/bench-2026-09-intake
# If infra #220 is merged: cd C:/Users/kalman9/Documents/vvc/vvt-infrastructure && git fetch origin && git checkout develop && git reset --hard origin/develop   # local develop was "ahead 2" with doc commits that rode along in #220
# 2. Framework state + quant-ladder results (chain launched 2026-09-07 ~10:40 MDT; ~90 min)
ssh -o BatchMode=yes framework 'ls ~/runs/2026-09-07-ladder-*.DONE ~/runs/2026-09-07-ladder-CHAIN.DONE 2>/dev/null | xargs -n1 basename; tail -4 ~/runs/chain_2026_09_07_ladder.log; ss -ltn | grep -c :8888; df -h /mnt/ai-models | tail -1; ls ~/runs/2026-09-07-ladder-UD-Q4_K_XL-text/manifest.auto.yaml 2>/dev/null'   # expect 6 row DONE + CHAIN.DONE, errs none, 1 listener (GLM baseline), manifest.auto.yaml present (new drivers)
# 3. Services
curl -s -m 5 -o /dev/null -w "mlflow=%{http_code} " http://192.168.7.241:5000/health; curl -s -m 5 -o /dev/null -w "airflow=%{http_code}\n" http://192.168.7.241:8081/health   # expect 200 200
```

## Phase status

### Completed this session (2026-09-06 → 07)
- Intake rows at build 10687 (#20): Qwen3.8-27B UD-Q8 ~16 t/s, gemma-4-31B-it-qat UD-Q4 ~25 t/s, Qwen3.6-27B-MTP UD-Q8 ~14 t/s (baseline, no MTP), gemma-4-31B-it UD-Q8 ~6 t/s — all 3/3 text, 7/7 Tier-2 on raw AND healing-on rungs. Results in `results/sweeps/2026-09-06-intake/` (12 rundirs, manifests, scrubbed serve logs).
- Purge (#21): Flash-Next UD-IQ4_XS + UD-Q2_K_XL (162G). Downloads: Qwen3.6-27B-MTP UD-Q8, gemma-4-31B-it-qat UD-Q4 + drafter.
- MLflow (#6): shim `scripts/utils/log_sweep_to_mlflow.py`, `scripts/sweeps/run_manifest.py` (manifest.auto.yaml from both drivers), `scripts/utils/register_models.py` + `docs/reference/model-slots.yaml` (15 models, 10 aliases, UC mirror `vvc.evidence`), `pyproject.toml`, `.devcontainer/`. 13 sweep dirs logged; tags refreshed from the node (real gguf sha256/size). Drivers shipped to `framework:~` (backups `~/drivers-backup-2026-09-07/`), manifest smoke passed.
- EvalScope pilot (#15): GLM-4.7-Flash gsm8k 20/20, ARC 39/40, perf ladder; adapter + guide; experiment `hwbench/community-results`.
- Airflow spike (infra #219 / PR #220): 2.10.5 live on CT 241 :8081 (CT resized 4c/8G/32G, PBS backup `ct/241/2026-09-06T19:23:28Z`), `framework_ssh_smoke` DAG success 2026-09-07; `hwbench_intake_row` DAG paused. DAGs in `orchestration/airflow/`.
- Infra PRs #216/#218 merged; #201 open (S3 tenant-key + delta-rs write criteria unevidenced).
- Studio serve API key rotated (per-serve keys; leaked one dead → 401). Framework `tailscale set --accept-routes=false` applied; Airflow pubkey installed.
- Quant ladder (#23) STARTED 2026-09-07: `~/chain_2026_09_07_ladder.sh` → Qwen3-Coder-30B-A3B UD-Q4_K_XL / UD-Q6_K_XL (downloaded) / UD-Q8_K_XL, text + raw-rung tool, tag `ladder-b10687-<quant>`, `HWBENCH_FORGEJO_ISSUE=23`.
- Issues filed: #20 intake, #21 purge, #22 GLM-5.3-Flash (blocked), #23 quant ladder, #24 typed spec + /bench-run skill, #25 Ansible node provisioning, infra #219 Airflow spike.

### Remaining in this phase
1. Collect the quant ladder: scp `framework:~/runs/2026-09-07-ladder-*` into `results/sweeps/2026-09-07-ladder/`, grade (`python3 scripts/utils/grade_sweep.py <rundir> results --layout cfg` in WSL/devcontainer), write/merge manifests (manifest.auto.yaml now exists; add `rung`/`forgejo_issue` if missing), log to MLflow (`--forgejo-issue 23`), then `--refresh-tags` from the node (podman, see Section-scoped reads), add the ladder table to `docs/reference/PERFORMANCE-SUMMARY.md`, comment + close #23.
2. Merge PRs #26 (hwbench) and #220 (infra) once CI is green (force_merge via API; evidence comments already posted) — then the worktree cleanup in the startup block.
3. MLflow metadata expansion — see the plan section below (Kal's priority: "go beyond tagging", capture UI screens with the browser, read docs).
4. Fix manifest.auto.yaml gaps: `node` host map (`fedora` → `kalman9-framework-01`), `hardware` string, `HWBENCH_FORGEJO_ISSUE` in every chain env; add gpt-oss-120b + DeepSeek-V4-Flash to `models-inventory.yaml` (unblocks 2 challenger aliases).
5. MTP on/off pair on the **G1a** (its build 10639 has `--spec-type draft-mtp`; Framework 10687 does not): Qwen3.6-27B-MTP (embedded head, `--spec-type draft-mtp --spec-draft-n-max 2`) and gemma-4-31B-it-qat (+ `mtp-gemma-4-31B-it.gguf`, n-max 4). Then the Framework runtime bump with `UNSLOTH_LLAMA_RELEASE_TAG` pinned (#14).

### Deferred / backlogged
- #22 GLM-5.3-Flash (llama.cpp #27754 unmerged; IQ1-only fit). #24 typed spec + bench_run + /bench-run skill. #25 Ansible provisioning. Track 2B serving matrix; vision lane; Airflow ingress/auth; MLflow/UC version bumps (server is 3.4.0 / UC 0.6.0 — no bump needed yet).

## Key decisions made this session
- Two-lane rule enforced in MLflow: community results only under `hwbench/community-*`; never joined to bespoke tables.
- Tier-2 comparability = **raw rung** (`--disable-tools --disable-tool-call-healing --disable-tool-call-nudging`); healing-on rows are kept but labelled. Every new tool spec uses the raw flags.
- Runtime held at 10687 for comparability; MTP work goes to the G1a first.
- Airflow 2.10.5 (not 3.x) for the spike; Airflow orchestrates deterministic pipelines, MLflow records, Forgejo tracks, Claude plans; agentic frameworks stay out of the runner.
- `results/community/**/records/` tracked, raw eval/perf trees gitignored.
- Studio serve keys are per-process; rotation = restart the serve. Never `pkill -f "unsloth run"` over ssh (self-match kills the session).

## What to do next
1. Run the startup block via the subagent; if `CHAIN.DONE` exists, do "Remaining 1" (ladder collection) first — it is mechanical (Sonnet leg) and closes #23.
2. Merge #26 and #220 if CI is green; clean up worktrees.
3. Start the MLflow metadata expansion per the plan below: capture the four UI screens, implement the S-effort items in the shim first (run description, `mlflow.log_table` per-cell tables, dataset inputs for the cases file, source tags), then LoggedModel/system metrics.
4. Fix manifest.auto.yaml gaps + inventory rows (Remaining 4).
5. G1a MTP pair (Remaining 5).

## Section-scoped reads
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\intake-2026-09\.claude\session-prompts\2026-09-06-intake-mlflow-airflow-handoff.md` §"Environment workarounds" and §"Next work" — read FULL (short); carries the podman `--security-opt label=disable` invocation, Docker `MSYS_NO_PATHCONV=1`, MTP/G1a facts.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\intake-2026-09\docs\guides\MLFLOW-LOGGING.md` §"Running on the Framework" and §"--refresh-tags" — the node logging flow.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\intake-2026-09\docs\guides\MODEL-REGISTRY.md` §"Promotion" — how a new champion is set.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\intake-2026-09\docs\reference\PERFORMANCE-SUMMARY.md` §"Roster leaderboard" (lines ~10–40) and §"Tool-calling (Track 1)" — where the ladder rows go.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\intake-2026-09\scripts\utils\log_sweep_to_mlflow.py` — grep `def build_tags|def build_params|def build_metrics|log_artifact` for the insertion points of the metadata expansion.
- `C:\Users\kalman9\Documents\vvc\vvt-infrastructure\.claude\worktrees\airflow-spike\datacenters\denver\services\mlops\README.md` §"Airflow spike (orchestration)" — deploy/rollback/never-contend.
- Memory: `[[mlops-ct241-endpoints]]`, `[[hwbench-runtime-gotchas]]` (in `C:\Users\kalman9\.claude\projects\C--Users-kalman9-Documents-vvc\memory\`).

## MLflow metadata expansion plan (from the 2026-09-07 UI + docs audit; issue filed, see #27)
What the UI shows empty today on every run: **Description** ("No description"), **Datasets** panel/column, **Logged models** column, **System metrics** tab, **Traces** tab, **Registered prompts**. Tags are the only populated surface. Registry versions have Description + Tags + Aliases but no Schema (pointer registrations, not `log_model`). Server is MLflow 3.4.0 on Postgres (SQL-backed → Traces and LoggedModel are supported server-side).

Ordered by value/effort (all land in `scripts/utils/log_sweep_to_mlflow.py` unless noted):
1. **Per-cell results table** — `mlflow.log_table(df, artifact_file="eval_results.json")` on the parent run (columns: cfg, task/case, correct, tps_wall, tokens, finish_reason, q_*); renders sortable in the Artifacts table view. Effort S.
2. **Datasets** — `mlflow.log_input(mlflow.data.from_pandas(cases_df, source=<cases path>, name="tier2-cases-v1"), context="eval")` for the tool cases file and the 3-cell prompt set (from `sweep_phase1.TASKS`), so the Dataset column fills and "which runs used this prompt set" becomes a filter. Effort M.
3. **Run description** — `mlflow.note.content` tag: one line per child (model/quant/task/pass) and a sweep summary on the parent. Effort S.
4. **Experiment description/tags** — `MlflowClient().set_experiment_tag(exp_id, "mlflow.note.content", ...)` with methodology + Forgejo links; add `mlflow.source.git.commit` when known. Effort S.
5. **System metrics** — the System metrics tab: a rocm-smi/`/sys` poller thread in the drivers logging `system/*` metrics with `step` during each cell (built-in `mlflow.enable_system_metrics_logging()` is NVIDIA-oriented; AMD unverified). Effort M/L.
6. **LoggedModel linkage** — `mlflow.initialize_logged_model(name=<model_key>, model_type="gguf")` / `set_logged_model_tags`, linking each child run to the registry version so the Models column fills. Effort M.
7. **Figures** — `mlflow.log_figure` t/s bars and quality radar per sweep. Effort M.
8. **Traces** — `@mlflow.trace` around Track 2A agent-harness cells and tool-call transcripts (spans per tool call). Effort L. **Prompt Registry** — `mlflow.genai.register_prompt` for the fixed cell prompts, tag runs with the prompt version. Effort M.
Screen capture for the design doc: use Playwright via the `webapp-testing` skill (saves PNGs) or desktop computer-use, not the in-app browser (inline only). Pages: `#/experiments/2`, a child run (e.g. `Qwen3.8-27B__intake-b10687/code`), `#/models`, one version page.

## Blockers
- None hard. Docker Desktop must be running on the HP for the devcontainer image; `deploy.sh` in infra needs an interactive `bw unlock` (ship with tar | pct exec instead). Infra local `develop` is ahead-2 until #220 merges (reset to origin after).

## Pending system-evolution items
None opened via /system-evolution (follow-ups were filed directly as hwbench #22–#25 and infra #219).

## Discord Thread
(filled after the session post)
