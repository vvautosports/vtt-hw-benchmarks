# Multi-Part Model Testing Guide

**Status:** Implementation in progress  
**Last Updated:** 2026-01-24

## Overview

Most large AI models are distributed as multi-part GGUF files (e.g., `model-00001-of-00002.gguf`, `model-00002-of-00002.gguf`). This guide explains how to properly test these models in the VTT benchmark suite.

## Current Implementation

### Quick Test Limitation (llama-bench)

**Current tool:** `llama-bench` (via Docker container)
- ✅ **Works with:** Single-file models only
- ❌ **Fails with:** Multi-part models
- **Use case:** Quick baseline testing (512p/128g)

**Example single-file models:**
- GLM-4.7-Flash-Q8 (33GB, single file)
- GPT-OSS-20B (13GB, single file)

**Example multi-part models:**
- DeepSeek-R1-Distill-Llama-70B (2 parts, 76GB total)
- MiniMax-M2.1 (2 parts, 81GB total)
- Qwen3-235B (3 parts, 98GB total)
- GLM-4.7-REAP-218B (2 parts, 92GB total)

### Comprehensive Test Support (llama-server)

**Recommended tool:** `llama-server` (direct execution, not containerized)
- ✅ **Works with:** Both single-file AND multi-part models
- ✅ **Supports:** Multiple context sizes (512, 4K, 16K, 32K, 65K)
- ✅ **Supports:** REST API for realistic testing
- **Use case:** Full model validation

## Multi-Part Model Directory Structure

```
/mnt/ai-models/
├── GLM-4.7-Flash-Q8/               # Single-file model
│   └── GLM-4.7-Flash-UD-Q8_K_XL.gguf
│
├── DeepSeek-R1-Distill-Llama-70B/  # Multi-part model
│   ├── DeepSeek-R1-Distill-Llama-70B-UD-Q8_K_XL-00001-of-00002.gguf
│   └── DeepSeek-R1-Distill-Llama-70B-UD-Q8_K_XL-00002-of-00002.gguf
│
└── Qwen3-235B-A22B-Instruct/       # 3-part model
    ├── Qwen3-235B-A22B-Instruct-2507-UD-Q3_K_XL-00001-of-00003.gguf
    ├── Qwen3-235B-A22B-Instruct-2507-UD-Q3_K_XL-00002-of-00003.gguf
    └── Qwen3-235B-A22B-Instruct-2507-UD-Q3_K_XL-00003-of-00003.gguf
```

## Testing Strategies

### Strategy 1: Quick Test (Single-File Only)

**Purpose:** Fast baseline validation (2-3 minutes)

```bash
cd docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test
```

**What it does:**
- Tests first model in config (if single-file)
- Skips multi-part models
- Uses llama-bench in container
- Tests 512p/128g only

**Best for:**
- Initial validation
- CI/CD pipelines
- Quick comparisons

### Strategy 2: Comprehensive Test (All Models)

**Purpose:** Full validation with multiple context sizes (30-45 minutes per model)

**Option A: Direct llama-server (Recommended)**

```bash
# Test single model with multiple contexts
llama-server \
  -m /mnt/ai-models/DeepSeek-R1-Distill-Llama-70B/DeepSeek-R1-Distill-Llama-70B-UD-Q8_K_XL-00001-of-00002.gguf \
  -c 65536 -ngl 999 -fa 1 -mmp 0 \
  --port 8001 --host 0.0.0.0

# Test with curl (from another terminal)
curl http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "test",
    "messages": [{"role": "user", "content": "Write a function to reverse a string"}],
    "max_tokens": 128
  }'
```

**Option B: Automated script (TODO)**

```bash
# This will be implemented in scripts/test-comprehensive-models.sh
./scripts/test-comprehensive-models.sh --mode all
```

### Strategy 3: Mixed Approach (Recommended)

1. **Quick test** with single-file models for baseline
2. **Comprehensive test** with multi-part models using llama-server
3. **Compare results** across all models

## Implementation Plan

### Phase 1: Document Current State ✅

- [x] Document llama-bench limitation
- [x] Document multi-part model structure
- [x] Update models-inventory.yaml ordering

### Phase 2: Enhanced Scripts (TODO)

Create `scripts/test-comprehensive-models.sh`:

```bash
#!/bin/bash
# Test all models (single-file and multi-part)
# Uses llama-server for comprehensive testing
# Supports multiple context sizes: 512, 4K, 16K, 32K, 65K

FEATURES:
- Auto-detect single vs multi-part models
- Start llama-server per model
- Test multiple context sizes
- Generate comparison report
- Export JSON results
```

### Phase 3: Container Enhancement (TODO)

Create new Docker container with llama-server:

```dockerfile
# docker/llama-server/Dockerfile
ARG BACKEND=vulkan-radv
FROM docker.io/kyuz0/amd-strix-halo-toolboxes:${BACKEND}

# llama-server supports multi-part models natively
COPY test-server.sh /test-server.sh
RUN chmod +x /test-server.sh

ENTRYPOINT ["/test-server.sh"]
```

### Phase 4: Configuration Updates (TODO)

Update `models-inventory.yaml` with test strategies:

```yaml
default_models:
  - name: "GLM-4.7-Flash-Q8"
    test_strategy: "both"  # llama-bench + llama-server
    
  - name: "DeepSeek-R1-Distill-Llama-70B"
    test_strategy: "server_only"  # Skip llama-bench (multi-part)
```

## Current Workaround

The current `run-ai-models.sh` script handles multi-part models by:

1. Detecting multi-part files (lines 187-233)
2. Counting parts (00001-of-00002 pattern)
3. Mounting entire directory instead of single file (line 246)

**However:** llama-bench still fails because it expects a single file path.

**Temporary solution:** Run quick tests with single-file models only, use manual llama-server for multi-part models.

## Model Classification

### Single-File Models (llama-bench compatible)
- ✅ GLM-4.7-Flash-Q8 (33GB)
- ✅ GPT-OSS-20B (13GB)
- ✅ Apriel-1.5-15B-Thinker (~15GB)
- ✅ Ministral-3-14B-Instruct (~14GB)

### Multi-Part Models (llama-server required)
- ⚠️ DeepSeek-R1-Distill-Llama-70B (2 parts, 76GB)
- ⚠️ MiniMax-M2.1 (2 parts, 81GB)
- ⚠️ Qwen3-235B (3 parts, 98GB)
- ⚠️ GLM-4.7-REAP-218B (2 parts, 92GB)
- ⚠️ GLM-4.7-Flash-BF16 (2 parts, 56GB)
- ⚠️ Gemma-3-27B (2 parts, ~54GB)

## Testing Matrix

| Model | Size | Parts | llama-bench | llama-server | Priority |
|-------|------|-------|-------------|--------------|----------|
| GLM-4.7-Flash-Q8 | 33GB | 1 | ✅ | ✅ | High (baseline) |
| GPT-OSS-20B | 13GB | 1 | ✅ | ✅ | High (speed) |
| DeepSeek-R1-70B | 76GB | 2 | ❌ | ✅ | High (reasoning) |
| MiniMax-M2.1 | 81GB | 2 | ❌ | ✅ | High (testing) |
| REAP-218B | 92GB | 2 | ❌ | ✅ | Medium (reasoning) |
| Qwen3-235B | 98GB | 3 | ❌ | ✅ | Medium (ultra-large) |

## Next Steps

1. **Immediate:** Use single-file models for quick tests
2. **Short-term:** Create llama-server test scripts
3. **Medium-term:** Build enhanced Docker container
4. **Long-term:** Unified testing framework

## Related Documentation

- [AI Model Strategy](../AI-MODEL-STRATEGY.md)
- [Testing Continuation Prompt](../TESTING-CONTINUATION-PROMPT.md)
- [Model Configuration](../../models-inventory.yaml)
- [Docker README](../../docker/README.md)

---

**Key Takeaway:** Quick tests work with single-file models only. For comprehensive testing of multi-part models, use llama-server directly or wait for enhanced scripts.
