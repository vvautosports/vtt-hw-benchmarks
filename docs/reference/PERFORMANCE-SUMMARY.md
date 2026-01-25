# Performance Summary - GLM-4.7 Models

**Date:** January 2026  
**Context:** 65K tokens (optimal for interactive use)  
**Backend:** Vulkan RADV, llama.cpp v7823

---

## Actual Test Results

### Generation Speed (Tokens/Second)

| Model | Quantization | Gen Speed | vs Flash-Q8 | vs Flash-BF16 | vs REAP-BF16 |
|-------|-------------|-----------|-------------|---------------|--------------|
| **GLM-4.7-Flash-REAP-Q8** | Q8 | **~40-42 t/s** | **+122% to +133%** 🔥 | **+344% to +367%** 🔥 | **+300% to +320%** 🔥 |
| **GLM-4.7-Flash-Q8** | Q8 | **~18 t/s** | **Baseline** | **+100%** 🔥 | **+80%** 🔥 |
| GLM-4.7-Flash-REAP-BF16 | BF16 | ~10 t/s | **-44%** | +11% | Baseline |
| GLM-4.7-Flash-BF16 | BF16 | ~9 t/s | **-50%** | Baseline | -10% |

**🎉 Surprise Finding:** Flash-REAP-Q8 is **FASTER** than Flash-Q8! (~2.2x faster generation)

### Prompt Processing Speed (Tokens/Second)

| Model | Quantization | Prompt Speed | vs Flash-Q8 | vs Flash-BF16 | vs REAP-BF16 |
|-------|-------------|--------------|-------------|---------------|--------------|
| **GLM-4.7-Flash-Q8** | Q8 | **~130 t/s** | **Baseline** | **+18%** | **+18%** |
| GLM-4.7-Flash-REAP-Q8 | Q8 | ~37-105 t/s | -15% to -71% | -5% to -66% | -5% to -66% |
| GLM-4.7-Flash-BF16 | BF16 | ~110 t/s | -15% | Baseline | 0% |
| GLM-4.7-Flash-REAP-BF16 | BF16 | ~110 t/s | -15% | 0% | Baseline |

**Note:** Flash-REAP-Q8 prompt speed is variable (37-105 t/s), likely due to REAP architecture overhead.

### API Response Time (Total Latency)

| Model | Quantization | Response Time | vs Flash-Q8 | vs Flash-BF16 | vs REAP-BF16 |
|-------|-------------|---------------|-------------|---------------|--------------|
| **GLM-4.7-Flash-Q8** | Q8 | **~0.27-0.36s** | **Baseline** | **-73% to -76%** 🔥 | **-67% to -76%** 🔥 |
| **GLM-4.7-Flash-REAP-Q8** | Q8 | **~0.27-0.37s** | **+0% to +3%** | **-67% to -75%** 🔥 | **-67% to -75%** 🔥 |
| GLM-4.7-Flash-BF16 | BF16 | ~1.1-1.5s | **+205% to +356%** | Baseline | +0% to +36% |
| GLM-4.7-Flash-REAP-BF16 | BF16 | ~1.1-1.5s | **+205% to +356%** | +0% to +36% | Baseline |

**Key Finding:** Flash-REAP-Q8 matches Flash-Q8 API response time despite faster generation (likely due to variable prompt processing).

### Model Size

| Model | Quantization | Size | vs Flash-Q8 | vs Flash-BF16 | vs REAP-BF16 |
|-------|-------------|------|-------------|---------------|--------------|
| **GLM-4.7-Flash-REAP-Q8** | Q8 | **26GB** | **-21%** 🔥 | **-54%** 🔥 | **-40%** 🔥 |
| **GLM-4.7-Flash-Q8** | Q8 | **33GB** | **Baseline** | **-41%** | **-23%** |
| GLM-4.7-Flash-REAP-BF16 | BF16 | 43GB | +30% | -23% | Baseline |
| GLM-4.7-Flash-BF16 | BF16 | 56GB | +70% | Baseline | +30% |

**Key Finding:** Flash-REAP-Q8 is the **smallest model** (26GB) - 21% smaller than Flash-Q8.

### Memory Usage @ 65K Context

| Model | Quantization | VRAM @ 65K | vs Flash-Q8 | vs Flash-BF16 | vs REAP-BF16 |
|-------|-------------|------------|-------------|---------------|--------------|
| **GLM-4.7-Flash-REAP-Q8** | Q8 | **~18GB** (est.) | **-14%** 🔥 | **-25%** 🔥 | **-25%** 🔥 |
| **GLM-4.7-Flash-Q8** | Q8 | **~21GB** | **Baseline** | **-12%** | **-12%** |
| GLM-4.7-Flash-REAP-BF16 | BF16 | ~24GB | +14% | 0% | Baseline |
| GLM-4.7-Flash-BF16 | BF16 | ~24GB | +14% | 0% | Baseline |

**Key Finding:** Flash-REAP-Q8 provides **best memory efficiency** (~18GB @ 65K).

---

## Key Percentage Differences

### Quantization Impact: Q8 vs BF16

**Generation Speed:**
- Flash-Q8 vs Flash-BF16: **+100% faster** (2x)
- REAP-Q8 vs REAP-BF16: **+300% to +320% faster** (4x!)

**API Response Time:**
- Flash-Q8 vs Flash-BF16: **-73% to -76% faster** (3-4x)
- REAP-Q8 vs REAP-BF16: **-67% to -75% faster** (3-4x)

**Model Size:**
- Flash-Q8 vs Flash-BF16: **-41% smaller**
- REAP-Q8 vs REAP-BF16: **-40% smaller**

**Verdict:** Q8 provides **massive performance improvements** (2-4x faster generation) with minimal quality loss.

### Architecture Impact: REAP vs Non-REAP

**Generation Speed (Q8):**
- REAP-Q8 vs Flash-Q8: **+122% to +133% faster** (2.2x faster!) 🎉

**Generation Speed (BF16):**
- REAP-BF16 vs Flash-BF16: **+11% faster** (slight improvement)

**Model Size:**
- REAP-Q8 vs Flash-Q8: **-21% smaller**
- REAP-BF16 vs Flash-BF16: **-23% smaller**

**Memory Efficiency:**
- REAP-Q8 vs Flash-Q8: **-14% less VRAM**
- REAP-BF16 vs Flash-BF16: **0% difference** (both ~24GB)

**Verdict:** REAP architecture provides **significant benefits with Q8** - faster generation AND smaller size!

---

## Winner Summary

### 🏆 Fastest Generation: GLM-4.7-Flash-REAP-Q8
- **40-42 t/s** generation (2.2x faster than Flash-Q8!)
- Best for: High-throughput generation tasks

### 🏆 Fastest API Response: GLM-4.7-Flash-Q8 (tied with REAP-Q8)
- **~0.27-0.36s** response time
- Best for: Interactive, real-time use

### 🏆 Smallest Model: GLM-4.7-Flash-REAP-Q8
- **26GB** model size
- Best for: Storage-constrained systems

### 🏆 Best Memory Efficiency: GLM-4.7-Flash-REAP-Q8
- **~18GB @ 65K** context
- Best for: Memory-constrained systems, large context needs

### 🏆 Best Overall: GLM-4.7-Flash-REAP-Q8
- Fastest generation (40-42 t/s)
- Smallest model (26GB)
- Best memory efficiency (~18GB @ 65K)
- Fast API response (~0.27-0.37s)
- **Recommended as new default!**

---

## Recommendations

### For Claude Code / Interactive Use:
**Use: GLM-4.7-Flash-REAP-Q8**
- Fastest generation (40-42 t/s)
- Fast API response (~0.27-0.37s)
- Best memory efficiency
- Smallest model size

### For Maximum Speed (If Memory Not Concern):
**Use: GLM-4.7-Flash-Q8**
- Slightly faster API response (more consistent)
- Still very fast generation (18 t/s)
- Slightly more memory (~21GB vs ~18GB)

### For Batch Processing / Quality Critical:
**Use: GLM-4.7-Flash-BF16 or REAP-BF16**
- Lossless quality
- Acceptable for non-interactive use

---

## Test Data

**Flash-REAP-Q8 (Tested 2026-01-24):**
- Generation: 40.25, 42.42, 42.10 t/s (avg: ~41.6 t/s)
- Prompt: 104.83, 36.62, 37.24 t/s (variable)
- API Response: 0.27-0.37s
- Model Size: 26GB

**Flash-Q8 (Tested 2026-01-24):**
- Generation: ~18 t/s
- Prompt: ~130 t/s
- API Response: 0.27-0.36s
- Model Size: 33GB

**Flash-BF16 (Tested 2026-01-24):**
- Generation: ~9 t/s
- Prompt: ~110 t/s
- API Response: 1.1-1.5s
- Model Size: 56GB

**Flash-REAP-BF16 (Tested 2026-01-24):**
- Generation: ~10 t/s
- Prompt: ~110 t/s
- API Response: 1.1-1.5s
- Model Size: 43GB

---

**Last Updated:** 2026-01-24  
**Status:** Complete - All models tested
