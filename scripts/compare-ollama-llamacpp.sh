#!/bin/bash
# Compare Ollama vs llama.cpp performance on same model
# Tests inference speed, memory usage, and API overhead

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$REPO_ROOT/results}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)

MODEL_NAME="${1:-glm4.7}"  # Ollama model name
MODEL_PATH="${2:-/mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf}"

if [ -z "$1" ]; then
    echo "Usage: $0 <ollama-model-name> [path-to-gguf-file]"
    echo ""
    echo "Example:"
    echo "  $0 glm4.7 /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
    echo ""
    echo "Available Ollama models:"
    ollama list
    exit 1
fi

mkdir -p "$RESULTS_DIR"
REPORT_FILE="$RESULTS_DIR/ollama-vs-llamacpp-${MODEL_NAME}-${TIMESTAMP}.md"

echo "=== Ollama vs llama.cpp Performance Comparison ===" | tee "$REPORT_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$REPORT_FILE"
echo "Model: $MODEL_NAME" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Check if Ollama model exists
if ! ollama list | grep -q "$MODEL_NAME"; then
    echo "❌ Error: Ollama model '$MODEL_NAME' not found" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "Available models:" | tee -a "$REPORT_FILE"
    ollama list | tee -a "$REPORT_FILE"
    exit 1
fi

# Check if GGUF file exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Error: GGUF file not found: $MODEL_PATH" | tee -a "$REPORT_FILE"
    exit 1
fi

echo "✅ Ollama model: $MODEL_NAME" | tee -a "$REPORT_FILE"
echo "✅ llama.cpp GGUF: $MODEL_PATH" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test prompt (coding task)
TEST_PROMPT="Write a Python function to calculate fibonacci numbers recursively. Include docstring and type hints."

echo "Test Prompt:" | tee -a "$REPORT_FILE"
echo "  $TEST_PROMPT" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test 1: Ollama performance
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "Test 1: Ollama API" | tee -a "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Get memory before
MEM_BEFORE_OLLAMA=$(free -m | awk 'NR==2{print $3}')

OLLAMA_START=$(date +%s.%N)
OLLAMA_RESPONSE=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"$MODEL_NAME\",
  \"prompt\": \"$TEST_PROMPT\",
  \"stream\": false
}" 2>&1)
OLLAMA_END=$(date +%s.%N)
OLLAMA_DURATION=$(echo "$OLLAMA_END - $OLLAMA_START" | bc)

# Get memory after
MEM_AFTER_OLLAMA=$(free -m | awk 'NR==2{print $3}')
MEM_USED_OLLAMA=$((MEM_AFTER_OLLAMA - MEM_BEFORE_OLLAMA))

# Parse response (if successful)
if echo "$OLLAMA_RESPONSE" | jq -e . >/dev/null 2>&1; then
    OLLAMA_TOTAL_DURATION=$(echo "$OLLAMA_RESPONSE" | jq -r '.total_duration // 0' 2>/dev/null || echo 0)
    OLLAMA_LOAD_DURATION=$(echo "$OLLAMA_RESPONSE" | jq -r '.load_duration // 0' 2>/dev/null || echo 0)
    OLLAMA_PROMPT_EVAL=$(echo "$OLLAMA_RESPONSE" | jq -r '.prompt_eval_count // 0' 2>/dev/null || echo 0)
    OLLAMA_PROMPT_DURATION=$(echo "$OLLAMA_RESPONSE" | jq -r '.prompt_eval_duration // 0' 2>/dev/null || echo 0)
    OLLAMA_EVAL=$(echo "$OLLAMA_RESPONSE" | jq -r '.eval_count // 0' 2>/dev/null || echo 0)
    OLLAMA_EVAL_DURATION=$(echo "$OLLAMA_RESPONSE" | jq -r '.eval_duration // 0' 2>/dev/null || echo 0)

    # Calculate tokens/sec
    if [ "$OLLAMA_PROMPT_DURATION" -gt 0 ]; then
        OLLAMA_PROMPT_TPS=$(echo "scale=2; $OLLAMA_PROMPT_EVAL / ($OLLAMA_PROMPT_DURATION / 1000000000)" | bc)
    else
        OLLAMA_PROMPT_TPS=0
    fi

    if [ "$OLLAMA_EVAL_DURATION" -gt 0 ]; then
        OLLAMA_GEN_TPS=$(echo "scale=2; $OLLAMA_EVAL / ($OLLAMA_EVAL_DURATION / 1000000000)" | bc)
    else
        OLLAMA_GEN_TPS=0
    fi

    echo "Response Time: ${OLLAMA_DURATION} seconds" | tee -a "$REPORT_FILE"
    echo "Prompt Tokens: $OLLAMA_PROMPT_EVAL" | tee -a "$REPORT_FILE"
    echo "Prompt Speed: ${OLLAMA_PROMPT_TPS} t/s" | tee -a "$REPORT_FILE"
    echo "Generation Tokens: $OLLAMA_EVAL" | tee -a "$REPORT_FILE"
    echo "Generation Speed: ${OLLAMA_GEN_TPS} t/s" | tee -a "$REPORT_FILE"
    echo "Memory Used: ~${MEM_USED_OLLAMA} MB" | tee -a "$REPORT_FILE"
else
    echo "❌ Ollama request failed" | tee -a "$REPORT_FILE"
    echo "Response: $OLLAMA_RESPONSE" | tee -a "$REPORT_FILE"
    OLLAMA_PROMPT_TPS=0
    OLLAMA_GEN_TPS=0
fi

echo "" | tee -a "$REPORT_FILE"

# Test 2: llama.cpp performance
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "Test 2: llama.cpp Direct" | tee -a "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Detect runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "❌ No container runtime found" | tee -a "$REPORT_FILE"
    exit 1
fi

MEM_BEFORE_LLAMA=$(free -m | awk 'NR==2{print $3}')

LLAMA_START=$(date +%s.%N)

MODEL_DIR_PATH=$(dirname "$MODEL_PATH")
LLAMA_OUTPUT=$($RUNTIME run --rm \
    --device /dev/dri --device /dev/kfd \
    --group-add video --group-add render \
    --security-opt seccomp=unconfined \
    -v "$MODEL_DIR_PATH":/models:ro,z \
    -e MODEL_PATH=/models/$(basename "$MODEL_PATH") \
    vtt-benchmark-llama 2>&1)

LLAMA_END=$(date +%s.%N)
LLAMA_DURATION=$(echo "$LLAMA_END - $LLAMA_START" | bc)

MEM_AFTER_LLAMA=$(free -m | awk 'NR==2{print $3}')
MEM_USED_LLAMA=$((MEM_AFTER_LLAMA - MEM_BEFORE_LLAMA))

# Parse llama.cpp output
LLAMA_PROMPT_TPS=$(echo "$LLAMA_OUTPUT" | grep "Prompt Processing:" | awk '{print $3}')
LLAMA_GEN_TPS=$(echo "$LLAMA_OUTPUT" | grep "Text Generation:" | awk '{print $3}')

echo "Response Time: ${LLAMA_DURATION} seconds" | tee -a "$REPORT_FILE"
echo "Prompt Speed: ${LLAMA_PROMPT_TPS:-0} t/s" | tee -a "$REPORT_FILE"
echo "Generation Speed: ${LLAMA_GEN_TPS:-0} t/s" | tee -a "$REPORT_FILE"
echo "Memory Used: ~${MEM_USED_LLAMA} MB" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Comparison
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "Comparison" | tee -a "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Calculate differences
if [ "$OLLAMA_PROMPT_TPS" != "0" ] && [ "$LLAMA_PROMPT_TPS" != "0" ]; then
    PROMPT_DIFF=$(echo "scale=2; (($LLAMA_PROMPT_TPS - $OLLAMA_PROMPT_TPS) / $OLLAMA_PROMPT_TPS) * 100" | bc)
    echo "Prompt Processing: llama.cpp is ${PROMPT_DIFF}% faster" | tee -a "$REPORT_FILE"
fi

if [ "$OLLAMA_GEN_TPS" != "0" ] && [ "$LLAMA_GEN_TPS" != "0" ]; then
    GEN_DIFF=$(echo "scale=2; (($LLAMA_GEN_TPS - $OLLAMA_GEN_TPS) / $OLLAMA_GEN_TPS) * 100" | bc)
    echo "Text Generation: llama.cpp is ${GEN_DIFF}% faster" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "Summary Table:" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

printf "%-20s | %-15s | %-15s | %-15s\n" "Metric" "Ollama" "llama.cpp" "Difference" | tee -a "$REPORT_FILE"
echo "--------------------------------------------------------------------------------" | tee -a "$REPORT_FILE"
printf "%-20s | %-15s | %-15s | %-15s\n" "Prompt (t/s)" "$OLLAMA_PROMPT_TPS" "$LLAMA_PROMPT_TPS" "${PROMPT_DIFF}%" | tee -a "$REPORT_FILE"
printf "%-20s | %-15s | %-15s | %-15s\n" "Generation (t/s)" "$OLLAMA_GEN_TPS" "$LLAMA_GEN_TPS" "${GEN_DIFF}%" | tee -a "$REPORT_FILE"
printf "%-20s | %-15s | %-15s | %-15s\n" "Memory (MB)" "$MEM_USED_OLLAMA" "$MEM_USED_LLAMA" "N/A" | tee -a "$REPORT_FILE"

echo "" | tee -a "$REPORT_FILE"
echo "Results saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
