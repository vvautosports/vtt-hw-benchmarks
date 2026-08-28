# AI Server (gfx906) — Bring-up Constraints and Early Test Plan

**Node:** `cincy-aiserver-pve-12` (100.64.0.39), Proxmox 9.2.10, Cincinnati.
Formerly `cbus-ai-server-01` / `boxbox-desktop` in Columbus — that Headscale record is stale
(offline since 2026-07-26, still tagged `cbus`) and should be cleaned up.

Assembled 2026-08-28 from direct inspection of the host plus a documentation sweep. Nothing
here has been measured on the hardware yet — this is the plan, not results.

---

## Hardware as it actually is

Two long-open questions from the August infra sessions are now answered:

| | documented as | **actually** |
|---|---|---|
| CPU | "E5-2690 v2 vs v4, awaiting Jordan" | **dual E5-2690 v4**, 56 threads |
| GPUs | "6× uniform MI50 32GB vs mixed" | **mixed**: 5× `1002:66a3` Radeon Pro Vega II + 1× `1002:66a1` Pro VII/MI50 |
| VRAM | 192 GB | **192 GB confirmed** — all six report 32 GB |
| System RAM | "256 GB planned" | **31 GB** — upgrade still pending |

All six are **gfx906** (Vega 20). Radeon Pro Vega II is the Apple Mac Pro MPX module — same
silicon as MI50/Radeon VII, differing in binning and vBIOS, ~1 TB/s HBM2.

**VM 610 `ai-allgpu-ubuntu`**: running, 48 cores, 26 GB RAM, all six GPUs passed through
(`hostpci0`–`hostpci5`), 100 GB disk on `local-lvm`. `agent: 1` is configured but the guest
agent is **not running**, the VM has **no IP** (absent from a full-subnet ARP sweep), and no
SSH key is enrolled. Console-level bring-up needed before anything else.

---

## The four constraints that shape everything

### 1. `sramecc-` segfault — the biggest risk, and it names our exact cards

AMD ships prebuilt rocBLAS/rocSPARSE/rocALUTION kernels only for the `sramecc+` (ECC-on)
ISA variant. A gfx906 card reporting `sramecc-` finds no matching kernel and the runtime
**segfaults rather than erroring cleanly**. The documented affected list is *"Radeon Pro
Vega II, Radeon VII, and some MI50s"* — and this box is **5× Vega II**.

**First diagnostic after VM access, before anything else:**

```bash
rocminfo | grep -o 'amdgcn-amd-amdhsa--gfx906[^ ]*'
```

`gfx906:sramecc-:xnack-` means affected. Fixes are a prebuilt `sramecc-` tarball (ROCm
7.2.3) or a 2–4 hour recompile of the affected libs. **No environment-variable workaround
exists.** Check per-card — the mixed SKUs may not report identically.

Source: <https://forum.level1techs.com/t/guide-prebuilt-fix-rocm-math-libraries-segfault-on-gfx906-with-ecc-disabled-vega-ii-radeon-vii-some-mi50s/252873>

### 2. Low system RAM vs huge VRAM — load-time, not inference-time

26 GB VM RAM against 192 GB VRAM. The relevant failure is during **model load**, not
inference (which lives in VRAM once loaded).

- llama.cpp mmaps the GGUF, but RAM usage empirically tracks model size during load because
  the file is read through once while copying to VRAM ([discussion #19883](https://github.com/ggml-org/llama.cpp/discussions/19883)).
- [Issue #9059](https://github.com/ggml-org/llama.cpp/issues/9059) — "let VRAM-destined
  layers skip RAM staging" — has been **open and unresolved since Aug 2024**.
- **`--no-mmap` makes this WORSE, not better** (forces a full RAM buffer). Counter-intuitive
  and worth stating plainly: keep mmap on, which is the default.
- **`--mlock` would guarantee failure here.** Never use it on this box.
- **`--n-cpu-moe` is the wrong direction** — it trades VRAM for RAM, and RAM is our scarce
  resource, not VRAM. Leave it at 0.

**Working envelope: keep individual model files comfortably under ~20 GB** until larger
loads are tested empirically. There is no published formula for the transient RAM peak, so
this must be measured, starting small and increasing.

### 3. Storage — the working set has nowhere fast to live

| store | free | speed |
|---|---|---|
| `local-lvm` (SATA SSD) | 142 GB | ~500 MB/s local |
| `aiserver-vmstore` (NFS @ 192.168.50.16) | 2.6 TB | **~110 MB/s — `nic0` is 1 GbE** |

`tank`, `hot`, `nvme-storage`, `ai-storage` are all **disabled**: `zpool import` finds
nothing and `/dev/nvme*` does not exist, so **those disks are not in the machine.** Either
they did not make the move from Columbus or they have not been re-added.

A 30 GB model streams from NFS in ~4.5 minutes; 60 GB in ~9. Six workers pulling different
models serialise over one 1 GbE pipe. **Stage the working set on `local-lvm`; treat NFS as
cold archive.** With 192 GB of VRAM and 142 GB of local storage, storage binds first.

---

### 4. Thermal and power — the hidden variable that could invalidate every number

**Flagged by Kal 2026-08-28; Jordan has already dealt with this and his configuration is
NOT captured anywhere in vvt-infrastructure.** The hardware doc records the chassis specs
(6× GPU power connectors, 4 graphics-fan headers, 6+6 phase delivery) but nothing about the
tuning actually applied. **Ask Jordan before benchmarking** — this is the highest-value
missing input on the whole box.

Why it matters more here than on Strix Halo. Six Vega 20 cards at ~300 W stock TDP is up to
~1.8 kW of GPU alone, before two E5-2690 v4s. And the SKUs are **thermally mismatched**:

- **Radeon Pro Vega II** is an Apple MPX module, designed around the Mac Pro's specific
  airflow. In a generic chassis its cooling assumptions do not hold.
- **MI50** is a passively-cooled server card that *requires* high static-pressure chassis
  airflow to survive at all.

Five of one and one of the other, in the same box, is a genuine thermal-engineering problem
— which is presumably exactly why Jordan underclocked/power-limited it to reach a balanced
system.

**The benchmarking consequence is the important part.** If cards are power-limited or
thermally throttling, then t/s is a function of thermal state, not just model and quant.
That is the same class of hidden variable as the unified-memory corruption and the
server-side tool injection: it does not announce itself, it silently makes numbers
incomparable, and it invalidates cross-run comparisons in a way no amount of careful
grading catches.

Concretely, a throttled box produces:
- **run-order dependence** — the first model of a batch runs cool and fast, later ones hot
  and slow, which reads as a model difference and is not one;
- **duration dependence** — long chained-call runs (our `tc_longchain`) heat up far more
  than short single-call ones, so the two are not on the same footing;
- **per-card asymmetry** — with mismatched cooling, GPU 0 and GPU 5 may throttle
  differently, so "which GPU a worker landed on" becomes a confound in the width test.

**Protocol requirements, non-negotiable for any run on this box:**

1. **Record telemetry with every record**, the way `flags`/`env` are recorded today:
   per-card edge/junction temperature, SCLK, and power draw, sampled at start and end of
   each cell (`rocm-smi --showtemp --showpower --showclocks`, or the Vulkan/sysfs
   equivalent under `/sys/class/drm/card*/device/hwmon/`).
2. **Log the configured power cap** (`rocm-smi --showmaxpower`) in the manifest's
   `launch_env` block. A run at a different cap is a different run.
3. **Add a throttle flag to grading**, analogous to `tools_injection_suspect`: if SCLK falls
   materially below its start value or the card reports a throttle status during a cell,
   mark the cell `thermally_suspect`. Flag, do not auto-fail.
4. **Consider a fixed cooldown between cells**, or randomise model order across runs, so
   run-order effects show up as noise rather than as a fake ranking.
5. **Baseline first**: idle temps, then a sustained single-card load, and find where it
   throttles — before any comparative benchmarking. Establish the envelope, then work
   inside it.

Kal's framing is the right one: the goal is a *balanced* system — deliberately
under-powered/under-clocked to sit inside the thermal and acoustic envelope — not maximum
per-card throughput. That means the honest headline for this box is **sustained aggregate
throughput under its real power cap**, not peak single-card t/s. Benchmarks should be
designed to measure the former.

---

## Quant selection — this INVERTS our Strix Halo preference

gfx906 has **no MFMA matrix cores** (those start at CDNA1/gfx908), but it **does** have
`v_dot2_f32_f16`, `v_dot4_i32_i8` and `v_dot8_i32_i4` — so int8 is present, just without
tensor-core acceleration. It has **no bf16** (CDNA2+).

The practical consequence is kernel coverage, not raw capability. The `iacopPBK/llama.cpp-gfx906`
fork wrote dedicated warp-cooperative MMVQ kernels specifically for **Q4_0, Q4_1 and Q8_0**,
plus Q8-optimised flash-attention tiles. K-quants and IQ-quants use more complex block-scale
and lookup structures that never got the same treatment.

> **Prefer Q4_0 / Q4_1 / Q8_0 on this hardware.** Q4_K_M — our default everywhere else — is
> explicitly described as "common but unoptimized on gfx906".

This directly contradicts the Strix Halo roster, where UD-Q4_K_XL and UD-Q8_K_XL are the
house quants. **Do not carry the Strix Halo quant choices over.** The claim that IQ-quants
are specifically slow on Vega 20 is *plausible from the kernel-coverage gap but unverified* —
measure it rather than assuming.

## Backend: Vulkan or ROCm

Both work; the split is workload-dependent. Vulkan wins short-context dense inference and is
far simpler to stand up; ROCm pulls ahead past ~16K context and on MoE. Real numbers from
[discussion #10879](https://github.com/ggml-org/llama.cpp/discussions/10879): MI50 under
Vulkan reaches pp512 ≈1119 t/s, tg128 ≈108 t/s. ROCm on MI50 with flash attention:
pp512 ≈1129, tg128 ≈106 ([#15021](https://github.com/ggml-org/llama.cpp/discussions/15021)).

Note gfx906 is still a valid `GPU_TARGETS` in AMD's current ROCm 7.0 llama.cpp build docs
despite the post-5.7 deprecation, so "no ROCm path" is **wrong** — it is unoptimised, not
absent.

**Recommendation: start on Vulkan.** It sidesteps the `sramecc-` segfault entirely (that is
a rocBLAS problem), and our early tests are short-context. Move to ROCm only when long
context or MoE justifies the setup cost.

## Multi-GPU topology

Per llama.cpp's [`docs/multi-gpu.md`](https://github.com/ggml-org/llama.cpp/blob/master/docs/multi-gpu.md):
`--split-mode layer` (default) is pipeline-parallel and tolerates slow interconnects;
`row` is deprecated; `tensor` wants RCCL and NVLink-class links and is a bad bet here.
There is **no xGMI** on this class of card, so cross-GPU traffic is plain PCIe.

For benchmarking, **N independent servers pinned one-per-GPU** (`--split-mode none
--main-gpu i`, or `--device` isolation) is the low-risk path and matches the box's strength:
**width, not single-stream speed.** Six workers that never contend for a memory bus is
structurally better for the fan-out tier than anything Strix Halo can do — where two
co-resident models cost each other 10–31% (see `2026-08-28-coresidency`).

## Early test plan (in order)

0. **Ask Jordan** what power/clock/fan configuration he applied and why. Undocumented,
   and it determines whether any number from this box is comparable to any other.
1. **Console bring-up** — guest agent, network, SSH key. Blocks everything.
2. **`rocminfo` sramecc check per card**, and confirm all six enumerate under Vulkan.
3. **Thermal baseline** — idle temps, sustained single-card load, find the throttle point
   and the configured power cap. Do this BEFORE any comparative run.
4. **Establish the RAM ceiling empirically** — load a ~5 GB model, then ~10, then ~20,
   watching load-time RAM peak. This calibrates every later decision.
5. **Port the battery** via the plain-llama-server path already built in
   `coresidency_test.py` / `muse_vision_smoke.py` — no unsloth studio here.
6. **Quant ladder on ONE model**: Q4_0 vs Q4_1 vs Q8_0 vs Q4_K_M vs an IQ variant. This is
   the highest-value early experiment because it tests the central claim above and decides
   every subsequent download.
7. **Width test**: 1 vs 2 vs 4 vs 6 concurrent pinned workers, measuring aggregate
   throughput — the direct comparison against Strix Halo co-residency.
8. Only then: small dense models, which the Strix Halo bandwidth verdict retired but which
   may be genuinely competitive on discrete HBM2.
