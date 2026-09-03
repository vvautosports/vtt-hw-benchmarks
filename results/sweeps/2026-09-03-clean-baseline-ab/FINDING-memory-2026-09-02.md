# The OOM is not context size — it is the kernel/GPU memory path

Captured 2026-09-02 ~21:22 MDT, during Phase A of the overnight chain,
box up 4h53m (all of todays runs on this boot).

## What #12 currently claims
"Auto-selected ctx 202752 x --parallel 4 is the memory bomb; pin -c and
--parallel 1." That mitigation was applied and **it did not work**.

## What actually happened on the pinned run
Serve verified pinned on the live child: `-c 65536 --parallel 1`.
Memory still climbed 43 GB -> 119 GB during ONE agent cell, and at 21:05:32
a GLOBAL OOM killed the unsloth studio PARENT (pid 100025), plus gjs and
xdg-desktop-portal. Port 8888 died, so cells 2-5 returned
"No running Unsloth server found" in <1.5s each (agent_exit=1).

## The attribution that matters
While `free` reported 107-108 GB used with only 7 GB free:

| source                      | value    |
|-----------------------------|----------|
| llama-server RSS            | 4.3 GB   |
| unsloth RSS                 | 0.95 GB  |
| claude RSS                  | 0.3 GB   |
| **SUnreclaim (kernel slab)**| **31.7 GB** |
| amdgpu mem_info_gtt_used    | 39.3 GB  |
| Shmem                       | 0.75 GB  |

No process accounts for the usage. ~32 GB sits in **unreclaimable kernel
slab** and ~39 GB in **GPU GTT** — neither is freeable under pressure, which
is exactly why the OOM killer fires with no single guilty process and picks
arbitrary victims (a desktop portal, the studio parent).

The llama-slots cache was ruled out: `~/.unsloth/studio/cache/llama-slots`
is empty (0 bytes, 0 files).

## Why this changes the plan
- Pinning context is not the fix. Context was never the bomb.
- Prime suspect is the GPU memory path on this APU. `UNSLOTH_DISABLE_UNIFIED_MEMORY=1`
  is set on every serve here (it is the b10639 regression fix). Disabling
  unified memory plausibly forces separate GTT allocations instead of pages
  shared with the CPU — i.e. paying twice on an APU whose "VRAM" IS system RAM.
  That is a HYPOTHESIS, not yet tested.
- SUnreclaim was ~flat across two samples a minute apart, so it may accumulate
  per serve-load/teardown rather than continuously. Multiple load/unload cycles
  across a boot would then ratchet it up until a run cannot fit.

## Next tests (cheapest first)
1. Read `/proc/slabinfo` as root to name the growing cache (needs sudo; sudoers
   here has use_pty so it will not work over non-interactive ssh).
2. Reboot, then run ONE battery on a clean boot and watch SUnreclaim. If a clean
   boot gets 5/5, the ratchet is confirmed and the fix is "one boot per battery".
3. A/B `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` vs unset on the same fixture, watching
   mem_info_gtt_used. Note: unsetting may reintroduce the b10639 regression, so
   check the runtime build first.

---

# CORRECTION (2026-09-03 06:47) — the "unreclaimable slab leak" above is WRONG

After the model unloaded and the box sat idle overnight:

| metric      | during run | now (idle) |
|-------------|-----------|------------|
| SUnreclaim  | 31.7 GB   | **0.58 GB** |
| amdgpu gtt_used | 39.3 GB | **0.0 GB** |
| Mem used    | 107 GB    | **3 GB**   |
| MemAvailable| 16 GB     | **120 GB** |

It ALL released. So the slab was just the amdgpu/TTM backing for the resident
model, freed correctly on unload. There is no leak and no ratchet, and the
"one boot per battery" idea is unnecessary. Disregard the hypothesis section.

# What the Phase A curve actually shows

56 samples, 21:20:27 -> 21:30:27:

- **start:  used=103.0 GB  avail=24.5 GB**  <- already nearly full BEFORE the cell
- peak 21:24:55: used=127.3 GB  **avail=0.24 GB**  (llama-server RSS only 6.4 GB)
- end 21:30:27: used=78.7 GB  avail=48.9 GB

The cell did not consume 76 GB. The box ENTERED Phase A with only ~24 GB of
headroom because a previous model was still resident in GTT. Stacked/leftover
residency across serve relaunches is the real mechanism: each battery starts
from whatever the last one left behind, until one cell tips it over.

That reframes it as an OPERATIONAL bug (we never verified a clean baseline or a
single resident model before launching), not a kernel or context-size bug.

# Correct next test
From the current genuinely clean baseline (3 GB used, 120 GB available, gtt 0),
launch ONE pinned serve, ASSERT exactly one llama-server child and avail > 100 GB,
then run the 5-cell battery and watch the curve.
