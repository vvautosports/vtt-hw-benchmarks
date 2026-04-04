# HP ZBook Ultra G1a (Kal) — LM Studio CPU-Only Baseline

**Test Date:** 2026-03-22
**Tester:** Kal
**LM Studio Version:** 0.4.7
**llama.cpp Engine:** CPU llama.cpp (Windows) v2.8.0
**Mode:** CPU-only (iGPU not available — see GPU Notes below)

---

## System Configuration

**CPU:** AMD Ryzen AI Max+ Pro 395 (16P+16E cores, 32 threads)
**RAM:** 128GB total, **112GB system / 16GB GPU UMA** (BIOS adjusted for CPU inference)
**GPU:** AMD Radeon 8060S (gfx1151, RDNA 3.5) — display only, not used for inference
**OS:** Windows 11 Pro 10.0.26200
**Power:** Plugged in, High Performance

### BIOS Settings
- UMA Frame Buffer: **16GB** (changed from 96GB to maximize system RAM for CPU inference)
- Resizable BAR: Enabled
- Above 4G Decoding: Enabled

---

## LM Studio Settings (Optimized)

### Load Tab (per-model)
| Setting | Value | Notes |
|---------|-------|-------|
| CPU Thread Pool Size | 16 | Max available in LM Studio |
| Evaluation Batch Size | 2048 | Increased from 512 for faster prompt processing |
| Max Concurrent Predictions | 1 | Single-user, no parallelism overhead |
| Unified KV Cache | ON | |
| Flash Attention | ON | Reduces memory pressure |
| Keep Model in Memory | ON | Avoids reload latency |
| Try mmap() | ON | Memory-mapped file loading |
| Number of Experts | 8 | Default for MoE models (active experts per token) |
| GPU Offload | 0 layers | iGPU not functional for inference |

### Inference Tab (per-model)
| Setting | Value | Notes |
|---------|-------|-------|
| Temperature | 0.1 | Low for deterministic code generation |
| CPU Threads | 16 | Matches thread pool |
| Top K Sampling | 20 | Reduced from 40 for speed |
| Top P Sampling | 0.9 | Reduced from 0.95 |
| Min P Sampling | 0.1 | Increased from 0.05, cuts tail faster |
| Repeat Penalty | 1.1 | Default |
| Context Overflow | Truncate Middle | |

### Speculative Decoding
- Not available for Qwen3.5 models (no compatible draft model)
- Available for other architectures — use Gemma 3 4B as draft model

---

## Benchmark Results

**Prompt:** "Write a Python function that reads a JSON file, filters entries where status is active, and writes the filtered results to a new file. Include error handling."
**Max tokens:** 500

### Results Table

| Model | ID | Type | Active Params | RAM (est.) | Tokens | Time | t/s | Notes |
|-------|----|------|--------------|-----------|--------|------|-----|-------|
| Gemma 3 4B | google/gemma-3-4b | Dense | 4B | ~3GB | 500 | 30.0s | **16.7** | Pre-optimization baseline |
| Qwen3.5-9B | qwen3.5-9b | Dense | 9B | ~14GB | 500 | 116.0s | **4.3** | Pre-optimization |
| Qwen3.5-35B-A3B | qwen3.5-35b-a3b | MoE | ~3B (of 35B) | ~24GB | 500 | 101.3s | **4.9** | Pre-optimization |
| Qwen3.5-35B-A3B | qwen3.5-35b-a3b | MoE | ~3B (of 35B) | ~24GB | 500 | 51.4s | **9.7** | **Optimized** (flash attn, batch 2048) |

### Pending Tests
| Model | ID | Type | Active Params | RAM (est.) | Status |
|-------|----|------|--------------|-----------|--------|
| Qwen3.5-122B-A10B | — | MoE | ~10B (of 122B) | ~65GB Q4 | Downloading |
| Qwen3-Coder-Next | qwen3-coder-next | — | — | — | Available, untested |
| Qwen3-Next-80B-A3B | qwen3-next-80b-a3b-instruct | MoE | ~3B (of 80B) | — | Available, untested |
| GLM-4.7-Flash | glm-4.7-flash | Dense | — | ~33GB | Available, untested |
| Qwen3-30B-A3B | qwen3-30b-a3b-thinking-2507 | MoE | ~3B | — | Available, untested |
| GLM-4.7-Flash-REAP-23B-A3B | glm-4.7-flash-reap-23b-a3b | MoE | ~3B | — | Available, untested |

---

## GPU Notes (iGPU Not Functional for Inference)

### Problem
LM Studio 0.4.7 cannot use the AMD Radeon 8060S (gfx1151) for inference on Windows:
- **ROCm engine:** "GPU survey unsuccessful" — rocBLAS TensileLibrary.dat for gfx1151 missing
- **Vulkan engine:** "Error surveying hardware" — known >64GB allocation bug + driver detection issues
- **CUDA engine:** Non-compatible (no NVIDIA GPU)

### Key Issues
- [LM Studio #806](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/806) — ROCm on Ryzen AI Max+ 395
- [LM Studio #1048](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1048) — Vulkan regression on gfx1151
- [LM Studio #1269](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1269) — ROCm gfx1151 data files missing
- [llama.cpp #16575](https://github.com/ggml-org/llama.cpp/issues/16575) — Vulkan >64GB allocation bug

### Path to GPU Inference
1. **CachyOS dual-boot** (best path) — ROCm + `HSA_OVERRIDE_GFX_VERSION=11.5.1`, proven 40+ t/s on 30B
2. **ROCm library replacement** — [likelovewant guide](https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU/wiki) for gfx1151 on Windows
3. **Ollama on Windows** — better gfx1151 ROCm support than LM Studio currently

---

## Models Available in LM Studio

Full model list as of 2026-03-22 (all from Unsloth unless noted):
1. qwen3.5-35b-a3b
2. qwen3.5-9b
3. qwen3.5-0.8b
4. qwen3-coder-next
5. qwen3-next-80b-a3b-instruct
6. glm-4.7-flash
7. qwen3-30b-a3b-thinking-2507
8. glm-4.7-flash-reap-23b-a3b
9. google/gemma-3-4b (baseline)
10. text-embedding-nomic-embed-text-v1.5
11. qwen3.5-122b-a10b (downloading, Q4)

---

## Offline Dev Readiness

### What Works Now
- LM Studio serving OpenAI-compatible API on localhost:1234
- CPU inference at 9.7 t/s on Qwen3.5-35B-A3B (usable for code generation)
- Multiple models hot-swappable without restart

### TODO
- [ ] Configure Claude Code to use LM Studio as provider
- [ ] Configure Roo Code / OpenCode for local model
- [ ] Test devcontainer build (Docker Desktop + WSL2)
- [ ] Export GitHub issues for offline task tracking
- [ ] Run full benchmark suite on all available models
- [ ] Test 122B-A10B when download completes
- [ ] Verify full offline simulation (WiFi off)
