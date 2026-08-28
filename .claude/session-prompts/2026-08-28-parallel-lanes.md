# Session Continuation Prompt
**Generated:** 2026-08-28
**Ending phase:** Track 1 tool-calling + co-residency + AI-server discovery
**Starting phase:** Parallel lanes — pick ONE lane per session

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT, not the main thread

Spawn ONE Explore subagent (cheap tier is fine) to run the Startup block and the
Section-scoped reads for **your lane only**, and return a ≤2K-word digest. ONLY that digest
enters main context — never read these files or run the startup block in the main thread.
Switch the main thread to a higher tier only when implementation starts. All paths absolute.
(Doctrine: vvt-omnigent ADR 0005.)

Repo: `vtt-hw-benchmarks`, worktree
`C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction`
Branch: `feature/unsloth-direction` (clean, **8 commits UNPUSHED** — see Blockers).

## ⚠️ READ THIS BEFORE STARTING A PARALLEL SESSION

Kal wants **several sessions at once, but not many things in flight at once.** Pick **one
lane**. Lanes are disjoint by *machine*, which is what makes them safe to run together:

| Lane | Machine | Safe to run alongside? |
|---|---|---|
| **A — Forge unblock + PR #5** | Forgejo CT 237 | yes, short |
| **B — Framework benchmarking** | `framework` | yes |
| **C — HP G1a validation** | HP G1a | yes |
| **D — AI server bring-up** | `cincy-aiserver-pve-12` | yes, but gated |

**Two hard rules for parallel work:**

1. **One worktree per session.** B, C and D all commit to this repo. Running two sessions in
   the SAME worktree will collide on the index. Create your own:
   `git -C <main clone> worktree add .claude/worktrees/<lane> feature/unsloth-direction`
   — or branch off and merge later.
2. **Only ONE session may run inference on a given box.** Every driver here does
   `pkill -f '[l]lama-server'` before loading. Two sessions benchmarking the Framework will
   silently kill each other's servers and produce garbage. Lanes B, C, D are on different
   machines, which is the whole point.

## Startup block (subagent runs this; absolute paths)

```bash
# State + what landed 2026-08-28 (8 commits)
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" log --oneline -9
git -C "C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction" status --short --branch
# NOTE: branch tracks `forgejo` (fixed 2026-08-28). `origin` is the STALE GitHub mirror —
# an "ahead 22" against origin is meaningless, always compare against forgejo.

# Is the forge fixed yet? These two calls diagnose it in 10s (Lane A gate):
curl -s -m 10 -o /dev/null -w "api: %{http_code} %{time_total}s\n" https://git.vvautosports.com/api/v1/version
curl -s -m 20 -o /dev/null -w "git: %{http_code} %{time_total}s\n" "https://git.vvautosports.com/vvc/vtt-hw-benchmarks.git/info/refs?service=git-upload-pack"
# api 200 fast + git 000/timeout  => still wedged, Lane A blocked, do NOT retry pushes.

# Framework health (Lanes B only)
ssh framework 'ps -eo args | grep "[l]lama-server" | head -1 | cut -c1-120; df -h /mnt/ai-models | tail -1'
```

## Completed this session

- **Track 1 Tier 1 tool-calling battery built and run** — 5 deterministic cases × 3 healing
  rungs × 6 models = **90/90 pass**. Saturated: it is a floor test, not a ranking.
- **Champion re-baseline under `--disable-tools`** — 17/18. Removing injection raised t/s
  10–21% and **reordered the leaderboard**: Ornith-1.5 (64.5) > Nemotron-3.5 (63.1) >
  Qwen3.6-35B-MTP (61.3).
- **Qwen3-Coder-30B "74.5 code king" figure explained and retired** — it was speculative
  decoding racing through ~3000 tokens of tool-loop boilerplate. True figure ~43.6.
- **Co-residency proven** — GLM+Coder at 74.3 GiB, co-residency FREE, aggregate 59.8 t/s.
  Heavy pair (gpt-oss-120b) also works at 100 GiB but is worse on every axis.
- **Deep-chain to 60 calls** — 5/6 clean; **gpt-oss-120b breaks at 31 and FABRICATES** a
  terminal answer. Reproducible across all 3 rungs. #19513 still does not reproduce.
- **DeepSeek-V4-Flash day-one** (97 GiB, 3/3, ~14 t/s) and **Muse vision confirmed** (2/2).
- **Forgejo CT 237 disk-full incident** diagnosed; volume extended 40→80 G (Kal approved).
- **AI server found**: it is `cincy-aiserver-pve-12` (100.64.0.39) in Cincinnati, not the
  old `cbus-ai-server-01`. Hardware documented wrong in two places — see Lane D.

## Key decisions made this session

- **`--disable-tools` stays ON for tool-calling runs.** It governs server-side built-ins,
  not the client-tool passthrough under test. The scoping doc said otherwise; it was wrong.
- **The healing axis is 3 rungs** (`raw`/`healed`/`full`) because `--enable-tool-call-nudging`
  (default on) silently retries. But it separated nothing on this roster — **run `raw` alone
  by default** and apply the ladder surgically to models that fail there.
- **Tool-call cases use greedy sampling** (temp 0), not the battery's thinking profile.
- **Grading expectations travel WITH each run** (`toolcall_cases.json` copied into the run
  dir) so editing case definitions can never silently re-grade committed history.
- **GLM-4.7-Flash + Qwen3-Coder-30B is the dual-agent config**, not gpt-oss-120b.
- **Co-residency ≠ Phase 6.** Phase 6 pools memory across nodes for one huge model; this
  partitions one node between two. Not blocked on the G1a dual-boot.

---

## Lane A — Unblock the forge, push, land PR #5

**Gated on Kal.** The fix is `docker restart forgejo` inside CT 237 (I was blocked by the
permission classifier and did not work around it).

1. Kal (or an approved session) runs on `denver-compute`: `pct exec 237 -- docker restart forgejo`
2. Verify with the two curls in the Startup block — `info/refs` must return 200 quickly.
3. `git -C <worktree> push forgejo feature/unsloth-direction` (8 commits).
4. Post PR #5 test evidence — **already drafted**, ready to paste:
   `C:/Users/kalman9/AppData/Local/Temp/claude/C--Users-kalman9-Documents-vvc/398686d9-66f9-40f1-93b4-b1787a062964/scratchpad/pr5-evidence.md`
   (scratchpad is session-scoped — if gone, regenerate from the manifests.)
5. Review/merge PR #5 with Kal. `gh` does NOT work on Forgejo — use the REST API with
   `git credential fill`.

**Also worth doing while in there:** the OCI package registry is what filled the disk
(30 GB of 40). It will fill again. Prune old images or plan the next extension.

## Lane B — Framework benchmarking (independent, highest-value)

In priority order:

1. **Harder tool-call cases.** Tier 1 is saturated at 90/90 and cannot rank anything. Add:
   parallel/multi-call turns, nested + union-typed argument schemas, ambiguous tool
   selection, adversarial arg coercion. Rotate `tc_distractor`'s correct tool position —
   it is currently always last of five, so positional bias is untested.
2. **Push the chain past 60.** Five models saturated the 60 bar too; their real ceilings are
   unmeasured. Use `toolcall_cases_deepchain.json` and raise `target_depth`/`pass_depth`.
3. **Grade a co-resident run.** `coresidency_test.py` measured throughput and health only —
   it does NOT establish that answers stay correct under contention. Wire the graders in.
4. **Nemotron-3.5 summarize second seed.** It failed on a missing literal `TL;DR` label with
   5 correct bullets; Nemotron-3-Nano has the same habit. Confirm family trait, not regression.
5. **DeepSeek context ceiling.** It ran pinned to 16384 for load safety; real limit unknown
   (~25 GiB KV budget after 97 GiB of weights).

## Lane C — HP G1a validation (do while Kal preps the HP)

**This is a real gap, not a nice-to-have.** `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` is staged on
the G1a via `setx` but has **never been serve-verified on Windows.** The unified-memory
corruption bug (the one that produced garbage 204–225 t/s figures) is a Strix Halo defect,
not a Linux one — so nothing on the HP is trustworthy until a graded battery runs there.

1. Verify the env var actually reaches the serve process on Windows.
2. Run the 3-task battery via `isolated_battery.py` with `--disable-tools`; compare against
   the Framework's clean re-baseline. Same silicon → numbers should be close.
3. Then light-pair co-residency (GLM 33 + Coder 34 = 67 GiB). **HP under Windows is capped
   at 96 GB**, so the heavy pair (95 GiB) will NOT fit — do not attempt it.

## Lane D — AI server bring-up (gated: Kal drives host config)

**Read `docs/reference/AI-SERVER-GFX906-PLAN.md` first — it has the full plan.** Summary of
what makes this lane different: the box is 5× Radeon Pro Vega II + 1× Pro VII/MI50 (all
gfx906, 192 GB VRAM) but only **31 GB system RAM**, 142 GB local SSD, and 2.6 TB NFS behind
a **1 GbE** link.

Ordered steps (0–2 are Kal's, manual):

0. **Ask Jordan about thermal/power tuning.** He solved it; it is documented nowhere. Six
   Vega 20 at ~300 W is ~1.8 kW, and the SKUs are thermally mismatched (Vega II is an Apple
   MPX module, MI50 is passive). Throttling would silently invalidate every number — same
   class of hidden variable as the unified-memory bug.
1. **Console bring-up of VM 610** — guest agent configured but not running, VM has no IP,
   no SSH key enrolled. Blocks everything else.
2. Decide whether to reattach the missing NVMe/ZFS disks (`zpool import` finds nothing,
   `/dev/nvme*` absent — those disks are not in the machine).
3. `rocminfo | grep -o 'amdgcn-amd-amdhsa--gfx906[^ ]*'` per card — `sramecc-` means the
   documented rocBLAS segfault applies. **Start on Vulkan, which sidesteps it entirely.**
4. Thermal baseline, then the RAM ceiling empirically (start ~5 GB, step up).
5. **Quant ladder is the highest-value early experiment**: Q4_0 vs Q4_1 vs Q8_0 vs Q4_K_M vs
   an IQ variant. gfx906 kernels favour Q4_0/Q4_1/Q8_0 — this **inverts** our Strix Halo
   house quants, so it decides every later download. Do not bulk-download before this.

## Section-scoped reads (per lane — do not read all of these)

- **All lanes** — `C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/docs/reference/PERFORMANCE-SUMMARY.md` §"Roster leaderboard" — current clean numbers; ✅ rows were re-measured 2026-08-28 and supersede all earlier figures.
- **Lane B** — `.../docs/reference/UNSLOTH-DIRECTION.md` §"Track 1 — tool calling & agentic" — full Tier 1 result + the two scoping corrections.
- **Lane B** — `.../scripts/sweeps/toolcall_cases.json` (read FULL, ~250 lines) — the five cases; new cases go here.
- **Lane B/C** — `.../docs/reference/SERVING-GOTCHAS-STRIX-HALO.md` §(c) and §(d) — tool flags and the three-way distinction. §(a) is the unified-memory bug Lane C must verify.
- **Lane D** — `.../docs/reference/AI-SERVER-GFX906-PLAN.md` (read FULL, ~216 lines) — everything for that lane.
- **Any lane touching results** — the relevant `results/sweeps/2026-08-28-*/manifest.yaml` `caveats:` block. Every run's honest limits are recorded there; read them before quoting a number.

## Blockers

- **Forgejo git is wedged** — 8 commits unpushed. `/api/v1/version` answers in 0.08 s while
  `info/refs` times out, for ALL repos. Disk was extended (80 G, 51% used) but the git
  handler did not recover. Needs `docker restart forgejo` in CT 237. **Do not burn time
  retrying pushes or `git ls-remote` — they hang for minutes.** (One such call hung >1 h
  this session before being killed.)
- **AI server VM 610 unreachable** — no IP, no guest agent, no SSH key. Console-level fix.
- **Jordan's thermal configuration is undocumented** — gates trustworthy AI-server numbers.
- **MI50/gfx906 work is entirely unmeasured.** Everything in the plan doc is research, not
  results.

## Pending system-evolution items

None opened this session.
