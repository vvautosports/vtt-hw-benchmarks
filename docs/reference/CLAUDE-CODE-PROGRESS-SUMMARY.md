# Claude Code Integration - Progress Summary

**Date:** January 2026  
**Status:** Functional but performance issues with large prompts  
**Next Step:** Test Roo Code for comparison

---

## What We Accomplished

### ✅ Successfully Integrated Claude Code CLI
- Connected Claude Code to local llama.cpp server
- Fixed API compatibility issues (`--no-prefill-assistant`, `--reasoning-budget 0`)
- Configured environment variables for local backend
- Server running and responding to requests

### ✅ Identified Optimal Configuration
- **Backend:** Vulkan RADV (most stable)
- **Context:** 65K tokens (optimal performance, 200K causes severe slowdown)
- **Flags:** Tool-calling optimized (`--temp 0.7 --top-p 1.0`)
- **Flash Attention:** Disabled (incompatible with GLM-4.7-Flash)

### ✅ Tested Multiple Models
- GLM-4.7-Flash-Q8 (33GB) - Fast for small prompts
- GLM-4.7-Flash-REAP-Q8 (26GB) - Fast for small prompts, struggles with large prompts
- GLM-4.7-Flash-BF16 (56GB) - Too slow for interactive use
- GLM-4.7-Flash-REAP-BF16 (43GB) - Too slow for interactive use

### ✅ Documented Quantization Impact
- Q8 provides **2-4x faster generation** than BF16
- Q8 provides **3-4x faster API responses** than BF16
- Q8 provides **40-54% smaller model size** than BF16
- Quality impact: Negligible (near-lossless)

### ✅ Created Comprehensive Documentation
- `CLAUDE-CODE-INTEGRATION.md` - Full integration process
- `QUANTIZATION-PERFORMANCE-COMPARISON.md` - Detailed comparisons
- `PERFORMANCE-SUMMARY.md` - Test results with percentages
- Updated `AI-MODEL-STRATEGY.md` with quantization focus
- Updated `GLM-4.7-TESTING.md` with REAP models

---

## Key Findings

### Performance Metrics

**Small Prompts (Direct API):**
- Flash-Q8: ~0.27-0.36s response, ~18 t/s generation ✅
- Flash-REAP-Q8: ~0.27-0.37s response, ~40-42 t/s generation ✅ (fastest!)

**Large Prompts (Claude Code System Prompt ~16K tokens):**
- Flash-Q8: First response ~15-30s, subsequent faster
- Flash-REAP-Q8: **2m 20s+ for simple queries** ❌ (unusable)
- Generation speed drops to **0.09 t/s** with large prompts

### Critical Issues Discovered

1. **Flash Attention Incompatibility**
   - GLM-4.7-Flash architecture doesn't support Flash Attention properly
   - GitHub Issues #18948, #18944 document this
   - Solution: Disable `-fa 1` flag

2. **Context Size Performance Degradation**
   - 65K context: Good performance (~1.5s for small queries)
   - 200K context: Severe degradation (4+ minutes, unusable)
   - Recommendation: Use 65K for interactive use

3. **Large Prompt Performance Issue**
   - Claude Code sends ~16K token system prompt
   - Flash-REAP-Q8 struggles with large prompts (0.09 t/s generation)
   - Flash-Q8 handles large prompts better but still slow on first response
   - **This is the main blocker for good Claude Code performance**

4. **Container & Kernel Compatibility**
   - Kernel 6.18.4+ breaks ROCm (except nightlies)
   - Firmware 20251125 breaks ROCm
   - Vulkan RADV is most stable backend
   - Always refresh containers for latest fixes

---

## Current Configuration

**Working Setup:**
```bash
# Server
nohup toolbox run -c llama-vulkan-radv llama-server \
  -m /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  --alias glm-4.7-flash \
  --jinja --ctx-size 65536 \
  --temp 0.7 --top-p 1.0 \
  --fit on --sleep-idle-seconds 300 \
  --host 0.0.0.0 --port 8080 \
  -ngl 999 --no-mmap \
  --no-prefill-assistant --reasoning-budget 0 \
  > /tmp/llama-server-flash-q8.log 2>&1 &

# Client
export ANTHROPIC_BASE_URL=http://localhost:8080
export ANTHROPIC_AUTH_TOKEN=vvc-local-access
claude --model glm-4.7-flash
```

**Performance:**
- Small queries: ~0.3-0.4s ✅
- First response (with system prompt): ~15-30s ⚠️
- Subsequent responses: ~0.3-0.4s ✅

---

## Known Limitations

### Claude Code Performance Issues

1. **Large System Prompt**
   - Claude Code sends ~16K token system prompt on first request
   - This causes slow first response (15-30s for Flash-Q8, 2m+ for REAP-Q8)
   - Subsequent responses are fast once prompt is cached

2. **Model Architecture Mismatch**
   - Flash-REAP-Q8: Fast for small prompts (40-42 t/s) but struggles with large prompts (0.09 t/s)
   - Flash-Q8: Better handling of large prompts but still slow on first response
   - **Root cause:** Large prompt processing overhead

3. **Context Size Trade-offs**
   - 65K: Good performance but may limit some use cases
   - 200K: Unusable performance (4+ minutes for simple queries)
   - **No good middle ground found yet**

---

## Next Steps: Roo Code Testing

### Why Test Roo Code?

1. **Different Architecture**
   - Roo Code may have different prompt handling
   - May send smaller system prompts
   - May have better caching strategies

2. **Performance Comparison**
   - Compare first response time
   - Compare subsequent response time
   - Compare large prompt handling

3. **API Compatibility**
   - Test if Roo Code works with same backend
   - Check if different flags needed
   - Verify tool-calling performance

### Testing Plan for Roo Code

**Setup:**
1. Install Roo Code (if not already installed)
2. Configure to use same llama.cpp backend
3. Test with same models (Flash-Q8, Flash-REAP-Q8)

**Metrics to Compare:**
- First response time (with system prompt)
- Subsequent response time
- Generation speed with large prompts
- Tool-calling performance
- Overall user experience

**Models to Test:**
- GLM-4.7-Flash-Q8 (baseline)
- GLM-4.7-Flash-REAP-Q8 (if Roo handles large prompts better)

**Expected Outcomes:**
- If Roo Code performs better: Document as recommended client
- If similar performance: Both are viable options
- If worse: Stick with Claude Code and optimize further

---

## Recommendations

### For Current Use:
- **Client:** Claude Code (functional but slow first response)
- **Model:** GLM-4.7-Flash-Q8 (best balance for large prompts)
- **Context:** 65K (optimal performance)
- **Backend:** Vulkan RADV (most stable)

### For Future Testing:
1. **Test Roo Code** - May have better large prompt handling
2. **Investigate Prompt Caching** - May improve first response time
3. **Test Smaller Context** - See if 32K or 16K improves large prompt performance
4. **Consider Different Models** - Test if other models handle large prompts better
5. **Optimize System Prompt** - If possible, reduce Claude Code's system prompt size

### Documentation Updates Needed:
- Add Roo Code comparison once tested
- Document large prompt performance issue
- Add recommendations for first response optimization
- Update model recommendations based on Roo Code results

---

## Files Created/Updated

**New Documentation:**
- `CLAUDE-CODE-INTEGRATION.md` - Full integration guide
- `QUANTIZATION-PERFORMANCE-COMPARISON.md` - Quantization analysis
- `PERFORMANCE-SUMMARY.md` - Test results with percentages
- `CLAUDE-CODE-PROGRESS-SUMMARY.md` - This file

**Updated Documentation:**
- `AI-MODEL-STRATEGY.md` - Added quantization comparison section
- `GLM-4.7-TESTING.md` - Added Flash-REAP models and quantization comparison

**Configuration Files:**
- `.claude/commands/check-local-llm.md` - Quick reference (needs update with findings)

---

## Key Learnings

1. **Quantization Matters:** Q8 provides massive performance improvements (2-4x) with minimal quality loss
2. **Architecture Matters:** REAP is fast for small prompts but struggles with large prompts
3. **Context Size Matters:** 65K is optimal, 200K is unusable
4. **Prompt Size Matters:** Large system prompts cause severe performance degradation
5. **Backend Stability:** Vulkan RADV is most reliable, ROCm has compatibility issues
6. **Container Updates:** Always refresh containers for latest fixes

---

## Open Questions

1. **Why does Flash-REAP-Q8 struggle with large prompts?**
   - Architecture overhead?
   - Memory management?
   - KV cache issues?

2. **Can we optimize large prompt processing?**
   - Prompt caching improvements?
   - Different context management?
   - Model-specific optimizations?

3. **Will Roo Code perform better?**
   - Different prompt handling?
   - Better caching?
   - Smaller system prompts?

4. **Are there other models that handle large prompts better?**
   - Qwen models?
   - Different architectures?
   - Different quantizations?

---

**Last Updated:** 2026-01-24  
**Next Action:** Test Roo Code for comparison
