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

## CRITICAL PRIORITY - Game Changers 🚀

### DeepSeek-V3.1 Unsloth Dynamic GGUFs (Revolutionary Quantization)

**Why this changes everything:**
- Traditional 1-2 bit quantization = gibberish
- Unsloth Dynamic GGUF = actually works with selective layer quantization
- DeepSeek-V3.1 normally 671GB → **192GB at 1-bit** (-75% size!)
- Fits on our 128GB system with memory pressure management
- Performance claims: 1-bit outperforms GPT-4.1, GPT-4.5, DeepSeek-V3-0324

**DeepSeek-V3.1-1bit-Unsloth** (~192GB)
- **Why test:** 671B parameter model in 192GB!
- **Expected advantage:** Massive model on consumer hardware
- **Trade-off:** Memory pressure on 128GB (need swap or reduced context)
- **Use case:** When you need SOTA reasoning and can manage memory
- **Priority:** ⭐⭐⭐⭐⭐ **HIGHEST - Could revolutionize local AI**
- **Status:** Need to download from Unsloth
- **Link:** https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs/unsloth-dynamic-ggufs-on-aider-polyglot

**DeepSeek-V3.1-2bit-Unsloth** (~250-300GB estimated)
- **Why test:** More quality than 1-bit, still massive compression
- **Expected advantage:** Better quality, still manageable with swap
- **Priority:** ⭐⭐⭐⭐⭐

**DeepSeek-V3.1-3bit-Unsloth** (~350-400GB estimated)
- **Why test:** Thinking mode outperforms Claude-4-Opus
- **Trade-off:** Doesn't fit in 128GB RAM alone (needs swap/disk)
- **Use case:** Absolute best quality, worth the wait
- **Priority:** ⭐⭐⭐⭐

**DeepSeek-V3.1-5bit-Unsloth** (~500GB estimated)
- **Why test:** Matches Claude-4-Opus (non-thinking)
- **Trade-off:** Way too large for 128GB (skip unless have 512GB+ RAM)
- **Priority:** ⭐ (too large for our hardware)

**Key Insight:** 1-bit and 2-bit Unsloth models could fit where 671B model normally impossible!

---

### MiniMax-M2.1 Unsloth GGUF

**MiniMax-M2.1-Q3_K_XL** (101GB - downloading now)
- **Why test:** 229B parameter Chinese model (competitive with DeepSeek/Qwen)
- **Expected advantage:** Different architecture (minimax-m2) might excel at different tasks
- **Unsloth optimization:** Validates Unsloth GGUF quality before committing to DeepSeek-V3.1-1bit
- **Memory fit:** 101GB + ~20GB context = **~121GB total ✓ Comfortable fit in 128GB**
- **Use case:** Reasoning/architecture tasks, alternative to REAP-218B
- **Priority:** ⭐⭐⭐⭐⭐ **CRITICAL - Validates Unsloth quality claims**
- **Status:** ⬇️ **Downloading Q3_K_XL (101GB)**
- **Link:** https://huggingface.co/unsloth/MiniMax-M2.1-GGUF

**Strategic importance:**
- **Test THIS before downloading 192GB DeepSeek-V3.1-1bit**
- If quality is excellent → Proceed with confidence to DeepSeek
- If quality is good → MiniMax becomes reasoning champion (fits better than DeepSeek)
- If quality disappoints → Don't download larger Unsloth models

**Comparison targets:**
- vs GLM-4.7-REAP-218B (92GB, 218B params) - Current reasoning champion
- vs Qwen3-235B-Q3 (97GB, 235B params, similar size/quant)
- vs DeepSeek-V3.1-1bit (if quality validates, proceed to 192GB model)

**Testing once complete:**
1. Baseline: 512p/128g, measure t/s
2. Quality: Architect mode reasoning tasks
3. Context: Scale to 65K-131K
4. Comparison: Better than REAP-218B?
5. Decision: New reasoning champion OR skip larger Unsloth models

**Note:** MiniMax models have shown strong performance in Chinese benchmarks and coding tasks. 229B params at Q3 is competitive parameter count with our current reasoning models.

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

---

## EFFICIENT MID-SIZED MODELS - Multi-Mode & Delegated Tasks 🎯

### Strategy: Running Multiple Modes Simultaneously

**Goal:** Run 2-3 models concurrently for different modes without exceeding 128GB RAM.

**Target models:** 10-40GB range, optimized for efficiency and quality balance.

**Use cases:**
- Ask mode + Code mode running simultaneously
- Delegated tasks to specialized models
- Multi-editor setup (Roo + Cursor + Claude Code)
- Fast context switching between modes

---

### Nemotron-3-Nano-30B-A3B (NEW - High Priority!)

**unsloth/Nemotron-3-Nano-30B-A3B-GGUF**
- **Why test:** NVIDIA's efficient 30B model with active expert architecture
- **Expected size:** ~30-35GB Q8, ~15-20GB Q4
- **Expected advantage:** Strong coding + reasoning at mid-size
- **Use case:** Balanced model for delegated tasks
- **Multi-mode fit:** Pairs well with GPT-OSS-20B (total: ~48GB)
- **Priority:** ⭐⭐⭐⭐⭐ **HIGHEST for efficient mid-size**
- **Status:** Need to download from Unsloth
- **Link:** https://huggingface.co/unsloth/Nemotron-3-Nano-30B-A3B-GGUF

**Testing focus:**
- Quality vs Qwen3-Coder-30B (similar size)
- Speed vs GLM-4.7-Flash-Q8
- Memory efficiency for multi-mode use

---

### Qwen3-Coder-30B (Already Listed, ELEVATED Priority)

**Qwen3-Coder-30B-Q8** (~30-40GB)
- **Why critical for multi-mode:** Best size/quality balance for code
- **Expected advantage:** Code-specialized, fits with other models
- **Multi-mode combinations:**
  - Qwen3-Coder-30B (35GB) + GPT-OSS-20B (13GB) = 48GB ✓
  - Qwen3-Coder-30B (35GB) + Nemotron-30B (35GB) = 70GB ✓
  - Qwen3-Coder-30B (35GB) + StarCoder2-15B (16GB) = 51GB ✓
- **Use case:** Primary Code mode while other models handle Ask/Debug
- **Priority:** ⭐⭐⭐⭐⭐ **CRITICAL for multi-mode**
- **Status:** Need to download and test

---

### Qwen3-Coder-14B (Faster Mid-Size Alternative)

**Qwen3-Coder-14B-Q8** (~15-20GB)
- **Why test:** Even more efficient, almost GPT-OSS-20B speed
- **Expected advantage:** Fast enough for interactive, better code quality than GPT
- **Multi-mode combinations:**
  - Qwen3-Coder-14B (18GB) + GLM-Q8 (33GB) = 51GB ✓
  - Qwen3-Coder-14B (18GB) + REAP-218B (92GB) = 110GB ✓
  - 3x Qwen3-Coder-14B = 54GB (run 3 instances!) ✓
- **Use case:** Multiple concurrent coding tasks
- **Priority:** ⭐⭐⭐⭐⭐ **HIGHEST for multi-instance**
- **Status:** Need to download

---

### Apriel Model - Placeholder

**Status:** Mentioned but need details
- **Model name/size?** Unknown
- **Specialization?** Unknown
- **Release date?** Unknown
- **Priority:** ⭐⭐⭐⭐ (assuming mid-size efficient model)
- **Action:** Need user to provide:
  - Full model name
  - HuggingFace link or source
  - Intended use case
  - Parameter count

**Note:** Will add full analysis once details provided.

---

### StarCoder2-15B (Already Listed, ELEVATED for Multi-Mode)

**StarCoder2-15B-Q8** (~16GB)
- **Why critical for multi-mode:** Pure code completion specialist
- **Multi-mode fit:** Excellent companion model
  - StarCoder2-15B (16GB) + GLM-Q8 (33GB) = 49GB ✓
  - StarCoder2-15B (16GB) + REAP-218B (92GB) = 108GB ✓
- **Use case:** Dedicated autocomplete while larger model handles reasoning
- **Priority:** ⭐⭐⭐⭐ **HIGH for multi-mode**

---

### Mistral-Nemo-12B (Already Listed, ELEVATED)

**Mistral-Nemo-12B-Q8** (~13GB)
- **Why critical for multi-mode:** Similar size to GPT-OSS-20B, newer
- **Multi-mode combinations:**
  - Nemo-12B (13GB) + Qwen3-Coder-30B (35GB) = 48GB ✓
  - Nemo-12B (13GB) + GLM-Q8 (33GB) + StarCoder2 (16GB) = 62GB ✓
  - Nemo-12B (13GB) + REAP-218B (92GB) = 105GB ✓
- **Use case:** Fast Ask mode + larger models for other modes
- **Priority:** ⭐⭐⭐⭐ **HIGH for multi-mode**

---

## Multi-Mode Execution Strategies

### Strategy 1: Speed + Quality Combo (48-70GB total)

**Best for:** Interactive development with fast Ask, quality Code

**Configuration:**
```
Machine 1 (Single 395, 128GB):
- Ask Mode:  GPT-OSS-20B (13GB)
- Code Mode: Qwen3-Coder-30B (35GB)
Total: 48GB + 20GB buffer = 68GB used
```

**Performance:**
- Ask: <2s responses (GPT-OSS speed)
- Code: High quality, 5-10s responses (Qwen3-Coder)
- Simultaneous: Yes, 60GB total

---

### Strategy 2: Balanced Triple Setup (60-80GB total)

**Best for:** Running Ask + Code + Code-Complete simultaneously

**Configuration:**
```
Machine 1 (Single 395, 128GB):
- Ask Mode:        Mistral-Nemo-12B (13GB)
- Code Mode:       Qwen3-Coder-30B (35GB)
- Autocomplete:    StarCoder2-15B (16GB)
Total: 64GB + 20GB buffer = 84GB used
```

**Performance:**
- Ask: Fast (Nemo-12B)
- Code: High quality (Qwen3-Coder)
- Autocomplete: Instant (StarCoder2)

---

### Strategy 3: Quality + Reasoning (105-120GB total)

**Best for:** Code + Deep architecture analysis

**Configuration:**
```
Machine 1 (Single 395, 128GB):
- Code Mode:      Qwen3-Coder-30B (35GB)
- Architect Mode: REAP-218B (92GB)
- OR
- Code Mode:      GLM-Q8 (33GB)
- Architect Mode: REAP-218B (92GB)
Total: ~125GB (tight but workable)
```

**Performance:**
- Code: Quality (Qwen/GLM)
- Architect: Best reasoning (REAP)
- Memory: Tight, monitor closely

---

### Strategy 4: Multi-Instance Same Model (54-90GB total)

**Best for:** Running multiple independent coding tasks

**Configuration:**
```
Machine 1 (Single 395, 128GB):
- Instance 1: Qwen3-Coder-14B (18GB) - Task A
- Instance 2: Qwen3-Coder-14B (18GB) - Task B
- Instance 3: Qwen3-Coder-14B (18GB) - Task C
Total: 54GB + buffer = ~70GB used
```

**Use case:**
- Testing different approaches simultaneously
- Multi-repository work
- Delegated background tasks

---

## Distributed Inference: 2x AMD Strix Halo Systems

### Recommended Architecture: Role-Based Model Distribution

**Better than:** Trying to shard a single model across machines (llama.cpp doesn't support this well)

**Strategy:** Each machine specializes in certain modes

---

### Configuration: Speed Machine + Reasoning Machine

**Machine 1: "Speed Machine" (Ask + Code modes)**
```
AMD Strix Halo #1 (128GB):
- Ask Mode:        GPT-OSS-20B (13GB)
- Code Mode:       Qwen3-Coder-30B (35GB)
- Code Alt:        Qwen3-Coder-14B (18GB)
- Autocomplete:    StarCoder2-15B (16GB)
Total: ~82GB, capacity for 3-4 concurrent
```

**Machine 2: "Reasoning Machine" (Architect + Debug modes)**
```
AMD Strix Halo #2 (128GB):
- Architect Mode:  REAP-218B (92GB)
- Debug Alt:       Mistral-Large-2 (120GB, swapped)
- OR DeepSeek-V3.1-1bit (170GB @ 16K ctx, tight fit)
Total: ~92-120GB, 1-2 large models
```

---

### Network Setup: Headscale Mesh VPN

**Already configured:** MS-01 Keras OCR via Headscale

**Extend for AI models:**
```bash
# On each 395 machine, run llama.cpp server
# Machine 1 (Speed):
llama-server -m /mnt/ai-models/Qwen3-Coder-30B/model.gguf \
  -c 65536 -ngl 999 -fa 1 --port 8001 --host 0.0.0.0

# Machine 2 (Reasoning):
llama-server -m /mnt/ai-models/REAP-218B/model.gguf \
  -c 65536 -ngl 999 -fa 1 --port 8001 --host 0.0.0.0

# Access via Headscale mesh:
# machine1.tailnet-name.ts.net:8001
# machine2.tailnet-name.ts.net:8001
```

**Editor configuration:**
- Roo Ask mode → Machine 1:8001 (GPT-OSS-20B)
- Roo Code mode → Machine 1:8002 (Qwen3-Coder-30B)
- Roo Architect → Machine 2:8001 (REAP-218B)

---

### Performance Expectations: Distributed vs Local

| Metric | Local (same machine) | Distributed (via Headscale) |
|--------|---------------------|------------------------------|
| **Latency** | <1ms overhead | +2-10ms network overhead |
| **Throughput** | Full GPU speed | Same (network not bottleneck) |
| **Setup** | Simple | Moderate (server setup) |
| **Reliability** | High | Depends on network |
| **Scalability** | Limited by 128GB | 2x capacity (256GB total) |
| **Cost** | 1 machine | 2 machines |

**Verdict:** Distributed makes sense for running MORE models, not faster inference of one model.

---

## Memory Budget Planning

### Small Model Budget (< 50GB total)

**Recommended combos:**
1. GPT-OSS-20B (13GB) + Qwen3-Coder-30B (35GB) = 48GB
2. Mistral-Nemo-12B (13GB) + DeepSeek-Coder-V3-33B (35GB) = 48GB
3. 3x Qwen3-Coder-14B (18GB each) = 54GB

**Use case:** Maximum flexibility, 3-4 simultaneous models

---

### Medium Model Budget (50-80GB total)

**Recommended combos:**
1. Nemo-12B + Qwen3-Coder-30B + StarCoder2-15B = 64GB
2. GPT-OSS-20B + GLM-Q8 + StarCoder2-15B = 62GB
3. Qwen3-Coder-14B + Qwen3-80B-Q8 = 105GB (tight)

**Use case:** Balanced quality + speed

---

### Large Model Budget (80-120GB total)

**Recommended combos:**
1. Qwen3-Coder-30B (35GB) + REAP-218B (92GB) = 127GB (max)
2. GLM-Q8 (33GB) + REAP-218B (92GB) = 125GB
3. Qwen3-80B (87GB) + Nemo-12B (13GB) = 100GB
4. Mistral-Large-2 (120GB) alone

**Use case:** Maximum quality, 1-2 large models

---

## Testing Priority: Efficient Mid-Sized Models

### Immediate Priority (Test First)

1. **Nemotron-3-Nano-30B-A3B** ⭐⭐⭐⭐⭐
   - Unknown quantity, could be excellent
   - Perfect size for multi-mode (30GB)
   - NVIDIA engineering, likely high quality

2. **Qwen3-Coder-30B** ⭐⭐⭐⭐⭐
   - Known good model family
   - Code-specialized
   - Perfect for Code mode primary

3. **Qwen3-Coder-14B** ⭐⭐⭐⭐⭐
   - Enable multi-instance use cases
   - Fast enough for interactive
   - 3x instances possible

### Secondary Priority

4. **Mistral-Nemo-12B** ⭐⭐⭐⭐
   - GPT-OSS-20B alternative
   - Newer training data

5. **StarCoder2-15B** ⭐⭐⭐⭐
   - Autocomplete specialist
   - Perfect companion model

---

## Expected Winners for Multi-Mode

**Best dual setup:**
- **Ask:** GPT-OSS-20B (13GB, fastest)
- **Code:** Qwen3-Coder-30B or Nemotron-30B (35GB, quality)
- **Total:** 48GB, plenty of headroom

**Best triple setup:**
- **Ask:** Mistral-Nemo-12B (13GB)
- **Code:** Qwen3-Coder-30B (35GB)
- **Autocomplete:** StarCoder2-15B (16GB)
- **Total:** 64GB, balanced

**Best distributed (2x 395):**
- **Machine 1:** GPT-OSS-20B + Qwen3-Coder-30B + StarCoder2-15B = 64GB
- **Machine 2:** REAP-218B or DeepSeek-V3.1-1bit = 92-170GB
- **Total capability:** 5 models across 2 machines

---

## Implications for AMD Strix Halo (128GB)

### What Unsloth Dynamic Changes

**Before Unsloth:**
- Maximum model size: ~120GB Q3 (e.g., Qwen-235B, Mistral-Large-2)
- Parameter limit: ~235B parameters practical
- Trade-off: Size vs quality vs speed

**After Unsloth:**
- Can run 671B parameter models! (DeepSeek-V3.1-1bit)
- 192GB 1-bit model with memory pressure management
- Potentially SOTA reasoning on consumer hardware
- New category: "Ultra-large models via ultra-low-bit quant"

### Memory Management Strategies for 192GB Model on 128GB System

**Option 1: Swap to NVMe (slower but works)**
```bash
# Create 128GB swap on NVMe
sudo dd if=/dev/zero of=/swapfile bs=1G count=128
sudo mkswap /swapfile
sudo swapon /swapfile
```
- **Speed:** Slow when swapping (NVMe latency)
- **Usable:** Yes, for batch processing / non-interactive
- **Context:** Reduced to fit in active memory

**Option 2: Reduce context window**
- DeepSeek-V3.1 has long context capability
- Reducing to 32K-65K context saves ~20-40GB
- Might fit in 128GB with model + reduced KV cache
- **Best for:** Interactive use with reasonable context

**Option 3: Wait for 256GB upgrade**
- Not practical short-term
- But validates future hardware planning

**Recommendation:** Try Option 2 first (reduced context), fall back to Option 1 (swap) for batch

---

## Expected Winners by Category

### Speed Category (< 2 sec responses)
**Current:** GPT-OSS-20B (1135/46 t/s)
**Challengers:**
1. Mistral-Nemo-12B (might be faster)
2. Gemma-2-9B (might be faster but lower quality)
3. StarCoder2-3B (ultra-fast but limited)

**Likely Winner:** GPT-OSS-20B (already excellent)

**Note:** 1-bit models will be slower due to dequantization overhead

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
1. **DeepSeek-V3.1-1bit/2bit Unsloth** (671B params!) 🚀 **GAME CHANGER**
2. Mistral-Large-2-123B (might be better reasoner)
3. Qwen3-235B (already tested, similar)
4. Llama-4-Scout-70B (if context helps reasoning)

**Likely Winner:** DeepSeek-V3.1-1bit if it fits and performs as claimed (revolutionary)
**Fallback:** REAP-218B or Mistral-Large-2 if DeepSeek doesn't fit/work

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

### Phase 0: Revolutionary Technology (Test FIRST) 🚀

**DeepSeek-V3.1 Unsloth Dynamic GGUFs**
1. **DeepSeek-V3.1-1bit** (~192GB) - If this works, changes everything
2. **DeepSeek-V3.1-2bit** (~250-300GB) - Better quality backup

**Why test first:**
- Could make 671B parameter model usable on 128GB system
- Claims to outperform GPT-4.1, GPT-4.5, Claude-4-Opus
- Revolutionary if true - validates or disproves Unsloth claims
- If it works: New champion for reasoning/architecture tasks
- If it doesn't work on our hardware: Know not to prioritize ultra-low-bit

**Testing approach:**
- Test with reduced context first (32K-65K to manage memory)
- If works: Best reasoning model by far
- If doesn't fit: Document limitations for future hardware planning

**Estimated testing time:** 2-3 hours (including memory management setup)

---

### Phase 1: High-Impact Models (Test After DeepSeek Validation)

1. **Qwen3-Coder-30B** - Most likely to dethrone GLM-Q8
2. **Llama-4-Scout-17B** - Unique 1M context capability
3. **GPT-OSS-120B** - Much larger GPT, potential quality leader
4. **DeepSeek-Coder-V3-33B** - Strong recent coder

**Why:** These have highest chance of beating current champions (if DeepSeek doesn't work)

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

### Special: Ultra-Low-Bit Models (1-2 bit Unsloth)

**Pre-test checks:**
1. **Memory availability:** Free up as much RAM as possible
   - Close all non-essential applications
   - Clear page cache: `sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches`
   - Monitor: `watch -n 1 free -h`

2. **Swap configuration (if needed):**
   ```bash
   # Check existing swap
   swapon --show

   # Create NVMe swap if needed (for 192GB model on 128GB RAM)
   sudo dd if=/dev/zero of=/swapfile bs=1G count=128
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

3. **Test with reduced context first:**
   - Start with 16K context (minimal KV cache)
   - Gradually increase to 32K, 65K if memory permits
   - Monitor swap usage: `vmstat 1`

**Testing procedure for 1-bit DeepSeek-V3.1:**
1. **Load test** - Can it even load?
   - If OOM: Try with reduced context
   - If still OOM: Document as "too large for 128GB"
   - If loads: Proceed to performance testing

2. **Quality test** - Does it produce coherent output?
   - Simple prompt: "Explain what a Python decorator is"
   - Check for gibberish/looping (common with bad 1-bit quants)
   - If gibberish: Unsloth claims are wrong, document and skip
   - If coherent: Proceed to benchmark

3. **Performance test** - How fast is it?
   - Expect slower than higher-bit quants due to dequantization
   - Baseline: 512 prompt, 128 gen
   - Measure: t/s prompt, t/s gen, total latency
   - Compare to GLM-REAP-218B (current reasoning champion)

4. **Mode-specific test** - Architect mode (its strength)
   - Complex system design prompt
   - Compare quality to REAP-218B and Qwen-235B
   - Judge: Is 671B params worth the memory pressure?

**Success criteria for ultra-low-bit models:**
- **Must:** Produce coherent, accurate output (not gibberish)
- **Should:** Quality > smaller models despite low bits
- **Nice:** Usable speed (even if slow, quality might justify)

**Decision tree:**
- If gibberish → Document failure, skip similar models
- If slow but high quality → Keep for batch/reasoning tasks
- If fast + high quality → New reasoning champion!

---

### For Normal Models (Q3-Q8, F16)

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

### Unsloth Dynamic GGUFs (Priority)

**Where to get DeepSeek-V3.1 Unsloth models:**
- Official: https://unsloth.ai/docs/basics/unsloth-dynamic-2.0-ggufs/
- HuggingFace: https://huggingface.co/unsloth (search for DeepSeek-V3.1)
- **Important:** Must use Unsloth Dynamic GGUFs, not standard quantizations

```bash
# Download DeepSeek-V3.1-1bit Unsloth (example)
cd /mnt/ai-models
mkdir DeepSeek-V3.1-1bit-Unsloth
cd DeepSeek-V3.1-1bit-Unsloth

# Use huggingface-cli
huggingface-cli download unsloth/DeepSeek-V3.1-1bit-GGUF \
  --local-dir . --local-dir-use-symlinks False

# Or wget if direct link available
# wget https://huggingface.co/unsloth/...

# Verify file size (should be ~192GB for 1-bit)
ls -lh
```

**Testing with memory management:**
```bash
# 1. Free up memory
sudo sync; echo 3 | sudo tee /proc/sys/vm/drop_caches

# 2. Setup swap if needed (for 192GB model on 128GB RAM)
sudo dd if=/dev/zero of=/swapfile bs=1G count=128
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 3. Test with reduced context first
podman run --rm \
  --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render \
  --security-opt seccomp=unconfined \
  -v /mnt/ai-models/DeepSeek-V3.1-1bit-Unsloth:/models:ro,z \
  --entrypoint llama-bench \
  vtt-benchmark-llama \
  -m /models/deepseek-v3.1-1bit.gguf \
  -p 512 -n 128 \
  -ngl 999 -fa 1 -mmp 0

# 4. Monitor memory usage
watch -n 1 free -h
```

---

### Standard Models (Normal Priority)

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

## January 2026 Prediction (Updated with Unsloth)

**Most Likely Final Champions:**

1. **Best Reasoning:** DeepSeek-V3.1-1bit-Unsloth (if it works!) 🚀
   - Fallback: GLM-4.7-REAP-218B or Mistral-Large-2
2. **Best Overall Coding:** Qwen3-Coder-30B or GLM-4.7-Flash-Q8
3. **Fastest:** GPT-OSS-20B (hard to beat)
4. **Massive Context:** Llama-4-Scout-17B (1M tokens unique)

**Revolutionary If True:**
- DeepSeek-V3.1-1bit could make 671B params usable on consumer hardware
- Would be biggest AI breakthrough for local inference in years
- Makes AMD Strix Halo viable for SOTA reasoning

**Dark Horses:**
1. **DeepSeek-V3.1-2bit** (if 1-bit doesn't work but 2-bit does)
2. GPT-OSS-120B (if speed scales from 20B)
3. DeepSeek-Coder-V3-33B (strong recent model)

**GLM Stack:** Still likely dominant for everyday coding if DeepSeek doesn't fit

**Key Uncertainty:** Can 192GB DeepSeek-V3.1-1bit actually run on 128GB system with reduced context?

---

---

## Summary: Why 1-2 Bit Unsloth Could Change Everything

### The Breakthrough

**Traditional quantization:**
- Q8 (8-bit): ~30-40% size reduction, excellent quality
- Q4 (4-bit): ~70% size reduction, good quality
- Q2/Q1: Gibberish, unusable

**Unsloth Dynamic GGUF:**
- **1-bit: ~75% size reduction, claims to work!**
- 2-bit: ~70% reduction, better quality than 1-bit
- Uses selective layer quantization (smart about which layers to compress more)
- DeepSeek-V3.1: 671GB → 192GB while maintaining coherence

### Impact on AMD Strix Halo (128GB)

**Before Unsloth:**
- Maximum: ~235B parameters (Qwen3-235B at Q3)
- Practical: ~80-120B parameters (Q8 for quality)

**After Unsloth (if it works):**
- Potential: 671B parameters! (DeepSeek-V3.1-1bit)
- Trade-off: Need swap/reduced context, but usable
- Result: SOTA reasoning on consumer hardware

### What We Need to Validate

**Critical questions:**
1. Does it actually produce coherent output? (Unsloth claims yes, others produce gibberish)
2. Can it fit in 128GB with reduced context? (192GB model, tight but maybe)
3. Is quality actually better than smaller models? (Claims beat GPT-4.1, GPT-4.5)
4. Is speed acceptable? (1-bit dequantization overhead, expect slower)

**If all YES:**
- Revolutionary for local AI
- AMD Strix Halo becomes SOTA reasoning machine
- Changes hardware recommendations entirely

**If any NO:**
- Still have excellent GLM/Qwen stack
- Document why ultra-low-bit doesn't work on our hardware
- Plan for future with more RAM

### Testing Priority

**Immediate:**
1. Download DeepSeek-V3.1-1bit-Unsloth
2. Test load with reduced context (32K)
3. Validate coherence (not gibberish)
4. If works: Full benchmark suite
5. If fails: Document why, continue with normal models

**This is the most important test** - could make or break the value of ultra-low-bit quantization for coding assistants.

---

**Last Updated:** 2026-01-22
**Status:** Updated with Unsloth Dynamic GGUF priority
**Next Action:** Download and test DeepSeek-V3.1-1bit IMMEDIATELY
