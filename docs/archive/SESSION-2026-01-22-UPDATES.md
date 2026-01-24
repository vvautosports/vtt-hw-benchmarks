# Session Updates: 2026-01-22

Comprehensive updates to AI model testing strategy with focus on efficient mid-sized models and multi-mode execution.

---

## Key Decisions Made

### 1. Single Machine vs Distributed for 192GB Models

**Question:** Can we run DeepSeek-V3.1-1bit (192GB) on 128GB system?

**Answer:** Yes, with reduced context:
- **Recommended approach:** Reduce context from 65K to 16K saves ~12GB
- **Estimate:** 165GB base + 4GB KV cache = 169GB (might fit with `--fit` flag)
- **Fallback:** NVMe swap for overflow (slower but workable)
- **NOT recommended:** Distributed inference across 2 machines (llama.cpp doesn't support tensor parallelism)

**Better use of 2x AMD Strix Halo systems:**
- Machine 1: Fast models (Ask/Code modes)
- Machine 2: Reasoning models (Architect/Debug modes)
- Connected via Headscale mesh VPN

---

### 2. MiniMax-M2.1 as Unsloth Validator

**Currently downloading:** MiniMax-M2.1-Q3_K_XL (101GB)
- 229B parameters
- Fits comfortably in 128GB (101GB + 20GB context = 121GB total)
- **Strategic value:** Test Unsloth quality BEFORE downloading 192GB DeepSeek

**Validation script created:** `scripts/test-minimax-unsloth.sh`
- Tests performance, quality, gibberish detection
- Compares vs REAP-218B and Qwen3-235B-Q3
- Recommends whether to proceed with DeepSeek download

---

### 3. Efficient Mid-Sized Models Priority

**New priority models for multi-mode execution:**

1. **Nemotron-3-Nano-30B-A3B** (30-35GB) ⭐⭐⭐⭐⭐
   - NVIDIA efficient 30B model
   - Perfect for delegated tasks
   - Pairs well with GPT-OSS-20B (total: 48GB)

2. **Qwen3-Coder-30B** (30-40GB) ⭐⭐⭐⭐⭐
   - Code-specialized
   - Best for Code mode primary
   - Elevated to CRITICAL priority

3. **Qwen3-Coder-14B** (15-20GB) ⭐⭐⭐⭐⭐
   - Enable multi-instance (3x = 54GB)
   - Fast enough for interactive
   - Best for parallel tasks

---

## Multi-Mode Execution Strategies

### Strategy 1: Speed + Quality (48GB total)
```
- Ask Mode:  GPT-OSS-20B (13GB)
- Code Mode: Qwen3-Coder-30B (35GB)
Total: 48GB with 80GB headroom
```

### Strategy 2: Balanced Triple (64GB total)
```
- Ask Mode:        Mistral-Nemo-12B (13GB)
- Code Mode:       Qwen3-Coder-30B (35GB)
- Autocomplete:    StarCoder2-15B (16GB)
Total: 64GB with 64GB headroom
```

### Strategy 3: Multi-Instance (54GB total)
```
- Instance 1: Qwen3-Coder-14B (18GB)
- Instance 2: Qwen3-Coder-14B (18GB)
- Instance 3: Qwen3-Coder-14B (18GB)
Total: 54GB, run 3 parallel coding tasks
```

### Strategy 4: Distributed (2x 395 systems)
```
Machine 1 (Speed):
  - GPT-OSS-20B + Qwen3-Coder-30B + StarCoder2-15B = 64GB
  - Ask/Code modes

Machine 2 (Reasoning):
  - REAP-218B (92GB) OR DeepSeek-V3.1-1bit (170GB @ 16K)
  - Architect/Debug modes
```

---

## Files Created/Updated

### Documentation

**docs/MODELS-TO-TEST.md** - Major updates:
- Added "Efficient Mid-Sized Models" section
- Multi-mode execution strategies
- Distributed inference architecture
- Memory budget planning
- MiniMax-M2.1 download status (Q3_K_XL 101GB)
- Nemotron-3-Nano-30B-A3B added as high priority

**docs/SESSION-2026-01-22-UPDATES.md** - This file
- Session summary
- Key decisions documented
- Testing roadmap

### Scripts

**scripts/test-minimax-unsloth.sh** - NEW
- Quick validation test for MiniMax-M2.1
- Quality check before downloading DeepSeek-V3.1-1bit
- Gibberish detection
- Performance comparison vs REAP-218B
- Decision tree for next steps

---

## Testing Roadmap

### Immediate (When MiniMax download completes)

1. **Run MiniMax validation:**
   ```bash
   ./scripts/test-minimax-unsloth.sh
   ```

2. **Review results:**
   - Is response coherent (not gibberish)?
   - Quality vs REAP-218B?
   - Performance acceptable?

3. **Decision:**
   - ✅ If excellent → Proceed with DeepSeek-V3.1-1bit download
   - ✅ If good → MiniMax becomes reasoning champion (skip DeepSeek)
   - ❌ If poor → Skip larger Unsloth models

---

### Phase 1: Efficient Mid-Sized Models

**Download and test:**
1. Nemotron-3-Nano-30B-A3B (NVIDIA efficient model)
2. Qwen3-Coder-30B (code specialist)
3. Qwen3-Coder-14B (multi-instance capable)

**Goal:** Establish best models for multi-mode simultaneous execution

---

### Phase 2: Ultra-Large Reasoning (If MiniMax validates)

**If MiniMax quality is good:**
1. Consider DeepSeek-V3.1-1bit (192GB) with reduced context
2. Test with 16K context first (might fit in 128GB)
3. Setup NVMe swap as fallback

**If MiniMax quality disappoints:**
- Skip DeepSeek-V3.1-1bit
- Focus on proven models (REAP-218B, Mistral-Large-2)

---

### Phase 3: Complete Testing Suite

**Once key models validated:**
1. Run comprehensive-ai-test.sh on all models
2. Update AI-MODEL-STRATEGY.md with findings
3. Finalize mode-to-model mappings
4. Document distributed inference setup

---

## Technical Notes

### Memory Estimation for DeepSeek-V3.1-1bit

```
Context Size | KV Cache | Total Memory | Fits in 128GB?
-------------|----------|--------------|---------------
     4K      |   ~1GB   |    166GB     | Maybe (tight)
    16K      |   ~4GB   |    169GB     | Maybe with --fit
    32K      |   ~8GB   |    173GB     | No, needs swap
    65K      |  ~16GB   |    181GB     | No, definitely swap
```

**Recommendation:**
- Try 16K context first with `--fit` flag
- Accept slower initial load time
- Use for reasoning tasks where quality > speed

---

### Distributed Inference Limitations

**llama.cpp does NOT support:**
- Tensor parallelism across machines
- Model sharding for GGUF files
- Network-distributed forward passes

**What DOES work:**
- Different models on different machines
- Load balancing across machines
- Headscale mesh VPN for connectivity

**Architecture:**
- Each machine runs llama-server
- Editor connects to appropriate machine per mode
- Fast queries → Speed machine
- Complex queries → Reasoning machine

---

## Apriel Model - Action Required

**Status:** Mentioned but need details

**Required information:**
- Full model name
- Parameter count
- HuggingFace link or source
- Specialization (code/general/reasoning?)
- Intended use case

**Please provide details to add to testing roadmap!**

---

## Next Actions

**When MiniMax download completes:**
1. ✅ Run `./scripts/test-minimax-unsloth.sh`
2. ✅ Review validation report
3. ✅ Decide on DeepSeek-V3.1-1bit download

**Parallel track:**
1. Download Nemotron-3-Nano-30B-A3B
2. Download Qwen3-Coder-30B
3. Download Qwen3-Coder-14B

**Research:**
- Investigate Apriel model details
- Plan distributed inference setup (2x 395 systems)
- Consider multi-node thinking mode architecture

---

## Questions to Revisit Later

**Multi-node thinking mode:** (user noted for later)
- DeepSeek handles deep reasoning on one node
- Delegates to specialized models on other nodes
- Worth exploring after hardware testing validates models

**Smaller efficient models:** (addressed in this session)
- ✅ Nemotron-3-Nano-30B-A3B added
- ✅ Qwen3-Coder series prioritized
- ⏸️ Apriel awaiting details

---

## Summary

This session focused on **practical multi-mode execution** rather than just benchmarking:

**Key insights:**
1. Running 2-3 mid-sized models (30-40GB each) is better than trying to fit one massive model
2. Distributed = different models on different machines, NOT model sharding
3. MiniMax-M2.1 validates Unsloth quality before committing to 192GB DeepSeek
4. Efficient 14-30B models enable delegated tasks and parallel workflows

**Ready for testing:**
- MiniMax validation script prepared
- Multi-mode strategies documented
- Memory budgets calculated
- Distributed architecture planned

**Waiting on:**
- MiniMax download completion
- Apriel model details
- Efficient mid-sized model downloads

---

**Last Updated:** 2026-01-22
**Session Progress:** ~16% of 200k token budget
**Commits:** 3 (MODELS-TO-TEST updates, validation script)
**Status:** Ready for MiniMax testing when download completes
