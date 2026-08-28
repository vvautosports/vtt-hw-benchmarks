# Continuation — AI server (gfx906) bring-up (Lane D)
**Generated:** 2026-08-28
**Scope:** `cincy-aiserver-pve-12` ONLY. Does not touch the Framework, the HP, or the forge.

---

## ▶ FIRST MOVE — re-establish context in a SUBAGENT

Spawn ONE Explore subagent (cheap tier is fine) to read
`C:/Users/kalman9/Documents/vvc/vtt-hw-benchmarks/.claude/worktrees/unsloth-direction/docs/reference/AI-SERVER-GFX906-PLAN.md`
**in full** (~216 lines) and run the Startup block, returning a ≤2K-word digest. That plan
doc is the substance of this lane — everything below is orientation around it. Never read it
in the main thread. (Doctrine: vvt-omnigent ADR 0005.)

## ⚠️ Two rules before you touch anything

1. **Kal drives Proxmox and host-side configuration manually.** He said so explicitly on
   2026-08-28. Diagnose freely and read freely — but propose host/VM changes and let him
   execute, rather than running them yourself. Read-only inspection over SSH is fine.
2. **A parallel session may be running Framework/Strix Halo work.** Different machine, so no
   conflict — but if you commit to this repo, use your own worktree:
   `git -C <main clone> worktree add .claude/worktrees/<name> feature/unsloth-direction`

## Startup block (read-only; subagent runs this)

```bash
ssh root@100.64.0.39 'hostname; pveversion | head -1; qm status 610 --verbose | grep -E "^status|^uptime"; pct exec 610 -- true 2>/dev/null || echo "(610 is a VM, not a CT)"'
ssh root@100.64.0.39 'lspci -nn | grep -i "Vega 20"; free -g | awk "NR==2{print \"RAM total \" \$2 \"G\"}"; pvesm status'
ssh root@100.64.0.39 'qm agent 610 ping 2>&1 | head -2'   # expect "not running" until bring-up
```

## The box, as it actually is (verified 2026-08-28, NOT as documented)

**`cincy-aiserver-pve-12`, 100.64.0.39**, Proxmox 9.2.10, Cincinnati. Reachable as
`root@100.64.0.39`. It moved from Columbus and was rebuilt as a Proxmox node — the old
Headscale record `cbus-ai-server-01` / `boxbox-desktop` (100.64.0.16, tag:cbus) is **stale,
offline since 2026-07-26**, and searching for it wastes a round-trip. Worth cleaning up.

`vvt-infrastructure` documents three things wrong; direct inspection settled two questions
that had been "awaiting Jordan" since August:

| | documented | **actual** |
|---|---|---|
| CPU | "v2 vs v4?" | **dual E5-2690 v4**, 56 threads |
| GPUs | "6× uniform MI50?" | **5× Radeon Pro Vega II (`1002:66a3`) + 1× Pro VII/MI50 (`1002:66a1`)** |
| VRAM | 192 GB | **192 GB confirmed** (all six 32 GB) |
| System RAM | "256 GB planned" | **31 GB** — upgrade still pending |

All six are gfx906. **VM 610 `ai-allgpu-ubuntu`** has all six passed through
(`hostpci0`–`hostpci5`), 48 cores, 26 GB RAM, 100 GB disk — running, but **no IP** (absent
from a full-subnet ARP sweep), guest agent **not running** despite `agent: 1`, and **no SSH
key enrolled**.

## Ordered plan — steps 0–2 are Kal's

0. **Ask Jordan about the thermal/power tuning.** He solved it; it is recorded nowhere in
   `vvt-infrastructure`. This is the highest-value missing input on the whole box — see the
   next section for why it is a benchmark-validity issue and not just an ops detail.
1. **Console bring-up of VM 610** — guest agent, network, SSH key. Blocks everything else.
2. **Decide on the missing disks.** `tank`, `hot`, `nvme-storage`, `ai-storage` are all
   disabled; `zpool import` finds nothing and `/dev/nvme*` does not exist, so those disks are
   **not in the machine**. With 192 GB VRAM against 142 GB of local SSD, storage binds first.
3. **`rocminfo | grep -o 'amdgcn-amd-amdhsa--gfx906[^ ]*'` per card.** `gfx906:sramecc-`
   means the documented rocBLAS segfault applies — and the affected list explicitly names
   Radeon Pro Vega II, of which this box has five. No env-var workaround exists.
   **Start on Vulkan, which sidesteps it entirely** and is fine for short-context dense work.
4. **Thermal baseline** — idle temps, then sustained single-card load, find the throttle
   point and the configured power cap. Before any comparative run.
5. **RAM ceiling, empirically** — load ~5 GB, then ~10, then ~20, watching the *load-time*
   RAM peak. Keep models under ~20 GB until this is measured.
6. **Quant ladder on ONE model — the highest-value early experiment.** Q4_0 vs Q4_1 vs Q8_0
   vs Q4_K_M vs an IQ variant. It tests the central claim below and decides every later
   download. **Do not bulk-download models before this runs.**
7. **Width test** — 1 vs 2 vs 4 vs 6 concurrent workers pinned to disjoint GPUs, measuring
   *aggregate* throughput. This is the direct comparison against Strix Halo co-residency.
8. Only then: small dense models, which the Strix Halo bandwidth verdict retired but which
   may be genuinely competitive on discrete HBM2.

## The four constraints (full detail in the plan doc)

1. **`sramecc-` rocBLAS segfault** — names Radeon Pro Vega II specifically; this box has 5.
2. **Load-time RAM, not inference RAM** — 26 GB VM RAM vs 192 GB VRAM.
   **`--no-mmap` makes it WORSE** (forces a full RAM buffer); **`--mlock` guarantees
   failure**; **`--n-cpu-moe` is backwards here** (trades VRAM for RAM, and RAM is what is
   scarce). llama.cpp#9059 — skip RAM staging for VRAM-destined layers — has been open since
   Aug 2024, so this is unsolved upstream.
3. **Storage** — 142 GB local SSD; 2.6 TB NFS behind a **1 GbE** `nic0` (~110 MB/s → ~4.5 min
   for a 30 GB model). Stage the working set locally; treat NFS as cold archive.
4. **Thermal/power** — six Vega 20 at ~300 W is ~1.8 kW before the CPUs, and the SKUs are
   **thermally mismatched**: Vega II is an Apple MPX module built for Mac Pro airflow, MI50
   is passive and needs high static pressure.

### Why thermal is a benchmark-validity issue

If cards throttle, t/s becomes a function of thermal state rather than model and quant —
the same class of hidden variable as the unified-memory corruption and the server-side tool
injection that invalidated large parts of this corpus. It would show up as **run-order
dependence** (first model cool and fast, later ones hot and slow, reading as a model
difference), **duration dependence** (long chained runs heat far more than short ones), and
**per-card asymmetry** that would confound the width test specifically.

So, non-negotiable for any run on this box: record per-card temp/SCLK/power with every
record the way `flags`/`env` are recorded today; log the power cap in the manifest's
`launch_env`; add a `thermally_suspect` grading flag analogous to `tools_injection_suspect`
(flag, do not auto-fail); and either fix a cooldown between cells or randomise model order.

**Kal's framing is the right one:** the goal is a *balanced* system — deliberately
under-clocked to sit inside its thermal and acoustic envelope — so the honest headline is
**sustained aggregate throughput under the real power cap**, not peak single-card t/s.

## Quant guidance INVERTS the Strix Halo house style

gfx906 has `v_dot4_i32_i8` (int8 is present) but **no MFMA matrix cores** and no bf16. The
practical issue is kernel coverage: the community gfx906 forks wrote dedicated warp-cooperative
MMVQ kernels for **Q4_0, Q4_1 and Q8_0**, while Q4_K_M is described as "common but
unoptimized". IQ-quants being slow here is **plausible but unverified** — measure it.

> **Do not carry UD-Q4_K_XL / UD-Q8_K_XL over from the Strix Halo roster.** That is exactly
> what step 6 exists to settle.

Note also that "gfx906 has no ROCm path" is **wrong** — it is unoptimised, not absent; still
a valid `GPU_TARGETS` in AMD's current ROCm 7.0 llama.cpp docs.

## Harness reuse — ~80% ports already

The battery talks to an OpenAI-compatible `/v1/chat/completions`, which plain `llama-server`
serves. `run_one()` and `run_tool_case()` port **as-is**; only the launch/kill layer is
Unsloth-specific. Two files already drive a plain llama-server and are the template:

- `scripts/sweeps/coresidency_test.py` — launches llama-server directly on chosen ports
- `scripts/testing/muse_vision_smoke.py` — same pattern, plus an mmproj

Neither uses `unsloth run`, and neither sets `GGML_CUDA_ENABLE_UNIFIED_MEMORY` (a Strix Halo
concern that does not apply here).

## Comparison target

Strix Halo co-residency: two models share ONE memory bus, so concurrent generation costs
−10% / −31% (`results/sweeps/2026-08-28-coresidency/manifest.yaml`). **On six discrete GPUs
with disjoint placement there is no shared bus, so contention should approach zero** — that
is the structural advantage this box has for the fan-out tier, and step 7 is what proves or
disproves it. Its value is **width, not single-stream speed**.

## Blockers

- **VM 610 unreachable** — no IP, no guest agent, no SSH key. Console-level; Kal drives.
- **Jordan's thermal configuration undocumented** — gates trustworthy numbers.
- **Nothing on this hardware has been measured.** The plan doc is research, not results.
- Repo has commits unpushed (Forgejo git handler wedged, another lane owns it). Commit
  locally; do not retry pushes here.
