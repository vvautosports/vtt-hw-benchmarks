# Session Continuation Prompt
**Generated:** 2026-08-26
**Ending phase:** unsloth-direction planning + fleet validation
**Starting phase:** unsloth-direction implementation (workstreams A/C/D of UNSLOTH-DIRECTION.md)

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread
Spawn ONE Explore subagent (cheap tier fine) to run the Startup block below and the
Section-scoped reads, and return a ≤2K-word digest. ONLY that digest enters main context —
never read the files or run the startup block in the main thread. Switch the main thread to
a higher tier only when implementation starts. Every path below is ABSOLUTE. (Doctrine:
vvt-omnigent ADR 0005.)

We're working on the vtt-hw-benchmarks repo (GitHub-hosted, NOT Forgejo — `gh` works here).
Worktree: `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction`
Branch: `feature/unsloth-direction` (clean; 1 commit `cc48ec1` ahead of develop, unpushed).
Rule: hand startup to a subagent (▶ FIRST MOVE); honor read scoping literally; apply the
documented workarounds on first attempt (Git Bash mangles `$` in inline PowerShell — use
.ps1 files; `pkill -f` patterns must use the `[x]` bracket trick over SSH or they kill the
session).

## Startup block (subagent runs first; batch aggressively; ABSOLUTE paths)

```bash
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks" worktree list && git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" status -sb && git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" log --oneline -3
# expect: worktree present, feature/unsloth-direction clean, cc48ec1 on top
tailscale status | grep -i framework && ssh -o ConnectTimeout=10 framework 'pgrep -f "[u]nsloth run" >/dev/null && echo SERVE-ALIVE || echo SERVE-DEAD; tail -5 ~/unsloth-serve.log | sed "s/sk-unsloth-[A-Za-z0-9_-]*/sk-REDACTED/"; cat /proc/cmdline | grep -o gttsize || echo "GTT-ARGS-NOT-ACTIVE (reboot pending or grubby failed)"'
# expect: framework online; SERVE-ALIVE unless rebooted (then relaunch serve, cache resumes)
```

## Fleet state (load-bearing — do not rediscover)

- **Framework (`ssh framework`, 100.64.0.1):** Fedora, kernel 7.1.9-fc43. Unsloth 2026.8.18
  at `~/.local/bin/unsloth`. Serving Qwen3.8-Flash-Next UD-Q3_K_XL (84GB, 3 shards, in HF
  cache on ROOT partition — not /mnt/ai-models yet) via
  `nohup ~/.local/bin/unsloth run --model unsloth/Qwen3.8-Flash-Next-GGUF:UD-Q3_K_XL -H 0.0.0.0 -p 8888`,
  log `~/unsloth-serve.log`. **API key: `grep -oE "sk-unsloth-[A-Za-z0-9_-]+" ~/unsloth-serve.log | tail -1`
  on the framework — never paste it into chat.** Endpoint:
  `http://kalman9-framework-01.vvnet.vvautosports.com:8888` (OpenAI `/v1/chat/completions` +
  Anthropic `/v1/messages`, Bearer auth).
  Suspend: `sleep/suspend/hibernate/hybrid-sleep.target` **masked**; user-session
  `sleep-inactive-ac-type=nothing` set. **Pending:** GDM auto-suspend override + WOL enable
  (sudo one-liners in UNSLOTH-DIRECTION.md workstream context / session transcript).
  **Kernel GTT args staged via grubby but NOT active** (`ttm.pages_limit` still 16328134
  ≈62GB) — takes effect on reboot; verify `/proc/cmdline` then (grubby staging was not
  independently confirmed). After any reboot: relaunch the serve (nohup dies), download
  resumes from cache. llama.cpp prebuilt there is b10360 (11 days stale) — if a model load
  fails on arch support, `unsloth studio update` then relaunch.
- **G1a (this machine):** Unsloth Desktop 0.1.803-beta installed (winget), studio backend
  127.0.0.1:8888 (desktop app owns it; CLI spawns 8889), ROCm gfx1151 llama.cpp prebuilt
  b10472, **detects Radeon 8060S** (`Hardware detected: ROCm (HIP 7.13)`), validated with
  Qwen3.5-4B end-to-end (all layers GPU, ~56GB usable = Windows ceiling). 13 models
  registered in its studio. Agent-key metadata in `~\.unsloth\studio\auth\` (booleans only;
  real keys printed by `unsloth run`).
- **/mnt/ai-models (framework, 1.3TB):** cleaned 2026-08-26, 98%→55% (~504GB freed, 9 dirs,
  successor-designated per retention policy). Layout is vendor-subdirs
  (`unsloth/<Repo>-GGUF/...`), inventory yaml drifted (flat paths, DeepSeek-70B absent).
- **Validation DONE (2026-08-26, GLM-4.7-Flash UD-Q8_K_XL):** full delegated round-trip
  G1a → mesh → Framework studio API. OpenAI dialect: 1526 prompt + 478 completion tokens in
  17.0s wall end-to-end (~28 t/s incl. pp+network; est. ~32 t/s generation vs 37.5 t/s
  llama-bench champion figure — pre-tuning, acceptable Unsloth-layer overhead). Anthropic
  dialect works incl. `thinking` content blocks — GOTCHA: thinking consumed the whole
  max_tokens budget on a trivial task; tune `--reasoning off` / budget for process tasks.
  Studio proxy strips llama.cpp `timings` from responses — for the overhead benchmark, hit
  the internal llama-server `/metrics` directly.
- **Qwen3.8-Flash-Next: BLOCKED upstream, not our config.** Even b10472-mix (newest
  unslothai/llama.cpp release, 2026-08-18) lacks the `qwen4exp` arch. Download is complete
  and cached; failed-load log at `~/unsloth-serve-qwen38-fail.log`. Watch
  `gh api repos/unslothai/llama.cpp/releases` for a tag newer than b10472-mix-4b653db, then
  `unsloth studio update` + relaunch — first live trigger for workstream E model-watch.

## Completed this session
- Research: Unsloth Desktop/API/AMD state, Strix Halo >120GB memory unlock, Qwen3.8-Flash-Next
  day-one drop, dual-cable USB4 bonding status (LACP broken, patch pending), two-node RPC
  cluster reality (capability not perf)
- Artifact: "The 120GB ZBook" (G1a Fedora dual-boot runbook + research; Kal has link)
- G1a: Unsloth validated end-to-end on Windows iGPU; BIOS confirmed 01.05.07; C: blocker
  found (368.8GB HF cache); ssh alias `framework` added to `~/.ssh/config`
- Framework: unsloth serve launched; suspend fixed; model cleanup; sleep-settings research
- Repo: issue #8, worktree, UNSLOTH-DIRECTION.md (6 workstreams) + inventory updates,
  commit cc48ec1
- Memory: unsloth-adoption, g1a-dual-boot-prep, model-retention-policy (+ baseline class)

## Remaining in this phase (ordered — What to do next)
1. Check for a new unslothai/llama.cpp release (> b10472-mix-4b653db); if present:
   `unsloth studio update` on framework, relaunch Qwen3.8 serve (cache resumes), validate
   with the scratchpad script pattern (model-agnostic, reads model id from /v1/models)
2. Push branch + open PR: `gh pr create --base develop` (GitHub repo; show link; test
   evidence in PR comment per house rules)
3. **wiki-sync (pending from this session):** vvt-knowledge clone at
   `C:\Users\kalman9\Documents\vvc\vvt-knowledge` (develop, clean; SCHEMA/CLAUDE read —
   OKF: `type:` frontmatter, relative md links, section index.md, `## Sources` closer).
   Add `projects/vtt-hw-benchmarks/unsloth-adoption.md` (type: note) distilling: Unsloth
   fleet adoption, Windows gfx1151 finding, memory-unlock facts, retention policy. Update
   `projects/vtt-hw-benchmarks/index.md`. Branch feature/*, PR to develop via /ship
   (gh does NOT work on Forgejo).
4. **Param/settings tuning on Qwen3.8-Flash-Next (run in PARALLEL with plan iteration —
   Kal wants this session shape):** sweep the Unsloth-documented presets (thinking: temp 1.0
   / top-p 0.95 / top-k 20; instruct: temp 0.7 / top-p 0.80 / presence 1.5), the
   `reasoning_effort` levels (xhigh/medium/low/none), `--speculative-type` modes
   (auto/mtp/ngram/off), and `--parallel` slots — measure t/s + quality on 2-3 fixed tasks,
   record winners in UNSLOTH-DIRECTION.md. **Close-out dogfood:** end that session by having
   the tuned model (via the Framework `/v1/messages` endpoint) draft the session's Discord
   summary or close-out checklist — first real delegated process task for the thinker node.
5. Overhead benchmark: same model `unsloth run` vs raw llama-server (workstream A)
5. Framework reboot (user-coordinated) → verify /proc/cmdline GTT args → full-GPU re-serve
   → hybrid-vs-full comparison; move Qwen3.8 GGUF to /mnt/ai-models
6. Workstream D kickoff: MLflow Phase 2 on MS-01 (reconcile the two composes first)
7. Workstreams E/F design: model-watch daily checks; nightly benchmark + fine-tuning-data
   flywheel (evals from VVC repos' real tech)

## Key decisions made this session
- Unsloth = serving+training layer on Strix Halo tier; MI50s stay on pinned llama.cpp Vulkan
- Dual-agent two-node architecture (thinker Framework / coder G1a) over RPC pooling;
  RPC = occasional capability mode; escalation-to-cloud = LiteLLM/omnigent routing policy
- Fedora 43 for G1a dual-boot (CachyOS = hosted-VM experiment later)
- Model retention policy incl. baseline/control class (memory: model-retention-policy)
- Qwen3.8-Flash-Next = thinker candidate; GLM-4.7-Flash stays champion until benchmarked

## Section-scoped reads
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction\docs\reference\UNSLOTH-DIRECTION.md` — read FULL (91 lines; the plan)
- `C:\Users\kalman9\Documents\vvc\vtt-hw-benchmarks\.claude\worktrees\unsloth-direction\models-inventory.yaml` — §default_models only (what changed: M2.5, Qwen3.8, baseline tags)
- GitHub issue #8: `gh issue view 8 -R vvautosports/vtt-hw-benchmarks` — task checklist
- `C:\Users\kalman9\Documents\vvc\vvt-knowledge\CLAUDE.md` — §Writing + §Forge and flow only (wiki contribution rules)
- Memory: MEMORY.md §Local AI + §Feedback (model-retention-policy) — already index-loaded

## Blockers
- Framework GTT unlock inactive until reboot (user coordinates timing)
- G1a dual-boot blocked on C: cleanup (delete/relocate 368.8GB `%USERPROFILE%\.cache\huggingface` — needs Kal's go)
- GDM suspend override + WOL: sudo one-liners not yet run (Kal)

## Pending system-evolution items
None.

## Discord Thread
<filled by Step 8>
