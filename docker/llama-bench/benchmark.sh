#!/bin/bash
# LLaMA Inference Benchmark Script for AMD Strix Halo
# Uses llama-bench from llama.cpp toolbox

MODEL_PATH="${MODEL_PATH:-/models/model.gguf}"
PROMPT_SIZE="${PROMPT_SIZE:-512}"
GEN_SIZE="${GEN_SIZE:-128}"
BATCH_SIZE="${BATCH_SIZE:-512}"
THREADS="${THREADS:-$(nproc)}"

# Strix Halo CRITICAL flags (from toolbox documentation)
# -fa 1: Flash attention (REQUIRED for Strix Halo or it will crawl/crash)
# -mmp 0: Disable memory mapping (REQUIRED for Strix Halo stability)
# -ngl 999: Offload all layers to GPU
STRIX_FLAGS="-fa 1 -mmp 0 -ngl 999"

echo "=== LLaMA Inference Benchmark (AMD Strix Halo) ==="
echo "System: $(uname -m)"
echo "Date: $(date -Iseconds)"
echo "Model: $MODEL_PATH"
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

# List detected GPUs
echo "Detected GPUs:"
llama-cli --list-devices 2>&1 | grep -A 10 "Available devices:" || echo "GPU detection failed"
echo ""

echo "Running llama-bench with Strix Halo optimizations..."
echo "Flags: $STRIX_FLAGS"
echo "Prompt: ${PROMPT_SIZE} tokens, Generate: ${GEN_SIZE} tokens"
echo ""

# Run llama-bench
# llama-bench outputs CSV-like format
OUTPUT=$(llama-bench \
    -m "$MODEL_PATH" \
    -p "$PROMPT_SIZE" \
    -n "$GEN_SIZE" \
    -b "$BATCH_SIZE" \
    -t "$THREADS" \
    $STRIX_FLAGS \
    2>&1)

echo "$OUTPUT"
echo ""

# Parse results from llama-bench output
# llama-bench outputs a table with test types (pp512, tg128) and performance (tokens/sec ± stddev)
# Extract the value before the ± symbol from the second-to-last column (last column is empty after final |)
PP_TPS=$(echo "$OUTPUT" | grep "pp${PROMPT_SIZE}" | awk -F'|' '{print $(NF-1)}' | awk '{print $1}' | head -1)
TG_TPS=$(echo "$OUTPUT" | grep "tg${GEN_SIZE}" | awk -F'|' '{print $(NF-1)}' | awk '{print $1}' | head -1)

# Default to 0 if parsing failed
PP_TPS=${PP_TPS:-0}
TG_TPS=${TG_TPS:-0}

echo "Results:"
echo "--------"
echo "Prompt Processing: ${PP_TPS} tokens/sec"
echo "Text Generation: ${TG_TPS} tokens/sec"
echo ""

# Get backend info from environment or detect
BACKEND=${BACKEND:-"unknown"}
if llama-cli --version 2>&1 | grep -qi "vulkan"; then
    BACKEND="vulkan"
elif llama-cli --version 2>&1 | grep -qi "rocm\|hip"; then
    BACKEND="rocm"
fi

# Output JSON
cat <<EOF
{
  "benchmark": "llama-inference",
  "timestamp": "$(date -Iseconds)",
  "cpu": "$CPU_MODEL",
  "cores": $CPU_CORES,
  "backend": "$BACKEND",
  "model": "$(basename "$MODEL_PATH")",
  "config": {
    "prompt_size": $PROMPT_SIZE,
    "generation_size": $GEN_SIZE,
    "batch_size": $BATCH_SIZE,
    "threads": $THREADS,
    "flash_attention": true,
    "no_mmap": true,
    "gpu_layers": 999
  },
  "results": {
    "prompt_processing_tps": $PP_TPS,
    "text_generation_tps": $TG_TPS
  }
}
EOF
