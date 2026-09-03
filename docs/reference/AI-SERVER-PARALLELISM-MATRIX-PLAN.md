# AI Server (gfx906) — Parallelism Matrix Plan

**Status:** plan only (2026-09-03). Execution is blocked: the AI server (`100.64.0.39`)
is off the mesh (100 % packet loss); someone on site must start `tailscaled`. No Discord
ping was sent — Kal's call.

Constraints and hardware truth live in `AI-SERVER-GFX906-PLAN.md` and are not repeated:
6 × 32 GB gfx906 (5 × Vega II + 1 × Pro VII/MI50, thermally mismatched), 26 GB VM RAM,
no xGMI, `sramecc-` risk on ROCm, **Vulkan first**, and step 0 is still *ask Jordan for the
power/clock/fan configuration*. Evidence lands per `EVIDENCE-LAKEHOUSE-REFERENCE-ARCH.md`
§5 (experiment `hwbench/parallelism`).

## Question

For an agentic workload (Track 2A cells, one model), what serves more useful throughput on
this box: **several independent servers pinned to a subset of GPUs** (2×, 4×) or **one
server spanning all six** (6×)? Secondary: does `--parallel N` inside one server beat N
servers, once the prompt cache is sized correctly.

## Axes

| Axis | Values | Notes |
|---|---|---|
| Topology | `1×6` (one server, `--split-mode layer` over 6 GPUs) · `2×3` · `3×2` · `6×1` (one server per GPU, `--split-mode none --main-gpu i`) | 6×1 is the recommended low-risk baseline in the gfx906 plan |
| `--parallel` per server | 1 · 2 · 4 | slots share the context budget; keep `-c` ≥ 65536 per slot for Hermes/Claude-class agents |
| Prompt cache | `LLAMA_ARG_CACHE_RAM` = 32768 (settled on framework, this session) | never leave at the 8192 default |
| Model | Qwen3-Coder-30B-A3B UD-Q8_K_XL (fits one 32 GB card? **no** — ~33 GB) → use Q6_K or split; second candidate a dense ≤ 30 GB model that fits one card | this is the quant inversion the gfx906 plan warns about; decide the per-card model before the matrix |
| Backend | Vulkan (all cells) · ROCm (only the 1×6 and 6×1 corners, after `sramecc` check) | |

Fixed: `-c 65536` per slot, `--metrics`, pinned llama.cpp build recorded in the manifest, same
fixture set (`config-sweep` + the 4 other Track 2A fixtures), Claude Code as the agent.

## Cells (first pass, 12 cells)

```
topology ∈ {1x6, 2x3, 3x2, 6x1}  ×  parallel ∈ {1, 2, 4}   (Vulkan, cache_ram=32768)
```

Load: for topology `k×g` run `k` concurrent copies of `agent_task_battery.py`, each pointed at
its own server port, each with `--parallel p` clients hitting it (the runner needs a
`--concurrency` flag or `k·p` processes; see "Runner changes"). Total in-flight agents =
`k·p`, compare cells at equal in-flight count (e.g. `1x6/p4` vs `2x3/p2` vs `6x1/p1` … ).

## Measures (per cell, from `/metrics` deltas, never agent-reported)

- Aggregate `predicted_tokens / wall_s` across all servers (box throughput)
- Per-agent wall time and pass rate (`grade.sh`) — throughput that fails cells is worthless
- `prompt_tokens / cell` — the cache-reuse signal (should sit near final context, not 147k)
- Per-GPU: temp, SCLK, power, configured cap (`rocm-smi --showtemp --showpower --showclocks --showmaxpower`) sampled at cell start/end — the thermal confound the gfx906 plan flags
- VM RAM `avail` + GTT curve at 15 s (same sampler as `run_ab.sh`)

## Runner changes needed (hwbench, before the box is up)

1. `agent_task_battery.py`: `--base-url` per invocation (today it discovers 8888 only) and a
   `--concurrency N` that launches N cells in parallel against one server.
2. `serve_pinned.sh` variant for bare llama-server (no Unsloth Studio on the AI server):
   `serve_matrix.sh <topology> <parallel>` launching `k` servers with `--device`/`--main-gpu`
   pinning, `--metrics`, `LLAMA_ARG_CACHE_RAM=32768`, ports 8801..880k, plus residency check
   via `/v1/models` (bare llama-server's `/health` is real, unlike the studio SPA).
3. `manifest.yaml` fields: `topology`, `n_servers`, `parallel`, `gpu_map`, `power_cap_w`,
   `backend`, `cache_ram_mib`.
4. Log each cell to MLflow (`hwbench/parallelism`, parent = matrix run) via the evidence writer
   once it exists; until then the sweep dir + manifest is the record.

## Order of execution once the box answers

0. Jordan: power/clock/fan config. Record it. (gfx906 plan step 0)
1. `rocminfo` sramecc check; confirm six GPUs under Vulkan; `rocm-smi` baseline.
2. Pick the per-card model (Q6_K of the 30B-A3B, or a ≤ 28 GB dense).
3. Single sanity cell: `6x1 / p1`, one fixture — proves pinning, metrics, grading on this box.
4. Full 12-cell matrix, one boot per topology row if memory ratchets like Strix Halo.
5. ROCm corners (`1x6`, `6x1` at `p1`) only if Vulkan numbers make long-context matter.

## Risks

- **Thermal asymmetry** makes "which GPU a server landed on" a confound; randomise `gpu_map`
  across repeats and log it.
- **26 GB VM RAM** — six concurrent model loads will thrash; stagger server starts.
- **Storage** — 142 GB local; one model at a time on the box.
- **Studio absent** — Claude Code needs an Anthropic-compatible endpoint; either run Unsloth
  Studio's proxy on the box (RAM cost) or front bare llama-server with the same shim used for
  the Strix Halo runs. Decide before cell 3.
