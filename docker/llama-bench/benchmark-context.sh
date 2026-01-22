#!/bin/bash
# LLaMA Inference Benchmark with Variable Context Sizes
# Tests models at different context lengths to find practical maximum

MODEL_PATH="${MODEL_PATH:-/models/model.gguf}"
CONTEXT_SIZES="${CONTEXT_SIZES:-32768,65536,131072}"
PROMPT_SIZE="${PROMPT_SIZE:-512}"
GEN_SIZE="${GEN_SIZE:-128}"
BATCH_SIZE="${BATCH_SIZE:-512}"
THREADS="${THREADS:-$(nproc)}"
USE_FIT="${USE_FIT:-1}"

# Strix Halo CRITICAL flags
STRIX_FLAGS="-fa 1 -mmp 0 -ngl 999"

echo "=== LLaMA Context Size Benchmark (AMD Strix Halo) ==="
echo "System: $(uname -m)"
echo "Date: $(date -Iseconds)"
echo "Model: $MODEL_PATH"
echo ""

# Check if model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found at $MODEL_PATH"
    exit 1
fi

# Get system info
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f", $2/1024/1024}')

echo "CPU: $CPU_MODEL"
echo "Cores: $CPU_CORES"
echo "Memory: ${MEM_TOTAL} GB"
echo ""

# Detect backend
BACKEND="unknown"
if llama-cli --version 2>&1 | grep -qi "vulkan"; then
    BACKEND="vulkan"
elif llama-cli --version 2>&1 | grep -qi "rocm\|hip"; then
    BACKEND="rocm"
fi
echo "Backend: $BACKEND"
echo ""

# Parse context sizes (comma-separated)
IFS=',' read -ra CTX_ARRAY <<< "$CONTEXT_SIZES"

echo "Testing context sizes: ${CONTEXT_SIZES}"
echo "Flags: $STRIX_FLAGS"
echo "Prompt: ${PROMPT_SIZE} tokens, Generate: ${GEN_SIZE} tokens"
echo ""

# Fit flag
FIT_FLAG=""
if [ "$USE_FIT" = "1" ]; then
    FIT_FLAG="-fit on"
fi

# Initialize results array
declare -a RESULTS
SUCCESSFUL_TESTS=0
FAILED_TESTS=0

# Test each context size
for ctx_size in "${CTX_ARRAY[@]}"; do
    echo "═══════════════════════════════════════════════════════"
    echo "Testing context size: $ctx_size tokens"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    # Run llama-bench with this context size
    OUTPUT=$(llama-bench \
        -m "$MODEL_PATH" \
        -c "$ctx_size" \
        -p "$PROMPT_SIZE" \
        -n "$GEN_SIZE" \
        -b "$BATCH_SIZE" \
        -t "$THREADS" \
        $STRIX_FLAGS \
        $FIT_FLAG \
        2>&1)

    EXIT_CODE=$?

    echo "$OUTPUT"
    echo ""

    # Check for errors
    if [ $EXIT_CODE -ne 0 ] || echo "$OUTPUT" | grep -qi "error\|failed\|out of memory\|oom"; then
        echo "❌ FAILED: Context size $ctx_size exceeded available memory or crashed"
        echo ""

        RESULTS+=("{\"context_size\": $ctx_size, \"status\": \"failed\", \"error\": \"OOM or error\"}")
        FAILED_TESTS=$((FAILED_TESTS + 1))

        # Stop testing larger contexts if we hit OOM
        echo "Stopping further tests (OOM encountered)"
        break
    else
        # Parse results
        PP_TPS=$(echo "$OUTPUT" | grep "pp${PROMPT_SIZE}" | awk -F'|' '{print $(NF-1)}' | awk '{print $1}' | head -1)
        TG_TPS=$(echo "$OUTPUT" | grep "tg${GEN_SIZE}" | awk -F'|' '{print $(NF-1)}' | awk '{print $1}' | head -1)

        PP_TPS=${PP_TPS:-0}
        TG_TPS=${TG_TPS:-0}

        echo "✅ SUCCESS"
        echo "   Prompt Processing: ${PP_TPS} tokens/sec"
        echo "   Text Generation: ${TG_TPS} tokens/sec"
        echo ""

        RESULTS+=("{\"context_size\": $ctx_size, \"status\": \"success\", \"prompt_processing_tps\": $PP_TPS, \"text_generation_tps\": $TG_TPS}")
        SUCCESSFUL_TESTS=$((SUCCESSFUL_TESTS + 1))
    fi
done

echo "═══════════════════════════════════════════════════════"
echo "Context Size Testing Complete"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  Successful: $SUCCESSFUL_TESTS"
echo "  Failed: $FAILED_TESTS"
echo ""

# Find maximum successful context
MAX_CTX=0
for ctx_size in "${CTX_ARRAY[@]}"; do
    # Check if this context succeeded
    for result in "${RESULTS[@]}"; do
        if echo "$result" | grep -q "\"context_size\": $ctx_size" && echo "$result" | grep -q "\"status\": \"success\""; then
            if [ $ctx_size -gt $MAX_CTX ]; then
                MAX_CTX=$ctx_size
            fi
        fi
    done
done

if [ $MAX_CTX -gt 0 ]; then
    echo "Maximum successful context: $MAX_CTX tokens"
else
    echo "No successful tests"
fi
echo ""

# Output JSON
cat <<EOF
{
  "benchmark": "llama-context-test",
  "timestamp": "$(date -Iseconds)",
  "cpu": "$CPU_MODEL",
  "cores": $CPU_CORES,
  "memory_gb": $MEM_TOTAL,
  "backend": "$BACKEND",
  "model": "$(basename "$MODEL_PATH")",
  "config": {
    "prompt_size": $PROMPT_SIZE,
    "generation_size": $GEN_SIZE,
    "batch_size": $BATCH_SIZE,
    "threads": $THREADS,
    "flash_attention": true,
    "no_mmap": true,
    "gpu_layers": 999,
    "use_fit": $USE_FIT
  },
  "results": [
$(IFS=,; echo "${RESULTS[*]}")
  ],
  "summary": {
    "successful_tests": $SUCCESSFUL_TESTS,
    "failed_tests": $FAILED_TESTS,
    "max_context": $MAX_CTX
  }
}
EOF
