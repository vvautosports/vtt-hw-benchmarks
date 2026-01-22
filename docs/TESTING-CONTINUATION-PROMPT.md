# Testing Continuation Prompt - Local AI Models with Roo

**Session Status:** 2026-01-22, ~33% token budget used
**Next Phase:** Model validation and realistic context testing

---

## Current State

### Models Downloaded
- ✅ GLM-4.7-Flash-Q8 (33GB) - Current champion
- ✅ GLM-4.7-Flash-BF16 (56GB)
- ✅ GLM-4.7-REAP-218B (92GB) - Best reasoning
- ✅ GPT-OSS-20B (13GB) - Fastest
- ✅ Qwen3-80B-Q8 (87GB)
- ✅ Qwen3-235B-Q3 (97GB)
- ⬇️ **MiniMax-M2.1-Q3_K_XL (101GB)** - Downloading now

### Models to Download Next
1. **DeepSeek-V3.1-TQ1_0 (170GB)** - Use TQ1_0, NOT IQ1_S (192GB)
2. **Apriel-1.5-15B-Thinker** (~15GB) - Fine-tuning candidate
3. **Ministral-3-14B-Instruct** (~14GB) - Latest small Mistral
4. **Llama-4-Scout-17B-16E** (~35GB) - 10M token context!
5. **Nemotron-3-Nano-30B-A3B** (~30GB) - NVIDIA efficient model
6. **Qwen3-Coder-30B** (~35GB) - Code specialist
7. **Qwen3-Coder-14B** (~18GB) - Multi-instance capable

---

## Immediate Actions

### 1. When MiniMax Download Completes

**Run validation test:**
```bash
cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks
./scripts/test-minimax-unsloth.sh
```

**This tests:**
- Speed: 512p/128g baseline
- Realistic: 4K prompt, 512 gen (typical coding)
- Large context: 16K prompt, 1024 gen (architecture tasks)
- Quality: Reasoning task with coherence check
- Comparison: vs REAP-218B and Qwen-235B

**Decision tree:**
- ✅ **Excellent quality** → Download DeepSeek-V3.1-TQ1_0 (170GB)
- ✅ **Good quality** → MiniMax is new reasoning champion
- ❌ **Poor/gibberish** → Skip larger Unsloth models

---

### 2. Update Benchmark Context Sizes

**OLD (inadequate):**
- 512 prompt / 128 generation
- Only tests speed, not realistic usage

**NEW (realistic):**
- **Small models:** 512:128, 4K:512, 16K:512
- **Medium models:** 512:128, 4K:512, 16K:512, 32K:1024, 65K:512
- **Large models:** 512:128, 4K:512, 16K:1024, 32K:1024, 65K:1024
- **Ultra-context:** Test up to 131K+ for Scout/DeepSeek

**Why this matters:**
- 512 tokens = parking lot test for a Ferrari
- 4K = realistic coding session (file + context)
- 16K = multi-file operations
- 32K+ = architecture/design tasks

**Scripts updated:**
- ✅ `test-minimax-unsloth.sh` - Now tests 512, 4K, 16K
- ✅ `comprehensive-ai-test.sh` - Context definitions updated
- ⏸️ Execution logic needs update (parse prompt:gen format)

---

## Testing with Roo and Local AI Models

### Roo Mode Configuration

**Speed Machine Setup (Ask/Code modes):**
```yaml
Roo Ask Mode:
  Model: GPT-OSS-20B
  Endpoint: http://localhost:8001
  Context: 4K max
  Expected: <2s responses

Roo Code Mode:
  Model: GLM-4.7-Flash-Q8 or Qwen3-Coder-30B
  Endpoint: http://localhost:8002
  Context: 16K-32K
  Expected: 5-10s responses
```

**Reasoning Machine Setup (Architect/Debug modes):**
```yaml
Roo Architect Mode:
  Model: MiniMax-M2.1-Q3 or REAP-218B
  Endpoint: http://localhost:8003
  Context: 32K-65K
  Expected: 15-30s responses

Roo Debug Mode:
  Model: Same as Architect
  Endpoint: http://localhost:8003
  Context: 16K-32K
  Expected: 10-20s responses
```

---

### llama-server Setup for Roo

**Start multiple llama-server instances:**

```bash
# Terminal 1: Ask mode (GPT-OSS-20B)
llama-server \
  -m /mnt/ai-models/gpt-oss-20b-F16/gpt-oss-20b-F16.gguf \
  -c 16384 -ngl 999 -fa 1 -mmp 0 \
  --port 8001 --host 0.0.0.0

# Terminal 2: Code mode (GLM-Q8)
llama-server \
  -m /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  -c 65536 -ngl 999 -fa 1 -mmp 0 \
  --port 8002 --host 0.0.0.0

# Terminal 3: Architect mode (MiniMax when ready, or REAP-218B)
llama-server \
  -m /mnt/ai-models/GLM-4.7-REAP-218B/GLM-4.7-REAP-218B-A32B-UD-Q3_K_XL-00001-of-00002.gguf \
  -c 65536 -ngl 999 -fa 1 -mmp 0 \
  --port 8003 --host 0.0.0.0
```

**Memory usage:**
- GPT-OSS-20B: ~13GB
- GLM-Q8: ~33GB
- REAP-218B: ~92GB
- **Total: ~138GB** (over limit by 10GB, might work or swap slightly)

**Alternative (fits better):**
- GPT-OSS-20B: ~13GB
- Qwen3-Coder-30B: ~35GB
- MiniMax-M2.1: ~101GB
- **Total: ~149GB** (needs context reduction or swap)

**Best fit:**
- GPT-OSS-20B @ 4K ctx: ~15GB
- Qwen3-Coder-30B @ 32K ctx: ~40GB
- REAP-218B @ 32K ctx: ~100GB
- **Total: ~155GB** (reduced context, might need swap)

---

### Roo Configuration

**Update Roo config to point to local servers:**

```json
{
  "modes": {
    "ask": {
      "provider": "openai-compatible",
      "endpoint": "http://localhost:8001/v1",
      "model": "gpt-oss-20b",
      "maxTokens": 512
    },
    "code": {
      "provider": "openai-compatible",
      "endpoint": "http://localhost:8002/v1",
      "model": "glm-4.7-flash-q8",
      "maxTokens": 2048
    },
    "architect": {
      "provider": "openai-compatible",
      "endpoint": "http://localhost:8003/v1",
      "model": "minimax-m2.1",
      "maxTokens": 4096
    },
    "debug": {
      "provider": "openai-compatible",
      "endpoint": "http://localhost:8003/v1",
      "model": "minimax-m2.1",
      "maxTokens": 2048
    }
  }
}
```

---

## DeepSeek V3.1 Decision: TQ1_0 vs IQ1_S

### Recommendation: Download TQ1_0 (170GB)

**Comparison:**

| Quantization | Size | + 16K ctx | Fits 128GB? | Recommendation |
|--------------|------|-----------|-------------|----------------|
| **TQ1_0**    | 170GB | ~174GB   | Maybe       | ✅ **Download this** |
| IQ1_S        | 192GB | ~196GB   | No          | ❌ Skip |

**Why TQ1_0:**
- 22GB smaller than IQ1_S
- No quality difference reported
- Better chance of fitting in 128GB with reduced context
- Even if needs swap, less swap usage

**Memory strategy:**
```bash
# Option 1: Reduced context (try first)
llama-server -m deepseek-v3.1-tq1_0.gguf -c 16384 --fit

# Option 2: Swap fallback
sudo dd if=/dev/zero of=/swapfile bs=1G count=64
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## Priority Testing Sequence

### Phase 1: Validate Unsloth Quality (In Progress)
1. ✅ MiniMax-M2.1-Q3_K_XL downloading
2. ⏸️ Run validation script when complete
3. ⏸️ Decide on DeepSeek-V3.1-TQ1_0 download

---

### Phase 2: Efficient Mid-Sized Models
**Download and test:**
1. **Apriel-1.5-15B-Thinker** (fine-tuning candidate)
2. **Ministral-3-14B-Instruct** (latest small Mistral)
3. **Qwen3-Coder-14B** (multi-instance capable)
4. **Qwen3-Coder-30B** (code specialist)
5. **Nemotron-3-Nano-30B-A3B** (NVIDIA efficient)

**Goal:** Find best models for multi-mode simultaneous execution

---

### Phase 3: Ultra-Context Models
**Download and test:**
1. **Llama-4-Scout-17B-16E** (1-10M token context!)
   - Test at 100K context (overnight research)
   - Test at 1M context (entire large projects)
   - NOT for interactive use

2. **DeepSeek-V3.1-TQ1_0** (if MiniMax validates Unsloth)
   - Test at 16K context (reduced for memory)
   - Test reasoning quality
   - Decide if worth the memory pressure

---

### Phase 4: Comprehensive Benchmarking
**Run full test suite:**
```bash
./scripts/comprehensive-ai-test.sh
```

**Update findings in:**
- `docs/AI-MODEL-STRATEGY.md` - Mode mappings
- `docs/SESSION-2026-01-22-UPDATES.md` - Session notes
- Test results in `results/` directory

---

## Multi-Mode Strategies to Test

### Strategy 1: Speed + Quality (48GB)
```
GPT-OSS-20B (13GB) + Qwen3-Coder-30B (35GB)
Ask: <2s, Code: 5-10s
```

### Strategy 2: Balanced Triple (64GB)
```
Ministral-14B (16GB) + Qwen3-Coder-30B (35GB) + StarCoder2-15B (16GB)
Ask: Fast, Code: Quality, Autocomplete: Instant
```

### Strategy 3: Multi-Instance (54GB)
```
3x Qwen3-Coder-14B (18GB each)
Run 3 parallel coding tasks
```

### Strategy 4: Distributed (2x 395 systems)
```
Machine 1: GPT-OSS + Qwen3-Coder + StarCoder2 (64GB)
Machine 2: MiniMax or REAP-218B (101-92GB)
Connected via Headscale
```

---

## Open Questions to Explore

1. **Can we run GPT-OSS-20B + GLM-Q8 + REAP-218B simultaneously?**
   - Total: 138GB (8GB over, might need context reduction)
   - Test with reduced contexts: 4K + 32K + 32K

2. **Is Qwen3-Coder-30B better than GLM-Q8 for code?**
   - Need to download and benchmark
   - If yes: New Code mode champion

3. **Can Llama-4-Scout handle 1M tokens overnight?**
   - ~100GB total with 1M context
   - Needs swap, but might be worth it for research tasks

4. **Should we fine-tune Apriel-15B on VV Collective workflows?**
   - No RL contamination = clean base
   - Custom fine-tune for team's specific needs

---

## Continuation Prompt for Next Session

**Use this to continue work:**

```
I'm continuing AI model testing for AMD Strix Halo (128GB).

Current status:
- MiniMax-M2.1-Q3_K_XL (101GB, 229B params) finished downloading
- Need to run validation: ./scripts/test-minimax-unsloth.sh
- Validation tests 512p, 4K, and 16K context sizes
- Results will decide if we download DeepSeek-V3.1-TQ1_0 (170GB)

Next steps:
1. Run MiniMax validation and review results
2. Download efficient mid-sized models (Apriel, Ministral, Qwen3-Coder)
3. Test multi-mode simultaneous execution strategies
4. Setup llama-server instances for Roo integration

Key decisions:
- DeepSeek: Use TQ1_0 (170GB), NOT IQ1_S (192GB)
- Context testing: Now using 512, 4K, 16K, 32K, 65K (not just 512!)
- Multi-mode: Target 2-3 models running simultaneously

Please help me continue testing and document findings.

Reference: /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks
Docs: docs/SESSION-2026-01-22-UPDATES.md, docs/MODELS-TO-TEST.md
```

---

## Files to Reference

**Documentation:**
- `docs/AI-MODEL-STRATEGY.md` - Model selection guide
- `docs/MODELS-TO-TEST.md` - Complete testing roadmap
- `docs/MODE-SPECIFIC-TESTING.md` - Test prompts by mode
- `docs/SESSION-2026-01-22-UPDATES.md` - Today's decisions
- `docs/TESTING-CONTINUATION-PROMPT.md` - This file

**Scripts:**
- `scripts/test-minimax-unsloth.sh` - MiniMax validation
- `scripts/comprehensive-ai-test.sh` - Full test suite
- `scripts/compare-ollama-llamacpp.sh` - Backend comparison

**Results:**
- `results/` - Benchmark outputs (markdown + JSON)

---

## Quick Command Reference

**Run MiniMax validation:**
```bash
./scripts/test-minimax-unsloth.sh
```

**Start llama-server for testing:**
```bash
llama-server -m /path/to/model.gguf -c 65536 -ngl 999 -fa 1 --port 8001
```

**Test with curl:**
```bash
curl http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "test",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'
```

**Monitor memory:**
```bash
watch -n 1 free -h
```

**Check model VRAM estimate:**
```bash
python3 /path/to/gguf-vram-estimator.py model.gguf
```

---

**Last Updated:** 2026-01-22
**Status:** Ready for MiniMax validation and multi-mode testing
**Next Action:** Run MiniMax validation when download completes
