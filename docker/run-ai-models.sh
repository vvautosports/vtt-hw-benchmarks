#!/bin/bash
# Run AI inference benchmarks across multiple models
# Implements Issue #4: Multiple AI Model Testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/../results}"
MODEL_DIR="${MODEL_DIR:-/mnt/ai-models}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)

# Detect container runtime
if command -v docker &> /dev/null; then
    RUNTIME="docker"
elif command -v podman &> /dev/null; then
    RUNTIME="podman"
else
    echo "ERROR: Neither docker nor podman is installed"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

OUTPUT_FILE="$RESULTS_DIR/ai-models-${HOSTNAME}-${TIMESTAMP}.json"
LOG_FILE="$RESULTS_DIR/ai-models-${HOSTNAME}-${TIMESTAMP}.log"

echo "=== VTT AI Model Benchmark Suite ===" | tee "$LOG_FILE"
echo "Host: $HOSTNAME" | tee -a "$LOG_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$LOG_FILE"
echo "Model Directory: $MODEL_DIR" | tee -a "$LOG_FILE"
echo "Results: $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Get system info
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f", $2/1024/1024}')

echo "System Information:" | tee -a "$LOG_FILE"
echo "  CPU: $CPU_MODEL" | tee -a "$LOG_FILE"
echo "  Cores: $CPU_CORES" | tee -a "$LOG_FILE"
echo "  Memory: ${MEM_TOTAL} GB" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Discover models
echo "Discovering GGUF models..." | tee -a "$LOG_FILE"
mapfile -t MODEL_FILES < <(find "$MODEL_DIR" -name "*.gguf" -type f 2>/dev/null | grep -v "\.Trash" | sort)

if [ ${#MODEL_FILES[@]} -eq 0 ]; then
    echo "ERROR: No GGUF models found in $MODEL_DIR" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Found ${#MODEL_FILES[@]} model file(s):" | tee -a "$LOG_FILE"
for model in "${MODEL_FILES[@]}"; do
    size=$(du -h "$model" | cut -f1)
    echo "  - $(basename "$model") ($size)" | tee -a "$LOG_FILE"
done
echo "" | tee -a "$LOG_FILE"

# Group multi-part models
declare -A MODEL_GROUPS
for model in "${MODEL_FILES[@]}"; do
    basename=$(basename "$model")
    # Remove part numbers like "-00001-of-00003"
    base_name=$(echo "$basename" | sed 's/-[0-9]\{5\}-of-[0-9]\{5\}\.gguf$/.gguf/')

    if [ -z "${MODEL_GROUPS[$base_name]}" ]; then
        MODEL_GROUPS[$base_name]="$model"
    else
        MODEL_GROUPS[$base_name]="${MODEL_GROUPS[$base_name]}|$model"
    fi
done

# Initialize results JSON
cat > "$OUTPUT_FILE" <<EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": "$(date -Iseconds)",
  "system": {
    "cpu": "$CPU_MODEL",
    "cores": $CPU_CORES,
    "memory_gb": $MEM_TOTAL
  },
  "models": [
EOF

FIRST_MODEL=true

# Test each model or model group
for base_name in "${!MODEL_GROUPS[@]}"; do
    model_files="${MODEL_GROUPS[$base_name]}"
    primary_model=$(echo "$model_files" | cut -d'|' -f1)

    # Count parts
    part_count=$(echo "$model_files" | tr '|' '\n' | wc -l)

    echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    if [ $part_count -gt 1 ]; then
        echo "Testing: $base_name ($part_count parts)" | tee -a "$LOG_FILE"
    else
        echo "Testing: $base_name" | tee -a "$LOG_FILE"
    fi
    echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Get model size
    total_size=0
    for part in $(echo "$model_files" | tr '|' '\n'); do
        size_bytes=$(stat -f%z "$part" 2>/dev/null || stat -c%s "$part" 2>/dev/null || echo 0)
        total_size=$((total_size + size_bytes))
    done
    size_gb=$(echo "scale=2; $total_size / 1024 / 1024 / 1024" | bc)

    echo "Model size: ${size_gb} GB" | tee -a "$LOG_FILE"

    # Mount all parts if multi-part, otherwise just the single file
    # Add :z for SELinux relabeling (shared access, read-only)
    MOUNT_ARGS=""
    if [ $part_count -gt 1 ]; then
        # Multi-part model - mount parent directory
        model_dir=$(dirname "$primary_model")
        MOUNT_ARGS="-v $model_dir:/models:ro,z"
        MODEL_PATH="/models/$(basename "$primary_model")"
    else
        # Single file model
        MOUNT_ARGS="-v $primary_model:/models/model.gguf:ro,z"
        MODEL_PATH="/models/model.gguf"
    fi

    # AMD iGPU device mounts for Strix Halo
    # Vulkan (RADV) requires: /dev/dri
    # ROCm requires: /dev/dri + /dev/kfd
    GPU_ARGS="--device /dev/dri --device /dev/kfd --group-add video --group-add render --security-opt seccomp=unconfined"

    # Run benchmark
    echo "Running llama-bench with AMD iGPU acceleration..." | tee -a "$LOG_FILE"

    BENCH_OUTPUT=$($RUNTIME run --rm $MOUNT_ARGS $GPU_ARGS \
        -e MODEL_PATH="$MODEL_PATH" \
        vtt-benchmark-llama 2>&1 || true)

    echo "$BENCH_OUTPUT" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Parse results from JSON output (everything after the opening brace)
    JSON_OUTPUT=$(echo "$BENCH_OUTPUT" | sed -n '/{/,/}/p' | tail -n +1)

    # Extract metrics using grep -o to get the full field and value
    PP_TPS=$(echo "$JSON_OUTPUT" | grep '"prompt_processing_tps"' | grep -o '[0-9.]*' | grep -v '^$' | tail -1)
    TG_TPS=$(echo "$JSON_OUTPUT" | grep '"text_generation_tps"' | grep -o '[0-9.]*' | grep -v '^$' | tail -1)

    # Default to 0 if empty
    PP_TPS=${PP_TPS:-0}
    TG_TPS=${TG_TPS:-0}

    # Add comma if not first
    if [ "$FIRST_MODEL" = false ]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    FIRST_MODEL=false

    # Add result to JSON
    cat >> "$OUTPUT_FILE" <<EOF
    {
      "model_name": "$base_name",
      "parts": $part_count,
      "size_gb": $size_gb,
      "results": {
        "prompt_processing_tps": $PP_TPS,
        "text_generation_tps": $TG_TPS
      }
    }
EOF
done

# Close JSON
cat >> "$OUTPUT_FILE" <<EOF

  ]
}
EOF

echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "Benchmark Complete" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Summary table
echo "Results Summary:" | tee -a "$LOG_FILE"
echo "────────────────────────────────────────────────────────────────────────────" | tee -a "$LOG_FILE"
printf "%-50s %10s %15s %15s\n" "Model" "Size (GB)" "Prompt (t/s)" "Gen (t/s)" | tee -a "$LOG_FILE"
echo "────────────────────────────────────────────────────────────────────────────" | tee -a "$LOG_FILE"

for base_name in "${!MODEL_GROUPS[@]}"; do
    model_files="${MODEL_GROUPS[$base_name]}"

    # Calculate size
    total_size=0
    for part in $(echo "$model_files" | tr '|' '\n'); do
        size_bytes=$(stat -f%z "$part" 2>/dev/null || stat -c%s "$part" 2>/dev/null || echo 0)
        total_size=$((total_size + size_bytes))
    done
    size_gb=$(echo "scale=2; $total_size / 1024 / 1024 / 1024" | bc)

    # This is a simplified summary - real parsing would extract from JSON
    printf "%-50s %10s %15s %15s\n" \
        "$(echo "$base_name" | cut -c1-49)" \
        "$size_gb" \
        "See JSON" \
        "See JSON" | tee -a "$LOG_FILE"
done

echo "────────────────────────────────────────────────────────────────────────────" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Results saved to:" | tee -a "$LOG_FILE"
echo "  JSON: $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "  Log:  $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Pretty print JSON if jq available
if command -v jq &> /dev/null; then
    echo "Full JSON output:" | tee -a "$LOG_FILE"
    jq '.' "$OUTPUT_FILE" | tee -a "$LOG_FILE"
fi
