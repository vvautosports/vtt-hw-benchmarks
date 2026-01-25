# Claude Code Integration - Testing & Learnings

**Date:** January 2026  
**System:** AMD Ryzen AI Max+ 395 (Strix Halo), Fedora 43  
**Purpose:** Document Claude Code CLI integration with local llama.cpp backend

---

## Executive Summary

Successfully integrated Claude Code CLI with local GLM-4.7 models via llama.cpp server. Key findings:

- **Optimal Configuration:** GLM-4.7-Flash-REAP-23B-Q8 @ 65K context (Vulkan RADV backend)
- **Critical Issues:** Flash Attention incompatible with GLM-4.7-Flash architecture
- **Performance:** 65K context optimal (200K causes severe slowdown)
- **Quantization Impact:** Q8 provides 2x speed improvement over BF16

---

## Integration Process

### Phase 1: Initial Setup

**Goal:** Connect Claude Code CLI to local llama.cpp server

**Steps:**
1. Start `llama-server` with Anthropic-compatible API
2. Configure environment variables to redirect Claude Code
3. Test basic connectivity

**Initial Configuration:**
```bash
# Server
llama-server -m /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  --alias glm-4.7-flash --ctx-size 202752 --host 0.0.0.0 --port 8080 \
  -ngl 999 -fa 1 --no-mmap

# Client
export ANTHROPIC_BASE_URL=http://localhost:8080
export ANTHROPIC_AUTH_TOKEN=vvc-local-access
claude --model glm-4.7-flash
```

**Issues Encountered:**
- ❌ "Assistant response prefill is incompatible with enable_thinking" error
- ❌ Server processing but no token generation (stuck at "Philosophising...")
- ❌ Extremely slow at 200K context (4+ minutes for simple queries)

### Phase 2: API Compatibility Fixes

**Problem:** Claude Code v2.1.19 uses extended thinking features incompatible with GLM models

**Solution:**
```bash
--no-prefill-assistant      # Disables assistant response prefilling
--reasoning-budget 0         # Disables extended thinking mode
```

**Result:** ✅ Claude Code connects and generates tokens successfully

### Phase 3: Performance Optimization

**Problem:** 200K context causes severe performance degradation

**Findings:**
- 65K context: ~1.5s response time ✅
- 200K context: 4+ minutes response time ❌
- Token generation: 0.07-39 t/s (highly variable, mostly very slow at 200K)

**Solution:** Reduce context to 65K for optimal performance

**Optimal Configuration:**
```bash
--ctx-size 65536            # 65K context (optimal performance)
--temp 0.7 --top-p 1.0      # Tool-calling optimized parameters
```

### Phase 4: Flash Attention Discovery

**Problem:** High CPU usage and slow context processing

**Root Cause:** Flash Attention (`-fa 1`) incompatible with GLM-4.7-Flash architecture
- GitHub Issue #18948: High CPU usage with GLM-4.7-Flash
- GitHub Issue #18944: FLASH_ATTN_EXT tensor schema not supported

**Solution:** Disable Flash Attention
```bash
# Remove -fa 1 flag
# Performance: No significant difference at 65K context
```

**Impact:**
- At 65K: No performance difference (both ~1.5s)
- At 200K: Still unusably slow regardless of Flash Attention setting
- **Conclusion:** Context size is the primary bottleneck, not Flash Attention

---

## Quantization Comparison

### GLM-4.7-Flash: Q8 vs BF16

| Metric | Q8 (33GB) | BF16 (56GB) | Improvement |
|--------|-----------|-------------|-------------|
| **Model Size** | 33GB | 56GB | 41% smaller |
| **Generation Speed** | ~18 t/s | ~9 t/s | **2x faster** |
| **Prompt Processing** | ~130 t/s | ~110 t/s | 18% faster |
| **API Response Time** | ~0.27-0.36s | ~1.1-1.5s | **3-4x faster** |
| **Memory @ 65K** | ~21GB | ~24GB | 12% less |
| **Quality** | Near-lossless | Lossless | Negligible difference |

**Verdict:** Q8 is significantly faster with minimal quality loss. **Recommended for Claude Code.**

### GLM-4.7-Flash-REAP: Q8 vs BF16

| Metric | Q8 XL (~20-25GB est.) | BF16 (43GB) | Expected Improvement |
|--------|----------------------|-------------|----------------------|
| **Model Size** | ~20-25GB | 43GB | ~50% smaller |
| **Generation Speed** | ~15-20 t/s (est.) | ~10 t/s | **1.5-2x faster** |
| **Memory Efficiency** | REAP architecture (25% better) | REAP architecture | Same benefit |
| **Quality** | Near-lossless | Lossless | Negligible difference |

**Status:** Q8 XL version being tested (January 2026)

**Expected Verdict:** Q8 XL should provide significant speed improvement while maintaining REAP's memory efficiency benefits.

---

## Backend Comparison

### Vulkan RADV vs ROCm 7.1.1

**Vulkan RADV:**
- ✅ Stable with all models
- ✅ Works with GLM-4.7-Flash
- ✅ No crashes observed
- ✅ Consistent performance
- **Recommendation:** Use for production

**ROCm 7.1.1:**
- ❌ Crashes during model loading with GLM-4.7-Flash
- ⚠️ Requires kernel ≤ 6.18.3-200 (6.18.4+ breaks ROCm)
- ⚠️ Use `rocm7-nightlies` if on newer kernels
- **Recommendation:** Test stability first, not recommended for GLM-4.7-Flash

**Kernel Compatibility:**
- **Stable:** Kernel 6.18.3-200
- **Warning:** Kernel 6.18.4+ breaks all ROCm versions except `rocm7-nightlies`
- **Current System:** 6.18.5-200 (ROCm unstable, Vulkan recommended)

---

## Container Updates & Gotchas

### Critical Warnings (2026-01-10)

**Deprecated Containers:**
- ❌ `rocwmma` - Removed (newer llama.cpp kernels are faster)
- ❌ `rocm-7rc` - Discontinued, obsolete
- ❌ `rocm-7beta`, `rocm-7alpha` - Deprecated
- ✅ `rocm7-nightlies` - Replaces rocm-7alpha (tracks TheRock nightly builds)

**Firmware Warning (2026-01-08):**
- ❌ `linux-firmware-20251125` - Breaks ROCm support (instability/crashes)
- ✅ Check: `rpm -qi linux-firmware | grep Version`
- ✅ Stable: 20251111 or newer (but avoid 20251125)

**Stable Configuration:**
- OS: Fedora 42/43
- Kernel: 6.18.3-200 (6.18.4+ breaks ROCm except nightlies)
- Firmware: 20251111 (or newer, but avoid 20251125)

### Container Refresh

**Always refresh containers before testing:**
```bash
cd FORKS/fork-amd-strix-halo-toolboxes
./refresh-toolboxes.sh llama-vulkan-radv llama-rocm-7.1.1
```

**Updated containers include:**
- Latest llama.cpp fixes
- Performance improvements
- Bug fixes for GLM models

---

## Performance Benchmarks

### Claude Code API Response Times

**Test:** Simple query ("Count 1 to 5", max_tokens=10)

| Model | Context | Backend | Response Time | Gen Speed |
|-------|---------|---------|---------------|-----------|
| GLM-4.7-Flash-Q8 | 65K | Vulkan RADV | 0.27-0.36s | ~18 t/s |
| GLM-4.7-Flash-Q8 | 200K | Vulkan RADV | 4+ minutes | 0.07-39 t/s (unstable) |
| GLM-4.7-Flash-REAP-BF16 | 65K | Vulkan RADV | 1.1-1.5s | ~10 t/s |
| GLM-4.7-Flash-REAP-Q8 | 65K | Vulkan RADV | TBD | ~15-20 t/s (est.) |

**Key Finding:** 65K context is the sweet spot for Claude Code performance.

### Token Generation Speed

**GLM-4.7-Flash-Q8 @ 65K:**
- Prompt processing: ~130 t/s
- Text generation: ~18 t/s
- Total API latency: ~0.27-0.36s

**GLM-4.7-Flash-REAP-BF16 @ 65K:**
- Prompt processing: ~110 t/s
- Text generation: ~10 t/s
- Total API latency: ~1.1-1.5s

**Conclusion:** Q8 quantization provides 2x generation speed improvement.

---

## Recommended Configurations

### Production Setup (Current)

**Model:** GLM-4.7-Flash-REAP-23B-Q8 (when available) or GLM-4.7-Flash-Q8

```bash
# Stop current
pkill -f llama-server

# Start server
nohup toolbox run -c llama-vulkan-radv llama-server \
  -m /mnt/ai-models/GLM-4.7-Flash-REAP-23B-A3B/GLM-4.7-Flash-REAP-23B-A3B-Q8_K_XL.gguf \
  --alias glm-4.7-flash-reap \
  --jinja --ctx-size 65536 \
  --temp 0.7 --top-p 1.0 \
  --fit on --sleep-idle-seconds 300 \
  --host 0.0.0.0 --port 8080 \
  -ngl 999 --no-mmap \
  --no-prefill-assistant --reasoning-budget 0 \
  > /tmp/llama-server-flash-reap.log 2>&1 &

# Configure Claude Code
export ANTHROPIC_BASE_URL=http://localhost:8080
export ANTHROPIC_AUTH_TOKEN=vvc-local-access
claude --model glm-4.7-flash-reap
```

**Key Flags:**
- `--ctx-size 65536` - Optimal performance (not 200K)
- `--temp 0.7 --top-p 1.0` - Tool-calling optimized
- `--no-prefill-assistant` - Claude Code compatibility
- `--reasoning-budget 0` - Disable thinking mode
- **NO `-fa 1`** - Flash Attention incompatible with GLM-4.7-Flash

### Alternative: GLM-4.7-Flash-Q8 (Faster)

```bash
-m /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
--alias glm-4.7-flash
# Then: claude --model glm-4.7-flash
```

**Trade-off:** Faster generation (~18 t/s) but less memory efficient than REAP.

---

## Testing Methodology

### Quantization Comparison Testing

**Standard Test Suite:**
1. **API Response Time:** Simple query, measure total latency
2. **Generation Speed:** Measure tokens/second during generation
3. **Prompt Processing:** Measure tokens/second during prompt processing
4. **Memory Usage:** Monitor VRAM at different context sizes
5. **Quality Check:** Compare output quality (coherence, accuracy)

**Test Command:**
```bash
time curl -s http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"glm-4.7-flash","messages":[{"role":"user","content":"Count 1 to 5"}],"max_tokens":10,"stream":false}' \
  | jq -r '.choices[0].message.content'
```

**Metrics to Record:**
- Total response time (real time)
- Token generation speed (from server logs)
- Prompt processing speed (from server logs)
- Memory usage (from server logs or system monitor)

### Context Size Testing

**Test different context sizes:**
- 4K, 16K, 32K, 65K, 131K, 200K

**Findings:**
- **65K:** Optimal performance (~1.5s response)
- **200K:** Severe degradation (4+ minutes, unstable)

**Recommendation:** Use 65K for Claude Code, reserve 200K for batch processing only.

---

## Lessons Learned

### Critical Discoveries

1. **Flash Attention Incompatibility:** GLM-4.7-Flash architecture doesn't support Flash Attention properly. Always disable `-fa 1` for GLM models.

2. **Context Size Matters:** 200K context causes severe performance degradation. 65K is the practical limit for interactive use.

3. **Quantization Impact:** Q8 provides 2x speed improvement over BF16 with negligible quality loss. Always prefer Q8 when available.

4. **API Compatibility:** Claude Code requires specific flags (`--no-prefill-assistant`, `--reasoning-budget 0`) to work with local backends.

5. **Backend Stability:** Vulkan RADV is more stable than ROCm for GLM models. Use ROCm only if testing shows stability.

6. **Kernel Compatibility:** Newer kernels (6.18.4+) break ROCm. Use `rocm7-nightlies` if ROCm is needed on newer kernels.

### Best Practices

1. **Always refresh containers** before testing to get latest fixes
2. **Test quantization versions** - Q8 often provides significant speedup
3. **Start with 65K context** - increase only if needed and performance is acceptable
4. **Use Vulkan RADV** for production - most stable backend
5. **Monitor performance** - log token speeds and response times
6. **Document gotchas** - firmware, kernel, container versions matter

---

## Future Testing

### Planned Tests

1. **GLM-4.7-Flash-REAP-Q8 XL:** Compare Q8 vs BF16 for REAP architecture
2. **Higher Context Performance:** Test 131K context performance (between 65K and 200K)
3. **ROCm Stability:** Test ROCm 7.1.1 with different models (not GLM-4.7-Flash)
4. **Container Updates:** Test performance improvements from updated containers
5. **Multi-Model Comparison:** Compare Flash-Q8, Flash-REAP-Q8, and REAP-218B for different use cases

### Quantization Priority

**High Priority:**
- ✅ GLM-4.7-Flash-REAP-Q8 XL (in progress)
- ⏸️ GLM-4.7-REAP-218B-Q8 (if available)
- ⏸️ Qwen3-80B-Q6 (sweet spot between Q8 and Q3)

**Medium Priority:**
- Test Q5_K_M versions for models that don't have Q8
- Compare Q6_K vs Q8 for coding tasks (AMD recommends Q6_K for coding)

---

## References

- **GitHub Issues:**
  - [#18948](https://github.com/ggml-org/llama.cpp/issues/18948) - High CPU usage with GLM-4.7-Flash
  - [#18944](https://github.com/ggml-org/llama.cpp/issues/18944) - Flash Attention tensor schema not supported

- **Container Repository:**
  - [amd-strix-halo-toolboxes](https://github.com/kyuz0/amd-strix-halo-toolboxes)

- **Related Documentation:**
  - `AI-MODEL-STRATEGY.md` - Overall model recommendations
  - `GLM-4.7-TESTING.md` - GLM-specific testing guide
  - `MODE-SPECIFIC-TESTING.md` - Mode-specific recommendations

---

**Last Updated:** 2026-01-24  
**Status:** Active - Testing GLM-4.7-Flash-REAP-Q8 XL
