# DRAFT — upstream issue for unslothai/unsloth (do not post without Kal's approval)

**Title:** Studio's GGML_CUDA_ENABLE_UNIFIED_MEMORY=1 corrupts inference on Strix Halo (gfx1151) under b10639-mix — garbage output, reasoning never terminates

## Summary

On AMD Strix Halo (Ryzen AI Max, Radeon 8060S iGPU, 128 GB unified memory, Fedora, ROCm), Unsloth Studio 2026.8.22 with the bundled `b10639-mix-f6f92fe` llama.cpp runtime produces corrupted inference for models launched through `unsloth run`. The studio wrapper auto-sets `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` for unified-memory APUs; with that variable present, generation is numerically broken. Launching with `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` fully resolves it.

This appears to be the same class of report as HF discussion unsloth/Qwen3.8-Flash-Next-GGUF#30 ("Gibberish output on Strix Halo since Unsloth Desktop sets GGML_CUDA_ENABLE_UNIFIED_MEMORY=1"), with a cleaner repro: the corruption reproduces on a template-free greedy `/completion`, so it is independent of chat templates, stop tokens, sampling, and the model family.

## Environment

- HW: AMD Strix Halo (Ryzen AI Max), Radeon 8060S iGPU (gfx1151), 128 GB unified, GTT unlock `gttsize=131072`
- OS: Fedora, ROCm
- Unsloth Studio 2026.8.22, runtime `b10639-mix-f6f92fe` (rocm-gfx1151 prebuilt)
- Models: Qwen3.8-Flash-Next UD-Q4_K_XL (gross corruption), GLM-4.7-Flash UD-Q8_K_XL (subtle corruption)
- Confirmed the serving llama-server process has `GGML_CUDA_ENABLE_UNIFIED_MEMORY=1` in `/proc/<pid>/environ`

## Repro

1. `unsloth run --model .../Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf -H 0.0.0.0 -p 8888`
2. Template-free probe against the internal llama-server port:
   `POST /completion {"prompt": "Counting: one, two, three,", "n_predict": 60, "temperature": 0.0}`
3. Output: `////////////////////////////////////////////////////////////` (pure slash spam).
   Chat-mode symptoms of the same corruption: reasoning never closes at any budget (tested to 32768 tokens), `enable_thinking:false` yields slash spam from token 1.
<!-- markdownlint-disable-next-line MD038 -->
4. Relaunch with `UNSLOTH_DISABLE_UNIFIED_MEMORY=1 unsloth run ...` — same probe returns ` four, five, six, seven, eight, nine, ten.` and chat mode terminates normally (653-token thinking answer, correct result).

## Subtle-corruption datapoint (why this matters beyond one model)

GLM-4.7-Flash UD-Q8_K_XL on the same setup is not gibberish under the variable — it degrades *subtly*: same prompt/seed/sampling that produced a compliant 5-bullet summary on b10472-mix returned a prose paragraph with zero bullets on b10639-mix; with `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` on b10639-mix the compliant 5-bullet structure returns. Silent quality degradation is arguably worse than visible gibberish for anyone benchmarking or serving on this hardware.

Note: the same variable appeared benign under `b10472-mix-4b653db` (clean graded runs 2026-08-27 on studio 2026.8.21) — so this looks like an interaction between the variable and the newer runtime/ROCm path on gfx1151, not the variable alone.

## Suggested direction

- Consider defaulting unified memory OFF for gfx1151 on the affected runtime line, or gating it on a quick numeric self-check at load.
- Documenting `UNSLOTH_DISABLE_UNIFIED_MEMORY=1` prominently for Strix Halo users would help — the off-switch exists (#8651/#8680) but is hard to discover while the failure looks like a model or template bug.
