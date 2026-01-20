#!/bin/bash
# LLaMA Inference Benchmark Script
# Requires model file to be mounted at /models/

MODEL_PATH="${MODEL_PATH:-/models/model.gguf}"
PROMPT_SIZE="${PROMPT_SIZE:-512}"
GEN_SIZE="${GEN_SIZE:-128}"
BATCH_SIZE="${BATCH_SIZE:-512}"
THREADS="${THREADS:-$(nproc)}"

echo "=== LLaMA Inference Benchmark ==="
echo "System: $(uname -m)"
echo "Date: $(date -Iseconds)"
echo "Model: $MODEL_PATH"
echo "Threads: $THREADS"
echo ""

# Check if model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model file not found at $MODEL_PATH"
    echo "Please mount a model file with: -v /path/to/model.gguf:/models/model.gguf"
    exit 1
fi

# Get CPU info
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)

echo "CPU: $CPU_MODEL"
echo "Cores: $CPU_CORES"
echo ""
echo "Running llama-bench..."

# Run llama-bench
cd /opt/llama.cpp
OUTPUT=$(./build/bin/llama-bench \
    -m "$MODEL_PATH" \
    -p "$PROMPT_SIZE" \
    -n "$GEN_SIZE" \
    -b "$BATCH_SIZE" \
    -t "$THREADS" \
    2>&1)

echo "$OUTPUT"

# Parse results (llama-bench outputs in CSV-like format)
# Extract tokens/second for prompt processing (pp) and text generation (tg)
PP_TPS=$(echo "$OUTPUT" | grep "pp" | awk '{print $NF}' | head -1)
TG_TPS=$(echo "$OUTPUT" | grep "tg" | awk '{print $NF}' | head -1)

echo ""
echo "Results:"
echo "--------"
echo "Prompt Processing: $PP_TPS tokens/sec"
echo "Text Generation: $TG_TPS tokens/sec"
echo ""

# Output JSON
cat <<EOF
{
  "benchmark": "llama-inference",
  "timestamp": "$(date -Iseconds)",
  "cpu": "$CPU_MODEL",
  "cores": $CPU_CORES,
  "model": "$MODEL_PATH",
  "config": {
    "prompt_size": $PROMPT_SIZE,
    "generation_size": $GEN_SIZE,
    "batch_size": $BATCH_SIZE,
    "threads": $THREADS
  },
  "results": {
    "prompt_processing_tps": $PP_TPS,
    "text_generation_tps": $TG_TPS
  }
}
EOF
