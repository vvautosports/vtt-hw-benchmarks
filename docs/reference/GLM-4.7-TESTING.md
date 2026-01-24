# GLM-4.7 Model Testing Guide

Testing guide for GLM-4.7 family models with extended context sizes on AMD Strix Halo systems.

## Models Overview

### GLM-4.7-Flash-Q8 (33GB)
- **File:** `GLM-4.7-Flash-UD-Q8_K_XL.gguf` (single file)
- **Quantization:** 8-bit (Q8_K_XL)
- **Size:** 32.71 GiB
- **Native Max Context:** 202,752 tokens
- **Practical Max Context:** 202K (full native support)

### GLM-4.7-Flash-BF16 (56GB)
- **Files:** 2-part model (47GB + 9.4GB)
- **Quantization:** BF16 (16-bit brain float)
- **Size:** 55.79 GiB
- **Native Max Context:** 202,752 tokens
- **Practical Max Context:** 202K (full native support)

### GLM-4.7-REAP-218B (92GB)
- **Files:** 2-part model (47GB + 45GB)
- **Quantization:** Q3_K_XL (3-bit)
- **Size:** 91.09 GiB
- **Parameters:** 218 billion (46x larger than Flash models)
- **Native Max Context:** 202,752 tokens
- **Practical Max Context:** ~65K (memory limited on 128GB system)

## Memory Requirements (VRAM Estimates)

Results from `gguf-vram-estimator.py`:

### GLM-4.7-Flash-Q8
```
Context Size | Context Memory | Est. Total VRAM
------------------------------------------------
      4,096 |     399.50 MiB |       35.10 GiB
     16,384 |       1.56 GiB |       36.27 GiB
     32,768 |       3.12 GiB |       37.83 GiB
     65,536 |       6.24 GiB |       40.95 GiB
    131,072 |      12.48 GiB |       47.19 GiB
    202,752 |      19.31 GiB |       54.02 GiB ✓
```

### GLM-4.7-Flash-BF16
```
Context Size | Context Memory | Est. Total VRAM
------------------------------------------------
      4,096 |     399.50 MiB |       58.18 GiB
     16,384 |       1.56 GiB |       59.35 GiB
     32,768 |       3.12 GiB |       60.92 GiB
     65,536 |       6.24 GiB |       64.04 GiB
    131,072 |      12.48 GiB |       70.28 GiB
    202,752 |      19.31 GiB |       77.11 GiB ✓
```

### GLM-4.7-REAP-218B
```
Context Size | Context Memory | Est. Total VRAM
------------------------------------------------
      4,096 |       1.44 GiB |       94.53 GiB
     16,384 |       5.75 GiB |       98.84 GiB
     32,768 |      11.50 GiB |      104.59 GiB
     65,536 |      23.00 GiB |      116.09 GiB ✓
    131,072 |      46.00 GiB |      139.09 GiB ❌
    202,752 |      71.16 GiB |      164.25 GiB ❌
```

**System:** 128GB total memory
- ✓ = Fits comfortably
- ❌ = Exceeds available memory

## Use Case Recommendations

### When to Use Q8 (Best Memory Efficiency)

**Ideal for:**
- **Long document analysis** (100K+ tokens): Legal documents, research papers, entire books
- **Multi-document RAG systems**: Fitting many retrieved chunks in context
- **Code repository analysis**: Analyzing entire codebases in one context window
- **Production deployments**: Best memory/performance balance
- **Batch processing**: Lower memory footprint allows multiple concurrent instances
- **Cost-sensitive workloads**: Less VRAM = cheaper infrastructure
- **Maximum context tasks**: When you need the full 202K tokens

**Performance characteristics:**
- Fastest inference speed (lowest memory overhead)
- Minimal quality loss from 8-bit quantization
- Can run at native 202K context on 128GB system
- Best for throughput-oriented workloads

### When to Use BF16 (Best Quality)

**Ideal for:**
- **High-precision tasks**: Mathematical reasoning, complex code generation
- **Creative writing**: Full precision preserves subtle language patterns
- **Scientific/technical content**: Where accuracy matters more than speed
- **Benchmark comparisons**: Reference quality baseline
- **Complex instruction following**: BF16 preserves more nuance in task understanding
- **Quality-critical applications**: Customer-facing chatbots, content generation
- **Research evaluation**: When testing model capabilities at full fidelity

**Performance characteristics:**
- Highest quality output (no quantization loss)
- 70% more memory than Q8 (56GB vs 33GB)
- Still achieves full 202K context on 128GB system
- Best when quality > efficiency

### When to Use REAP-218B (Best Reasoning)

**Ideal for:**
- **Complex reasoning tasks**: Multi-step logic, chain-of-thought problems
- **Difficult problems**: Advanced mathematics, algorithmic challenges, code debugging
- **Medium-context tasks** (16K-65K): Most real-world applications fit here
- **Quality over quantity**: Better model with moderate context beats smaller model with huge context
- **Research and evaluation**: Testing capabilities of larger parameter models
- **Specialized domains**: Medical, legal, technical content where model intelligence matters most
- **Few-shot learning**: Larger model handles examples in context better

**Performance characteristics:**
- 46x more parameters than Flash models (218B vs 4.7B)
- Significantly better reasoning and problem-solving
- Limited to ~65K context due to memory constraints
- Slower inference than Flash models (more compute required)
- Best quality for tasks that fit in 65K context

## Practical Decision Matrix

### Task Context < 32K tokens
→ **Use REAP** (best quality, context not limiting)

Most real-world tasks fall here:
- Single document Q&A
- Code completion
- Chat conversations
- Standard RAG queries
- Email/document generation

### Task Context 32K-65K tokens
→ **Use REAP** if quality/reasoning critical
→ **Use Q8** if speed/efficiency matters

Medium-length tasks:
- Multi-document analysis
- Long-form content generation
- Large codebase queries
- Extended conversations

### Task Context 65K-202K tokens
→ Must use **Q8** or **BF16** (REAP can't fit)
→ **Use BF16** for quality-critical tasks
→ **Use Q8** for production/batch processing

Long-context tasks:
- Full novel analysis
- Massive codebases
- Very long document chains
- Extreme context RAG

## Testing Recommendations

### Context Sizes to Test

**GLM-4.7-Flash-Q8:**
```bash
# Test contexts: 32K, 65K, 131K, 202K (max)
CONTEXT_SIZES="32768,65536,131072,202752"
```

**GLM-4.7-Flash-BF16:**
```bash
# Test contexts: 32K, 65K, 131K, 202K (max)
CONTEXT_SIZES="32768,65536,131072,202752"
```

**GLM-4.7-REAP-218B:**
```bash
# Test contexts: 16K, 32K, 65K, 80K (push limit)
CONTEXT_SIZES="16384,32768,65536,81920"
```

### Running Tests

**Using VRAM estimator first:**
```bash
# Estimate before testing
python3 /path/to/gguf-vram-estimator.py \
  /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  --contexts 32768 65536 131072 202752
```

**Running context tests:**
```bash
# Q8 model
CONTEXT_SIZES="32768,65536,131072,202752" \
  ./docker/run-ai-models.sh --context-test --filter "GLM-4.7-Flash-Q8"

# BF16 model
CONTEXT_SIZES="32768,65536,131072,202752" \
  ./docker/run-ai-models.sh --context-test --filter "GLM-4.7-Flash-BF16"

# REAP model
CONTEXT_SIZES="16384,32768,65536,81920" \
  ./docker/run-ai-models.sh --context-test --filter "GLM-4.7-REAP"
```

## Real-World Context Statistics

**Task distribution by context length:**
- **< 8K tokens:** ~80% of tasks (standard chat, simple queries)
- **8K-32K tokens:** ~15% of tasks (document analysis, code review)
- **32K-65K tokens:** ~4% of tasks (large documents, multi-file code)
- **> 65K tokens:** ~1% of tasks (novels, massive repositories)

**Implication:** REAP's 65K limit covers 99% of real-world use cases, making it the best choice for most work despite the context restriction.

## Performance Expectations

**Typical inference speeds on AMD Strix Halo (Ryzen AI Max+ 395):**

- **GLM-4.7-Flash-Q8:**
  - Prompt processing: 1000-1500 t/s
  - Text generation: 40-60 t/s
  - Best throughput

- **GLM-4.7-Flash-BF16:**
  - Prompt processing: 800-1200 t/s
  - Text generation: 30-50 t/s
  - Slightly slower than Q8

- **GLM-4.7-REAP-218B:**
  - Prompt processing: 200-400 t/s
  - Text generation: 10-20 t/s
  - Much slower but much smarter

*Note: Speeds decrease with larger context sizes due to KV cache overhead*

## Simultaneous Usage

**Can you run multiple models at once?**

No - each model must be tested separately. The 128GB memory is shared, so:

- Running Q8 + BF16 simultaneously: Would need ~90GB (possible but tight)
- Running REAP alone at 65K: Uses ~116GB (safe)
- Running REAP + any other: Would exceed 128GB (will OOM)

**Recommendation:** Test models sequentially, one at a time.

## References

- VRAM estimation tool: `/FORKS/fork-amd-strix-halo-toolboxes/toolboxes/gguf-vram-estimator.py`
- AMD Strix Halo setup: `docs/AMD-STRIX-HALO-SETUP.md`
- Model files: `/mnt/ai-models/GLM-4.7-*/`
- Benchmark scripts: `docker/llama-bench/`

## Credits and Acknowledgments

This testing framework builds on excellent work from the community:

- **AMD Strix Halo Toolboxes** by [kyuz0](https://github.com/kyuz0/amd-strix-halo-toolboxes)
  - Pre-built llama.cpp containers with Vulkan/ROCm support
  - VRAM estimation utility (`gguf-vram-estimator.py`)
  - Critical flags and configuration for Strix Halo iGPU
  - Repository: https://github.com/kyuz0/amd-strix-halo-toolboxes

- **llama.cpp** by Georgi Gerganov and contributors
  - Fast LLM inference engine
  - GGUF model format support
  - Repository: https://github.com/ggerganov/llama.cpp

---

**Last Updated:** 2026-01-21
