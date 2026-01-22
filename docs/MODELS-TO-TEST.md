# Models to Test - January 2026 Roadmap

Complete list of models to evaluate on AMD Strix Halo for coding assistance.

---

## Currently Tested (Baseline Complete) ✅

### GLM Family (Zhipu AI)
- **GLM-4.7-Flash-Q8** (33GB) - ✅ Tested - **Current champion**
- **GLM-4.7-Flash-BF16** (56GB) - ✅ Tested
- **GLM-4.7-REAP-218B-Q3** (92GB) - ✅ Tested - Best reasoning

### Qwen Family (Alibaba)
- **Qwen3-Next-80B-Q8** (87GB) - ✅ Tested
- **Qwen3-235B-Q3** (97GB) - ✅ Tested

### GPT Family (Open Source)
- **GPT-OSS-20B-F16** (13GB) - ✅ Tested - Fastest small model
- **GPT-OSS-120B** (size TBD) - ⏸️ Not tested yet

**Verdict so far:** GLM-4.7-Flash-Q8 winning for overall coding, GPT-OSS-20B for speed

---

## High Priority - Must Test 🔥

### GPT-OSS-120B (Larger GPT open source)

**GPT-OSS-120B** (Expected ~120GB Q3/Q4)
- **Why test:** 6x larger than GPT-OSS-20B
- **Expected advantage:** Much better quality while maintaining GPT architecture
- **Trade-off:** Slower than 20B but potentially best GPT reasoning
- **Use case:** When GPT-20B quality insufficient but want GPT family
- **Memory:** Tight fit at 128GB (Q3/Q4 needed)
- **Priority:** ⭐⭐⭐⭐
- **Note:** If it has GPT-20B speed scaling, could be excellent

### Qwen 3 Coder Series (Specialized for code)

**Qwen3-Coder-30B** (Expected ~30-40GB Q8)
- **Why test:** Specialized for coding (vs general GLM)
- **Expected advantage:** Better code completion, fewer hallucinations
- **Potential winner if:** Code quality > GLM-Q8
- **Context:** ~128K standard
- **Status:** Need to download and test
- **Priority:** ⭐⭐⭐⭐⭐ (highest)

**Qwen3-Coder-14B** (Expected ~15-20GB Q8)
- **Why test:** Faster than 30B, still code-specialized
- **Expected advantage:** Speed similar to GPT-OSS-20B but code-focused
- **Potential winner if:** Quality > GPT-OSS + speed > GLM-Q8
- **Priority:** ⭐⭐⭐⭐

**Qwen3-Coder-70B** (Expected ~70-80GB Q8)
- **Why test:** Best Qwen coder model
- **Trade-off:** Slower than GLM-Q8, but potentially better code quality
- **Priority:** ⭐⭐⭐

---

### Llama 4 Scout Series (Long Context)

**Llama-4-Scout-17B** (Expected ~20GB Q4, ~35GB Q8)
- **Why test:** Up to **1M token context** (vs GLM's 202K)
- **Expected advantage:** Entire massive codebases in context
- **Trade-off:** Smaller param count (17B vs GLM 30B)
- **Use case:** When context > quality
- **Priority:** ⭐⭐⭐⭐⭐ (unique capability)
- **Note:** 1M context is slow but possible on 128GB system

**Llama-4-Scout-70B** (Expected ~80GB Q4)
- **Why test:** Best balance of size and context
- **Expected advantage:** 1M context + better reasoning than 17B
- **Memory:** Tight fit at 128GB
- **Priority:** ⭐⭐⭐⭐

---

### DeepSeek Coder V3 (Strong coding model)

**DeepSeek-Coder-V3-33B** (Expected ~35GB Q8)
- **Why test:** Competitive with Qwen Coder
- **Expected advantage:** Good code quality, reasonable speed
- **Recent:** Late 2025 release, very strong
- **Priority:** ⭐⭐⭐⭐

---

### Mistral Large 2 (General purpose, strong coder)

**Mistral-Large-2-123B** (Expected ~120GB Q3)
- **Why test:** Top-tier general model, very strong at code
- **Trade-off:** Barely fits in 128GB, slower inference
- **Expected advantage:** Best reasoning + code quality
- **Use case:** When you need absolute best (Architect mode)
- **Priority:** ⭐⭐⭐

**Mistral-Nemo-12B** (Expected ~13GB Q8)
- **Why test:** Fast baseline alternative to GPT-OSS-20B
- **Expected advantage:** More recent training, better instruction following
- **Priority:** ⭐⭐⭐

---

### Gemma 2 Series (Google)

**Gemma-2-27B** (Expected ~28GB Q8)
- **Why test:** Google's open model, decent at code
- **Expected:** Good but likely not beating GLM-Q8
- **Priority:** ⭐⭐

**Gemma-2-9B** (Expected ~10GB Q8)
- **Why test:** Very fast baseline
- **Expected:** Faster than GPT-OSS-20B but lower quality
- **Priority:** ⭐⭐

---

### Yi Coder (01.AI)

**Yi-Coder-34B** (Expected ~35GB Q8)
- **Why test:** Strong Chinese company, good at code
- **Expected:** Competitive with Qwen Coder
- **Priority:** ⭐⭐⭐

---

## Medium Priority - Worth Testing

### Qwen2.5 Variants

**Qwen2.5-72B-Instruct** (Expected ~75GB Q8)
- Older generation but proven
- Priority: ⭐⭐

**Qwen2.5-32B-Instruct** (Expected ~33GB Q8)
- Good balance, but Qwen3 likely better
- Priority: ⭐⭐

### StarCoder Series

**StarCoder2-15B** (Expected ~16GB Q8)
- Specialized for code
- From BigCode project
- Priority: ⭐⭐⭐

**StarCoder2-3B** (Expected ~4GB Q8)
- Ultra-fast for simple completions
- Priority: ⭐⭐

### Codestral (Mistral's code model)

**Codestral-22B** (Expected ~23GB Q8)
- Mistral's code-specialized model
- Priority: ⭐⭐⭐

---

## Low Priority - Skip Unless Specific Need

### Phi-3/3.5 Series (Microsoft)
- Small models (3-14B)
- Fast but lower quality
- Already have GPT-OSS-20B for fast baseline

### Smaller Gemma models
- Gemma-2-2B
- Too small for serious coding

### Older Llama models
- Llama 3.1/3.2
- Superseded by Llama 4

---

## Apriel Model - Need More Info

**Status:** Mentioned but need details
- Model name/size?
- Specialization?
- Release date?
- **Action:** Research and add to roadmap

---

## Expected Winners by Category

### Speed Category (< 2 sec responses)
**Current:** GPT-OSS-20B (1135/46 t/s)
**Challengers:**
1. Mistral-Nemo-12B (might be faster)
2. Gemma-2-9B (might be faster but lower quality)
3. StarCoder2-3B (ultra-fast but limited)

**Likely Winner:** GPT-OSS-20B (already excellent)

---

### Balanced Category (Speed + Quality + Context)
**Current:** GLM-4.7-Flash-Q8 (801/37.5 t/s, 202K context)
**Challengers:**
1. **Qwen3-Coder-30B** ⭐ (specialized for code, might beat GLM)
2. Llama-4-Scout-17B (1M context!)
3. DeepSeek-Coder-V3-33B (strong recent model)
4. Yi-Coder-34B (competitive)

**Likely Winner:**
- **Qwen3-Coder-30B** if code quality significantly better
- **GLM-4.7-Flash-Q8** remains champion if Qwen not noticeably better

---

### Reasoning Category (Complex problems)
**Current:** GLM-4.7-REAP-218B (218B params)
**Challengers:**
1. Mistral-Large-2-123B (might be better reasoner)
2. Qwen3-235B (already tested, similar)
3. Llama-4-Scout-70B (if context helps reasoning)

**Likely Winner:** REAP-218B or Mistral-Large-2 (neck and neck)

---

### Massive Context Category (>200K tokens)
**Current:** GLM-4.7-Flash-Q8 (202K max)
**Challengers:**
1. **Llama-4-Scout-17B** (1M context!) ⭐⭐⭐
2. Llama-4-Scout-70B (1M context + better reasoning)

**Clear Winner:** Llama-4-Scout series (unique capability)

**Use case:** When you need entire massive codebases (Linux kernel, LLVM, etc.)

---

## Recommended Testing Priority

### Phase 1: High-Impact Models (Test First)

1. **Qwen3-Coder-30B** - Most likely to dethrone GLM-Q8
2. **Llama-4-Scout-17B** - Unique 1M context capability
3. **GPT-OSS-120B** - Much larger GPT, potential quality leader
4. **DeepSeek-Coder-V3-33B** - Strong recent coder

**Why:** These have highest chance of beating current champions

### Phase 2: Alternatives and Baselines

4. **Qwen3-Coder-14B** - Faster alternative
5. **Mistral-Large-2-123B** - Best reasoning contender
6. **Yi-Coder-34B** - Competitive balanced option

### Phase 3: Specialized Testing

7. **StarCoder2-15B** - Pure code completion
8. **Codestral-22B** - Mistral code specialist
9. **Mistral-Nemo-12B** - Fast baseline alternative

---

## Expected Final Recommendations (After Full Testing)

### Predicted Best Overall Setup

**Primary (Default):**
- **Qwen3-Coder-30B** (if significantly better at code)
- **OR GLM-4.7-Flash-Q8** (if Qwen not noticeably better)

**Speed (Ask mode):**
- **GPT-OSS-20B** (already excellent, hard to beat)

**Reasoning (Architect/Debug):**
- **GLM-4.7-REAP-218B** (unless Mistral-Large-2 clearly better)

**Massive Context (Huge repos):**
- **Llama-4-Scout-17B** (1M tokens, unique)

---

## Testing Methodology

### For Each New Model

1. **Baseline test** (512 prompt, 128 gen)
2. **Context scaling** (4K, 16K, 32K, 65K, max)
3. **Mode-specific prompts** (Ask, Code, Architect, Debug)
4. **Compare vs current champion** in same category
5. **Memory usage** analysis
6. **Decision:** Keep, replace champion, or discard

### Success Criteria for Replacement

**To replace GLM-Q8 as primary:**
- Must be faster OR significantly better quality
- Must handle ≥65K context comfortably
- Must fit in 128GB at typical context sizes

**To replace GPT-OSS-20B as speed king:**
- Must be faster (>1200 t/s prompt, >50 t/s gen)
- Quality can't be significantly worse

**To replace REAP-218B as reasoner:**
- Must show clearly better reasoning in Architect tests
- Can be slower (already slow)
- Must fit in 128GB at 65K context

---

## Download and Test Commands

```bash
# Example: Download Qwen3-Coder-30B
cd /mnt/ai-models
mkdir Qwen3-Coder-30B
cd Qwen3-Coder-30B
# Use huggingface-cli or wget to download
# Then convert to GGUF if needed

# Test with comprehensive suite
./scripts/comprehensive-ai-test.sh

# Compare against current champion
./scripts/compare-models.sh GLM-4.7-Flash-Q8 Qwen3-Coder-30B

# Mode-specific testing
./scripts/test-model-mode.sh Qwen3-Coder-30B all
```

---

## Current Status Summary

**Tested:** 6 models ✅
**High Priority Remaining:** 6 models 🔥
**Medium Priority:** ~8 models
**Total Models to Evaluate:** ~20 models

**Estimated Testing Time:**
- Baseline + context: ~30 min per model
- Mode-specific: ~1 hour per model
- Full evaluation: ~1.5 hours per model
- **Total:** ~30 hours of testing for all high/medium priority

**Recommended Approach:**
- Test high-priority batch first (6 models, ~9 hours)
- Evaluate results and update champions
- Decide if medium-priority testing needed based on findings

---

## Apriel Model - Action Required

**Need to research:**
- Official model name and version
- Parameter count and quantization available
- Specialization (code? general?)
- Context length
- Where to download

**Please provide details if you have them!**

---

## January 2026 Prediction

**Most Likely Final Champions:**

1. **Best Overall:** Qwen3-Coder-30B (if as good as expected)
2. **Fastest:** GPT-OSS-20B (hard to beat)
3. **Best Reasoning:** GLM-4.7-REAP-218B or Mistral-Large-2
4. **Massive Context:** Llama-4-Scout-17B (1M tokens unique)

**Dark Horse:** DeepSeek-Coder-V3-33B (could surprise)

**GLM Stack:** Still likely dominant for most use cases even after new testing

---

**Last Updated:** 2026-01-22
**Status:** Testing roadmap complete, awaiting model downloads
