# Session Continuation Prompt

**Generated:** 2026-11-01
**Ending phase:** mlflow-metadata-27 shipped (PR #29)
**Starting phase:** strix-halo-model-research — decide what to benchmark next

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread

Spawn ONE Explore subagent (cheap tier) to run the Startup block and the Section-scoped reads, and return a ≤2K-word digest. ONLY the digest enters main context. Switch the main thread up only when writing begins. Every path is ABSOLUTE. (Doctrine: vvt-omnigent ADR 0005.)

Repo: vtt-hw-benchmarks at `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks` (main checkout on `develop`). Start a fresh worktree `claude --worktree model-research` → rename to `feature/model-research-2026-11`.

## Startup block

```bash
cd /c/Users/kalman9/Documents/vvc/vtt-hw-benchmarks && git fetch forgejo && git status --short && git log --oneline -3 forgejo/develop
# PR #29 state (merged → remove .claude/worktrees/mlflow-metadata + branch)
TOKEN=$(printf 'protocol=https\nhost=git.vvautosports.com\n' | git credential fill | sed -n 's/^password=//p'); for n in 29; do curl -s -H "Authorization: token $TOKEN" "https://git.vvautosports.com/api/v1/repos/vvc/vtt-hw-benchmarks/pulls/$n" | python -c "import sys,json;d=json.load(sys.stdin);print(d['number'],d['state'],d['merged'])"; done
ssh -o BatchMode=yes -o ConnectTimeout=10 framework 'ls -d ~/runs/2026-09-07-gemma-ladder-*/ | wc -l; df -h /mnt/ai-models | tail -1; ls /mnt/ai-models/unsloth | wc -l'   # expect 8 rundirs, ~95% disk
cat ~/.unsloth/llama.cpp/UNSLOTH_PREBUILT_INFO.json | python -c "import sys,json;print(json.load(sys.stdin)['release_tag'])"   # G1a build; was b10830
```

## Research task (this session's deliverable)

Use the `deep-research` skill (subagents) — the question is "what should the next intake on Strix Halo (gfx1151, 128 GB, Framework Fedora + HP G1a Windows) benchmark, and with what harness?" Scope, each a subagent:

1. **New models since 2026-09** in our bands (dense 27–35B Q8/QAT-Q4, MoE A3B/A4B, ≤120B MoE at UD-Q4): unsloth GGUF releases, MTP/draft-head variants, anything with sidecar drafters. Cross-check against `models-inventory.yaml` and MODELS-TO-TEST so we don't re-list what's tested.
2. **Halogen** project status and whether it changes the Strix Halo serving story.
3. **Donato Capitella** — recent Strix Halo posts/numbers; what configs he reports beating ours (we hold ~63 t/s Framework / ~36 t/s G1a on Qwen3-Coder-30B-A3B UD-Q8, 18→40 t/s with MTP on Qwen3.6-35B-A3B).
4. **llama.cpp / ROCm / unsloth runtime** since b10830: gfx1151 kernel wins, speculative modes (`dspark`, `dflash`, `mtp+ngram`), `--fit`, unified-memory changes; what the Framework bump (#14) would buy.
5. **Harnesses** beyond our bespoke batteries: EvalScope (pilot exists, #15 two-lane rule), lm-eval, BFCL, Aider polyglot, SWE-bench-lite, anything agent-centric that runs offline against an OpenAI-compatible endpoint.

Output: (a) update `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\docs\reference\MODELS-TO-TEST.md` (new candidates section with size, quant, why, source link); (b) one Forgejo issue "next intake 2026-11" with a prioritized model list, config axes, and harness picks, respecting disk (95% full → purge needs a designated successor per retention policy) and the two-lane rule. Check in with Kal on 2–4 key choices before writing the full doc.

## Still owed (carry forward, not this session's focus)

- Harvest/grade/log #28 gemma ladder: 8 rundirs on Framework `~/runs/2026-09-07-gemma-ladder-*`, scrub keys on node, scp to `results/sweeps/2026-09-07-gemma-ladder/`, table in PERFORMANCE-SUMMARY, Q8-slowness verdict.
- Close #23 (ladder logged; table at PERFORMANCE-SUMMARY ~line 43).
- Full G1a MTP pair (drop `--only`) when docked; then Framework runtime bump (#14).
- #27 remainder: Playwright UI captures, LoggedModel linkage, system metrics, figures, traces.
- Worktree cleanup: `intake-2026-09` (merged, clean), infra `airflow-spike` (stale); `track2a-stream-b` has UNCOMMITTED work — don't remove blind. `charming-pare-45cbae` is a detached leftover.
- `run_manifest.py` gaps: `rung`, `hardware`, `repo_git_sha` empty; `node: fedora`.

## Key decisions made this session

- Long runs go to the Framework while Kal travels; G1a is config + smoke only.
- Chain pattern: detached `setsid nohup`, on-disk rungs first, per-rung `.DONE` skip, per-download wait with timeout → SKIP, never fatal; stability over depth.
- Studio `--speculative-type mtp` = llama-server `--spec-type draft-mtp`; the studio proxy strips `timings`, so tps_wall is the comparable number. G1a scripted serves on 8899.

## Section-scoped reads

- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\docs\reference\MODELS-TO-TEST.md` — read FULL (it is the doc being updated).
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\docs\reference\PERFORMANCE-SUMMARY.md` lines 1–80 — current rankings + #23 ladder table.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\models-inventory.yaml` — grep `name:` only, for the tested set.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\docs\reference\UNSLOTH-DIRECTION.md` §"Post-upgrade batch on b10639" onward — what MTP/spec history we already have.
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\session-prompts\2026-09-20-framework-remote-testing.md` §"Section-scoped reads" — env workarounds (podman label=disable, key scrub, MLflow container invocation).

## Blockers

None hard. Framework `/mnt/ai-models` ~95% full. MCP_DOCKER was flaky last session.

## Pending system-evolution items

None.

## Discord Thread

See PR #29 post (filled in by /done).
