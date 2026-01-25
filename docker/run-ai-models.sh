#!/bin/bash
# Run AI inference benchmarks across multiple models
# Implements Issue #4: Multiple AI Model Testing
# Supports configurable model selection via models-inventory.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/../results}"
MODEL_DIR="${MODEL_DIR:-/mnt/ai-models}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../models-inventory.yaml}"
MODEL_CONFIG_MODE="${MODEL_CONFIG_MODE:-}"  # default, all, or empty (auto)
QUICK_TEST="${QUICK_TEST:-false}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick-test)
            QUICK_TEST=true
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --mode)
            MODEL_CONFIG_MODE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--quick-test] [--config FILE] [--mode default|all]"
            exit 1
            ;;
    esac
done

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

# Determine model selection method
if [ -n "$MODEL_CONFIG_MODE" ] && [ -f "$CONFIG_FILE" ]; then
    echo "Using configuration file: $CONFIG_FILE" | tee -a "$LOG_FILE"
    echo "Mode: $MODEL_CONFIG_MODE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Source config parser
    source "$SCRIPT_DIR/../scripts/utils/config-parser.sh"

    if [ "$MODEL_CONFIG_MODE" = "light" ]; then
        echo "Loading light models from configuration (1-2 models, <16GB VRAM)..." | tee -a "$LOG_FILE"

        # Load model paths from config
        mapfile -t MODEL_PATHS < <(awk '
            /^light_models:/ { in_section = 1; next }
            /^[a-z_]+:/ && in_section { in_section = 0 }
            in_section && /path:/ {
                match($0, /path:[[:space:]]*["]?([^"]+)["]?/, arr)
                if (arr[1] != "") {
                    print arr[1]
                }
            }
        ' "$CONFIG_FILE")

    elif [ "$MODEL_CONFIG_MODE" = "default" ]; then
        echo "Loading default models from configuration..." | tee -a "$LOG_FILE"

        # Load model paths from config
        mapfile -t MODEL_PATHS < <(load_default_models "$CONFIG_FILE")

        if [ ${#MODEL_PATHS[@]} -eq 0 ]; then
            echo "ERROR: No default models found in configuration" | tee -a "$LOG_FILE"
            exit 1
        fi

        # Build full paths and discover multi-part models
        MODEL_FILES=()
        for path in "${MODEL_PATHS[@]}"; do
            full_path="$MODEL_DIR/$path"
            if [ -f "$full_path" ]; then
                MODEL_FILES+=("$full_path")
                
                # Check if this is a multi-part model (e.g., -00001-of-00002.gguf)
                if [[ "$full_path" =~ -[0-9]{5}-of-[0-9]{5}\.gguf$ ]]; then
                    # Extract the base pattern and total parts
                    model_dir=$(dirname "$full_path")
                    model_base=$(basename "$full_path" | sed 's/-[0-9]\{5\}-of-[0-9]\{5\}\.gguf$//')
                    total_parts=$(basename "$full_path" | grep -oP '(?<=-of-)[0-9]{5}' | sed 's/^0*//')
                    
                    # Add remaining parts
                    for ((i=2; i<=$total_parts; i++)); do
                        part_num=$(printf "%05d" $i)
                        total_num=$(printf "%05d" $total_parts)
                        part_file="$model_dir/${model_base}-${part_num}-of-${total_num}.gguf"
                        if [ -f "$part_file" ]; then
                            MODEL_FILES+=("$part_file")
                        else
                            echo "WARNING: Multi-part model part not found: $part_file" | tee -a "$LOG_FILE"
                        fi
                    done
                fi
            else
                echo "WARNING: Model not found: $full_path" | tee -a "$LOG_FILE"
            fi
        done

        if [ ${#MODEL_FILES[@]} -eq 0 ]; then
            echo "ERROR: None of the configured models were found in $MODEL_DIR" | tee -a "$LOG_FILE"
            exit 1
        fi

        echo "Loaded ${#MODEL_FILES[@]} default model(s)" | tee -a "$LOG_FILE"

    elif [ "$MODEL_CONFIG_MODE" = "all" ]; then
        echo "Auto-discovering all models..." | tee -a "$LOG_FILE"
        mapfile -t MODEL_FILES < <(find "$MODEL_DIR" -name "*.gguf" -type f 2>/dev/null | grep -v "\.Trash" | sort)

        if [ ${#MODEL_FILES[@]} -eq 0 ]; then
            echo "ERROR: No GGUF models found in $MODEL_DIR" | tee -a "$LOG_FILE"
            exit 1
        fi
    else
        echo "ERROR: Invalid MODEL_CONFIG_MODE: $MODEL_CONFIG_MODE (use 'light', 'default', or 'all')" | tee -a "$LOG_FILE"
        exit 1
    fi
else
    # Backward compatibility: auto-discover all models
    echo "Discovering GGUF models (backward compatibility mode)..." | tee -a "$LOG_FILE"
    mapfile -t MODEL_FILES < <(find "$MODEL_DIR" -name "*.gguf" -type f 2>/dev/null | grep -v "\.Trash" | sort)

    if [ ${#MODEL_FILES[@]} -eq 0 ]; then
        echo "ERROR: No GGUF models found in $MODEL_DIR" | tee -a "$LOG_FILE"
        exit 1
    fi
fi

echo "Found ${#MODEL_FILES[@]} model file(s):" | tee -a "$LOG_FILE"

# Quick test mode: only show first model
if [ "$QUICK_TEST" = true ]; then
    echo "QUICK TEST MODE: Testing first model only" | tee -a "$LOG_FILE"
    MODEL_FILES=("${MODEL_FILES[0]}")
fi

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
    # In nested VMs, GPU devices won't exist - handle gracefully
    GPU_ARGS=""
    if [ -d "/dev/dri" ]; then
        GPU_ARGS="--device /dev/dri --group-add video --group-add render"
        if [ -d "/dev/kfd" ]; then
            GPU_ARGS="$GPU_ARGS --device /dev/kfd"
        fi
        GPU_ARGS="$GPU_ARGS --security-opt seccomp=unconfined"
        echo "GPU devices detected - using GPU acceleration" | tee -a "$LOG_FILE"
    else
        echo "WARNING: No GPU devices found (/dev/dri not available)" | tee -a "$LOG_FILE"
        echo "Running in CPU-only mode (expected in nested VMs)" | tee -a "$LOG_FILE"
    fi

    # Verify container image exists
    if ! $RUNTIME image inspect vtt-benchmark-llama:latest &>/dev/null; then
        echo "ERROR: Container image 'vtt-benchmark-llama:latest' not found" | tee -a "$LOG_FILE"
        echo "Pull images with: ./scripts/ci-cd/pull-from-ghcr.sh" | tee -a "$LOG_FILE"
        exit 1
    fi

    # Run benchmark
    if [ -n "$GPU_ARGS" ]; then
        echo "Running llama-bench with AMD iGPU acceleration..." | tee -a "$LOG_FILE"
    else
        echo "Running llama-bench in CPU-only mode..." | tee -a "$LOG_FILE"
    fi

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
