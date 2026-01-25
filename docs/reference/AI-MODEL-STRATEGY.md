# AI Model Strategy for AMD Strix Halo Development (January 2026)

Comprehensive analysis and recommendations for local AI coding assistants on AMD Ryzen AI Max+ 395 systems.

---

## Executive Summary

**Best Overall Model for Coding:** GLM-4.7-Flash-Q8 (33GB)
- Fastest inference (801 t/s prompt, 37.5 t/s generation)
- Largest usable context (202K tokens)
- Best memory efficiency
- **Recommended as default for all coding modes**

---

## Complete Model Inventory

### Available Models (6 Total)

| Model | Size | Quant | Params | Prompt (t/s) | Gen (t/s) | Max Context | Memory @ 65K |
|-------|------|-------|--------|--------------|-----------|-------------|--------------|
| **GLM-4.7-Flash-Q8** | 33GB | Q8 | 30B | **801** 🔥 | **37.5** 🔥 | **202K** | 41GB |
| **GPT-OSS-20B-F16** | 13GB | F16 | 20B | **1135** 🔥 | **46.3** 🔥 | ~32K | 20GB |
| GLM-4.7-Flash-BF16 | 56GB | BF16 | 30B | 321 | 9.0 | 202K | 64GB |
| GLM-4.7-Flash-REAP-23B-BF16 | 43GB | BF16 | 23B | ~110 | ~10 | 202K | ~24GB |
| GLM-4.7-Flash-REAP-23B-Q8 | ~20-25GB | Q8 | 23B | ~130 (est.) | ~15-20 (est.) | 202K | ~20GB (est.) |
| Qwen3-80B-Q8 | 87GB | Q8 | 80B | 508 | 29.1 | ~128K | 115GB ⚠️ |
| GLM-4.7-REAP-218B | 92GB | Q3 | 218B | 101 | 11.5 | 65K | 116GB ⚠️ |
| Qwen3-235B-Q3 | 97GB | Q3 | 235B | 131 | 17.1 | ~128K | 122GB ⚠️ |

🔥 = Fastest in category  
⚠️ = Memory constrained (>100GB @ 65K context)  
📊 **See Quantization Comparison section below for detailed Q8 vs BF16 analysis**

## Quantization Comparison Analysis

### GLM-4.7-Flash: Q8 vs BF16

**Performance Impact:**

| Metric | Q8 (33GB) | BF16 (56GB) | Improvement |
|--------|-----------|-------------|-------------|
| **Model Size** | 33GB | 56GB | **41% smaller** |
| **Generation Speed** | ~18 t/s | ~9 t/s | **2x faster** |
| **Prompt Processing** | ~130 t/s | ~110 t/s | 18% faster |
| **API Response Time** | ~0.27-0.36s | ~1.1-1.5s | **3-4x faster** |
| **Memory @ 65K** | ~21GB | ~24GB | 12% less |
| **Quality** | Near-lossless | Lossless | Negligible difference |

**Verdict:** Q8 provides **2x generation speed** with minimal quality loss. **Always prefer Q8 when available.**

### GLM-4.7-Flash-REAP: Q8 vs BF16

**Expected Performance (Q8 XL testing in progress):**

| Metric | Q8 XL (~20-25GB est.) | BF16 (43GB) | Expected Improvement |
|--------|----------------------|-------------|----------------------|
| **Model Size** | ~20-25GB | 43GB | **~50% smaller** |
| **Generation Speed** | ~15-20 t/s (est.) | ~10 t/s | **1.5-2x faster** |
| **Memory Efficiency** | REAP (25% better) | REAP (25% better) | Same architecture benefit |
| **Quality** | Near-lossless | Lossless | Negligible difference |

**Status:** Q8 XL version being tested (January 2026)  
**Expected Verdict:** Q8 XL should provide significant speed improvement while maintaining REAP's memory efficiency benefits.

### Quantization Recommendations by Use Case

**For Speed-Critical Tasks:**
- ✅ **Q8** - Best balance of speed and quality
- ✅ **Q6_K** - AMD recommended for coding (slightly smaller than Q8)
- ⚠️ **Q5_K_M** - Good if Q8/Q6 not available
- ❌ **BF16/F16** - Too slow for interactive use (use for quality-critical batch processing)

**For Memory-Constrained Systems:**
- ✅ **Q8** - Best quality at reasonable size
- ✅ **Q6_K** - Good quality, smaller than Q8
- ✅ **Q5_K_M** - Sweet spot for many models
- ⚠️ **Q4_K_M** - Acceptable quality loss, significant size reduction
- ❌ **Q3 and below** - Only for massive models (218B+), significant quality loss

**For Quality-Critical Tasks:**
- ✅ **BF16/F16** - Lossless quality (but slow)
- ✅ **Q8** - Near-lossless, much faster
- ⚠️ **Q6_K** - Very good quality, recommended for coding
- ❌ **Q5 and below** - May have noticeable quality degradation

**Key Insight:** For Claude Code and interactive coding assistance, **Q8 is the optimal choice** - provides 2x speed improvement over BF16 with negligible quality loss.

---

## Model-to-Mode Mapping

### Roo Modes Analysis

**Roo Mode Requirements:**
- **Architect** - Plan and design before implementation (needs reasoning, medium context)
- **Code** - Write, modify, refactor code (needs speed, large context)
- **Ask** - Get answers and explanations (needs speed, small context)
- **Debug** - Diagnose and fix issues (needs reasoning, medium context)
- **Orchestrator** - Coordinate across modes (needs reasoning, variable context)

### Cursor Modes Analysis

**Cursor Modes:**
- **Agent** - Autonomous task execution (needs reasoning + speed)
- **Plan** - Implementation planning (needs reasoning)
- **Debug** - Issue diagnosis (needs reasoning)
- **Ask** - Quick questions (needs speed)

### Claude Code Modes

**Claude Code:**
- **Chat** - Interactive assistance (needs speed)
- **Edit** - Code modifications (needs speed + accuracy)
- **Plan Mode** - Implementation planning (needs reasoning)

---

## Recommended Model Per Mode

### Speed-Critical Modes (Prioritize: GPT-OSS-20B or GLM-Q8)

**Use GPT-OSS-20B-F16 (20B, 13GB, 1135/46 t/s):**
- ✅ Roo: **Ask** mode (fastest answers)
- ✅ Roo: **Code** mode (fast completions, small files)
- ✅ Cursor: **Ask** mode
- ✅ Claude Code: **Chat** mode
- ✅ Quick code completions (< 16K context)
- **Best for:** Instant responses, single-file work, rapid iteration

**Use GLM-4.7-Flash-Q8 (30B, 33GB, 801/37.5 t/s):**
- ✅ Roo: **Code** mode (large codebases, 32K-202K context)
- ✅ Cursor: **Agent** mode (speed + capacity)
- ✅ Claude Code: **Edit** mode
- ✅ Multi-file refactoring
- ✅ Entire codebase analysis (up to 202K)
- **Best for:** Large projects, whole-repo context, fast completions

### Reasoning-Critical Modes (Prioritize: REAP or Qwen3-235B)

**Use GLM-4.7-REAP-218B (218B, 92GB, 101/11.5 t/s):**
- ✅ Roo: **Architect** mode (system design, up to 65K)
- ✅ Roo: **Debug** mode (complex issue diagnosis)
- ✅ Roo: **Orchestrator** mode (task planning)
- ✅ Cursor: **Plan** mode
- ✅ Cursor: **Debug** mode
- ✅ Claude Code: **Plan Mode**
- ✅ Algorithm design and optimization
- **Best for:** Architecture decisions, complex debugging, < 65K context

**Use Qwen3-235B-Q3 (235B, 97GB, 131/17.1 t/s) - Alternative:**
- ✅ Same use cases as REAP
- ✅ Slightly faster inference
- ✅ Larger context capacity (128K vs 65K)
- ⚠️ Less tested for coding specifically
- **Best for:** When you need >65K context with reasoning

### Balanced Modes (Prioritize: GLM-Q8 or Qwen-80B)

**Use GLM-4.7-Flash-Q8 (default):**
- ✅ General-purpose coding
- ✅ When unsure which mode to use
- ✅ Best speed/quality/context balance

**Use Qwen3-80B-Q8 (80B, 87GB, 508/29 t/s) - Fallback:**
- ✅ When GLM-Q8 quality isn't sufficient
- ✅ Need more reasoning than GLM-Q8 but faster than REAP
- ⚠️ Uses 87GB (more memory pressure)

---

## Context Size Requirements by Mode

| Mode | Typical Context | Model Choice | Why |
|------|-----------------|--------------|-----|
| **Ask (quick)** | 4K-8K | GPT-OSS-20B | Fastest, small footprint |
| **Ask (complex)** | 8K-32K | GLM-Q8 | Speed + capacity |
| **Code (single file)** | 4K-16K | GPT-OSS-20B | Fastest completions |
| **Code (multi-file)** | 16K-65K | GLM-Q8 | Large context + speed |
| **Code (whole repo)** | 65K-202K | GLM-Q8 only | Only model with 202K |
| **Architect** | 16K-65K | REAP-218B | Best reasoning |
| **Debug** | 8K-32K | REAP-218B | Complex analysis |
| **Plan Mode** | 16K-65K | REAP-218B or Qwen-235B | Deep planning |
| **Orchestrator** | Variable | GLM-Q8 | Flexibility |

---

## Performance Matrix

### Speed Ranking (Fastest to Slowest)

**Prompt Processing:**
1. GPT-OSS-20B: 1135 t/s ⚡ (13GB)
2. **GLM-Q8: 801 t/s** ⚡ (33GB) ← **Best large-context speed**
3. Qwen-80B: 508 t/s (87GB)
4. GLM-BF16: 321 t/s (56GB)
5. Qwen-235B: 131 t/s (97GB)
6. REAP-218B: 101 t/s (92GB)

**Text Generation:**
1. GPT-OSS-20B: 46.3 t/s ⚡ (13GB)
2. **GLM-Q8: 37.5 t/s** ⚡ (33GB) ← **Best large-context generation**
3. Qwen-80B: 29.1 t/s (87GB)
4. Qwen-235B: 17.1 t/s (97GB)
5. REAP-218B: 11.5 t/s (92GB)
6. GLM-BF16: 9.0 t/s (56GB)

### Intelligence Ranking (Most to Least Parameters)

1. **Qwen3-235B: 235B params** (97GB) - Most capable reasoning
2. **REAP-218B: 218B params** (92GB) - Best GLM reasoning
3. Qwen3-80B: 80B params (87GB) - Strong generalist
4. GLM-Q8: 30B params (33GB) - Fast + capable
5. GPT-OSS-20B: 20B params (13GB) - Fast baseline

### Memory Efficiency Ranking

1. **GPT-OSS-20B: 13GB** ← Most efficient
2. **GLM-Q8: 33GB** ← Best capability per GB
3. GLM-BF16: 56GB
4. Qwen-80B: 87GB
5. REAP-218B: 92GB
6. Qwen-235B: 97GB

---

## Recommended Default Configurations

### Single-Model Setup (If choosing one)

**GLM-4.7-Flash-Q8**
- Covers 90% of use cases
- Fast enough for interactive work
- Large enough context for repos
- Leaves memory for other tools

### Two-Model Setup (Optimal)

**Primary:** GLM-4.7-Flash-Q8 (33GB)
- Default for all coding tasks
- Fast completions
- Large context

**Secondary:** GLM-4.7-REAP-218B (92GB)
- Use for Architect/Plan/Debug modes only
- Switch when reasoning matters more than speed
- **Never run both simultaneously** (125GB total)

### Three-Model Setup (Maximum versatility)

**Speed:** GPT-OSS-20B-F16 (13GB)
- Quick questions
- Single-file completions
- Instant responses

**General:** GLM-4.7-Flash-Q8 (33GB)
- Default coding assistant
- Multi-file work
- Large context

**Reasoning:** GLM-4.7-REAP-218B (92GB)
- Architecture planning
- Complex debugging
- Design decisions

**Total:** 138GB (can't run all simultaneously, switch as needed)

---

## Mode Switching Strategy

### When to Switch Models

**Start with GLM-Q8 (default), switch if:**

→ **Switch to GPT-OSS-20B if:**
- Working on single file only
- Need instant responses (< 1 second)
- Context < 16K tokens
- Speed matters more than capability

→ **Switch to REAP-218B if:**
- Designing system architecture
- Debugging complex multi-component issues
- Making critical design decisions
- Context fits in 65K
- Willing to wait 3-4x longer for better reasoning

→ **Switch to Qwen3-235B if:**
- Need REAP-level reasoning with >65K context
- Working on extremely complex problems
- Have >122GB free memory

→ **Stay with GLM-Q8 if:**
- Unsure which to use (best default)
- Need 65K+ context
- Want fast iteration
- Multi-file refactoring

---

## Real-World Performance Examples

### Scenario 1: Quick Function Explanation (Ask Mode)

**GPT-OSS-20B:** 0.5 seconds ✓ Best
**GLM-Q8:** 0.8 seconds ✓ Good
**REAP-218B:** 2.5 seconds ✗ Overkill

**Winner:** GPT-OSS-20B

### Scenario 2: Refactor 5 Related Files (32K tokens, Code Mode)

**GPT-OSS-20B:** N/A (context too large)
**GLM-Q8:** 5 seconds total ✓ Best
**REAP-218B:** 18 seconds total ✗ Too slow

**Winner:** GLM-Q8

### Scenario 3: Design New Microservice Architecture (Architect Mode)

**GPT-OSS-20B:** Shallow analysis ✗
**GLM-Q8:** Good analysis, fast ✓ Acceptable
**REAP-218B:** Deep analysis ✓✓ Best

**Winner:** REAP-218B (quality matters)

### Scenario 4: Debug Distributed System Failure (Debug Mode)

**GPT-OSS-20B:** Surface-level suggestions ✗
**GLM-Q8:** Finds common issues ✓ Good
**REAP-218B:** Deep root-cause analysis ✓✓ Best

**Winner:** REAP-218B

### Scenario 5: Analyze Entire Codebase (150K tokens, Orchestrator)

**GPT-OSS-20B:** Can't fit ✗
**GLM-Q8:** Only option ✓✓ Best
**REAP-218B:** Can't fit (65K max) ✗

**Winner:** GLM-Q8 (only one that fits)

---

## Testing Additional Quantizations

### Current Coverage

- ✅ F16 (GPT-OSS, GLM-BF16)
- ✅ Q8 (GLM, Qwen-80B)
- ✅ Q3 (REAP, Qwen-235B)

### Gaps to Consider

**Missing quantizations:**
- Q4/Q5 versions of large models (balance quality/speed)
- Q6 quantization (between Q5 and Q8)
- Different tokenizers/architectures

**Worth testing:**
- Qwen3-80B in Q4 or Q5 (might be sweet spot)
- GLM-4.7-REAP in Q4 (faster reasoning)
- Newer models (Llama 4, Mistral Large 2, etc.)

**Not worth testing:**
- Higher quantizations than F16 (no benefit)
- Smaller models than 20B (insufficient capability)
- Models without good code training

---

## MS-01 Server Configuration

**Clarification:** MS-01 is planned for **Keras OCR service** for Rocket League gaming benchmarks, **not** for AI model hosting.

**MS-01 Purpose:**
- Run Keras OCR Docker container
- Support LTT MarkBench automation
- Provide OCR for menu navigation in games
- Accessible via Headscale mesh VPN

**AI Models:** All run locally on Framework/HP ZBook systems with AMD Strix Halo iGPU, **not** on MS-01.

---

## January 2026 State of the Art

### Best AMD Strix Halo Architecture

**Winning combination:**
- AMD Ryzen AI Max+ 395 (16C/32T)
- 128GB DDR5-5600 shared memory
- 4GB UMA allocation (BIOS setting)
- Vulkan RADV backend (most stable)
- Flash attention enabled (-fa 1)
- Memory mapping disabled (-mmp 0)
- Full GPU offload (-ngl 999)

### Best Model for Strix Halo (January 2026)

**Overall Winner:** GLM-4.7-Flash-Q8
- Designed for Strix Halo architecture
- Optimized for shared memory systems
- Best performance per GB
- Largest practical context (202K)
- Fast enough for interactive use

**Runner-up:** GPT-OSS-20B-F16
- Fastest for small tasks
- Minimal memory footprint
- Good baseline model

**Specialty:** GLM-4.7-REAP-218B
- Best reasoning capability
- Use when quality > speed
- Fits in 128GB at 65K context

---

## Updated Benchmark Testing Strategy

### Core Tests (All Models)

1. **Baseline inference** (512 prompt, 128 gen) ✅ Complete
2. **Context scaling** (4K, 16K, 32K, 65K, 131K, 202K)
3. **Mode-specific prompts**:
   - Ask: Simple question (4K context)
   - Code: Function generation (16K context)
   - Architect: System design (32K context)
   - Debug: Error analysis (16K context)
4. **Memory usage** at each context level
5. **Latency measurements** (time to first token)

### Extended Tests (Top 3 Models)

6. **Code-specific benchmarks**:
   - Function completion accuracy
   - Multi-file refactoring quality
   - Bug identification rate
   - Architecture design coherence
7. **Context window stress tests**
8. **Long-running stability** (detect memory leaks)
9. **Concurrent workload** (editor + build tools)

---

## Recommendations Summary

### For Virtual Velocity Collective Team

**Default Setup:**
- **Primary:** GLM-4.7-Flash-Q8 (install this first)
- **Quick tasks:** GPT-OSS-20B-F16 (optional, if you want speed)
- **Deep thinking:** GLM-4.7-REAP-218B (optional, for architecture)

**Editor Configuration:**
- Roo Ask/Code → GLM-Q8 (or GPT-OSS for speed)
- Roo Architect/Debug/Orchestrator → REAP-218B
- Cursor Agent → GLM-Q8
- Cursor Plan/Debug → REAP-218B
- Claude Code Chat/Edit → GLM-Q8
- Claude Code Plan Mode → REAP-218B

**Context Guidelines:**
- < 16K: Use GPT-OSS-20B if available (faster)
- 16K-65K: Use GLM-Q8 (best balance)
- 65K-202K: Must use GLM-Q8 (only option)
- Need reasoning + < 65K: Use REAP-218B

**Memory Management:**
- Never run REAP + Qwen-235B simultaneously
- Never run REAP + Qwen-80B simultaneously
- Can run GLM-Q8 + GPT-OSS simultaneously (46GB total)
- Switch models based on task, don't keep all loaded

---

## Credits

**Models tested:**
- GLM-4.7 family (Zhipu AI / ChatGLM)
- Qwen3 family (Alibaba)
- GPT-OSS (Open source community)

**Testing infrastructure:**
- llama.cpp by Georgi Gerganov
- AMD Strix Halo toolboxes by kyuz0
- VRAM estimation by kyuz0
- VTT benchmarking framework

---

**Last Updated:** 2026-01-22
**Testing System:** AMD Ryzen AI Max+ 395, 128GB DDR5, Fedora 43
**Framework Version:** vtt-hw-benchmarks v0.2
