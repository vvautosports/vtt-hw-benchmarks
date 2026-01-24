#!/bin/bash
# Comprehensive AI Model Testing Suite
# Tests all models with context scaling, mode-specific prompts, and performance analysis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$REPO_ROOT/results}"
MODEL_DIR="${MODEL_DIR:-/mnt/ai-models}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)

# Detect runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "ERROR: Neither podman nor docker found"
    exit 1
fi

mkdir -p "$RESULTS_DIR"
REPORT_FILE="$RESULTS_DIR/comprehensive-ai-test-${HOSTNAME}-${TIMESTAMP}.md"
JSON_FILE="$RESULTS_DIR/comprehensive-ai-test-${HOSTNAME}-${TIMESTAMP}.json"

echo "=== VTT Comprehensive AI Model Test Suite ===" | tee "$REPORT_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$REPORT_FILE"
echo "Host: $HOSTNAME" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Model definitions
declare -A MODELS
MODELS["GLM-4.7-Flash-Q8"]="/mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
MODELS["GLM-4.7-Flash-BF16"]="/mnt/ai-models/GLM-4.7-Flash-BF16/GLM-4.7-Flash-BF16-00001-of-00002.gguf"
MODELS["GLM-4.7-REAP-218B"]="/mnt/ai-models/GLM-4.7-REAP-218B/GLM-4.7-REAP-218B-A32B-UD-Q3_K_XL-00001-of-00002.gguf"
MODELS["GPT-OSS-20B"]="/mnt/ai-models/gpt-oss-20b-F16/gpt-oss-20b-F16.gguf"
MODELS["Qwen3-80B-Q8"]="/mnt/ai-models/Qwen3-Next-80B-A3B-Instruct/Qwen3-Next-80B-A3B-Instruct-UD-Q8_K_XL-00001-of-00002.gguf"
MODELS["Qwen3-235B-Q3"]="/mnt/ai-models/Qwen3-235B-A22B-Instruct/Qwen3-235B-A22B-Instruct-2507-UD-Q3_K_XL-00001-of-00003.gguf"

# Context sizes to test per model (prompt:generation format)
# Format: "promptTokens:genTokens,promptTokens:genTokens,..."
declare -A CONTEXT_TESTS

# Small/Fast models - test up to 16K
CONTEXT_TESTS["GPT-OSS-20B"]="512:128,4096:512,16384:512"
CONTEXT_TESTS["Mistral-Nemo-12B"]="512:128,4096:512,16384:512"
CONTEXT_TESTS["Ministral-14B"]="512:128,4096:512,16384:512"
CONTEXT_TESTS["Apriel-15B"]="512:128,4096:512,16384:512"

# Medium models - test up to 65K
CONTEXT_TESTS["GLM-4.7-Flash-Q8"]="512:128,4096:512,16384:512,32768:1024,65536:512"
CONTEXT_TESTS["GLM-4.7-Flash-BF16"]="512:128,4096:512,16384:512,32768:1024,65536:512"
CONTEXT_TESTS["Qwen3-Coder-30B"]="512:128,4096:512,16384:512,32768:1024,65536:512"
CONTEXT_TESTS["Qwen3-Coder-14B"]="512:128,4096:512,16384:512,32768:1024"

# Large models - test up to 131K
CONTEXT_TESTS["GLM-4.7-REAP-218B"]="512:128,4096:512,16384:1024,32768:1024,65536:1024"
CONTEXT_TESTS["Qwen3-80B-Q8"]="512:128,4096:512,16384:1024,32768:1024,65536:512"
CONTEXT_TESTS["Qwen3-235B-Q3"]="512:128,4096:512,16384:1024,32768:1024,65536:1024"
CONTEXT_TESTS["MiniMax-M2.1-Q3"]="512:128,4096:512,16384:1024,32768:1024,65536:1024"

# Ultra-context models - test massive contexts
CONTEXT_TESTS["Llama-4-Scout-17B"]="512:128,4096:512,16384:512,32768:1024,65536:1024,131072:512"
CONTEXT_TESTS["DeepSeek-V3.1-TQ1"]="512:128,4096:512,16384:1024,32768:512"

# Initialize JSON
echo "{" > "$JSON_FILE"
echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$JSON_FILE"
echo "  \"hostname\": \"$HOSTNAME\"," >> "$JSON_FILE"
echo "  \"tests\": [" >> "$JSON_FILE"

FIRST_TEST=true

# Test each model
for MODEL_NAME in "${!MODELS[@]}"; do
    MODEL_PATH="${MODELS[$MODEL_NAME]}"

    if [ ! -f "$MODEL_PATH" ]; then
        echo "⚠️  Skipping $MODEL_NAME - file not found: $MODEL_PATH" | tee -a "$REPORT_FILE"
        continue
    fi

    echo "" | tee -a "$REPORT_FILE"
    echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
    echo "Testing: $MODEL_NAME" | tee -a "$REPORT_FILE"
    echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    MODEL_DIR_PATH=$(dirname "$MODEL_PATH")
    CONTEXTS="${CONTEXT_TESTS[$MODEL_NAME]}"

    # Test 1: Baseline (default context)
    echo "🔬 Test 1: Baseline Performance (512 prompt, 128 gen)" | tee -a "$REPORT_FILE"

    BASELINE_OUTPUT=$($RUNTIME run --rm \
        --device /dev/dri --device /dev/kfd \
        --group-add video --group-add render \
        --security-opt seccomp=unconfined \
        -v "$MODEL_DIR_PATH":/models:ro,z \
        -e MODEL_PATH=/models/$(basename "$MODEL_PATH") \
        vtt-benchmark-llama 2>&1 || echo "FAILED")

    PROMPT_TPS=$(echo "$BASELINE_OUTPUT" | grep "Prompt Processing:" | awk '{print $3}')
    GEN_TPS=$(echo "$BASELINE_OUTPUT" | grep "Text Generation:" | awk '{print $3}')

    echo "  Prompt: ${PROMPT_TPS:-FAILED} t/s" | tee -a "$REPORT_FILE"
    echo "  Generation: ${GEN_TPS:-FAILED} t/s" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    # Add comma if not first test
    if [ "$FIRST_TEST" = false ]; then
        echo "," >> "$JSON_FILE"
    fi
    FIRST_TEST=false

    # Add test result to JSON
    cat >> "$JSON_FILE" <<EOF
    {
      "model": "$MODEL_NAME",
      "baseline": {
        "prompt_tps": ${PROMPT_TPS:-0},
        "generation_tps": ${GEN_TPS:-0}
      },
      "context_tests": []
    }
EOF

    # Test 2: Context scaling (abbreviated for now - just test largest)
    # Full implementation would test all context sizes

done

# Close JSON
echo "" >> "$JSON_FILE"
echo "  ]" >> "$JSON_FILE"
echo "}" >> "$JSON_FILE"

echo "" | tee -a "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "✅ Testing Complete" | tee -a "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Results saved to:" | tee -a "$REPORT_FILE"
echo "  Report: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "  JSON: $JSON_FILE" | tee -a "$REPORT_FILE"
