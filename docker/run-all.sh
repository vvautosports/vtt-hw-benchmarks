#!/bin/bash
# Run all benchmarks and collect results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/../results}"
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

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

# Output file
OUTPUT_FILE="$RESULTS_DIR/benchmark-${HOSTNAME}-${TIMESTAMP}.json"
LOG_FILE="$RESULTS_DIR/benchmark-${HOSTNAME}-${TIMESTAMP}.log"

echo "=== VTT Hardware Benchmark Suite ===" | tee "$LOG_FILE"
echo "Host: $HOSTNAME" | tee -a "$LOG_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$LOG_FILE"
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
  "benchmarks": {
EOF

# Track if we need comma separator
FIRST=true

# Function to add benchmark result
add_result() {
    local name=$1
    local result=$2

    if [ "$FIRST" = false ]; then
        echo "," >> "$OUTPUT_FILE"
    fi
    FIRST=false

    echo "    \"$name\": $result" >> "$OUTPUT_FILE"
}

# Run 7-Zip benchmark
echo "Running 7-Zip benchmark..." | tee -a "$LOG_FILE"
RESULT_7ZIP=$($RUNTIME run --rm vtt-benchmark-7zip 2>&1)
echo "$RESULT_7ZIP" | tee -a "$LOG_FILE"
JSON_7ZIP=$(echo "$RESULT_7ZIP" | tail -n 1)
add_result "7zip" "$JSON_7ZIP"
echo "" | tee -a "$LOG_FILE"

# Run STREAM benchmark
echo "Running STREAM benchmark..." | tee -a "$LOG_FILE"
RESULT_STREAM=$($RUNTIME run --rm vtt-benchmark-stream 2>&1)
echo "$RESULT_STREAM" | tee -a "$LOG_FILE"
JSON_STREAM=$(echo "$RESULT_STREAM" | tail -n 1)
add_result "stream" "$JSON_STREAM"
echo "" | tee -a "$LOG_FILE"

# Run LLaMA benchmark (if model provided)
if [ -n "$LLAMA_MODEL" ] && [ -f "$LLAMA_MODEL" ]; then
    echo "Running LLaMA benchmark with model: $LLAMA_MODEL" | tee -a "$LOG_FILE"
    RESULT_LLAMA=$($RUNTIME run --rm \
        -v "$LLAMA_MODEL:/models/model.gguf" \
        vtt-benchmark-llama 2>&1)
    echo "$RESULT_LLAMA" | tee -a "$LOG_FILE"
    JSON_LLAMA=$(echo "$RESULT_LLAMA" | tail -n 1)
    add_result "llama" "$JSON_LLAMA"
    echo "" | tee -a "$LOG_FILE"
else
    echo "Skipping LLaMA benchmark (no model specified)" | tee -a "$LOG_FILE"
    echo "Set LLAMA_MODEL=/path/to/model.gguf to include AI inference test" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
fi

# Close JSON
cat >> "$OUTPUT_FILE" <<EOF

  }
}
EOF

echo "=== Benchmark Suite Complete ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Results saved to:" | tee -a "$LOG_FILE"
echo "  JSON: $OUTPUT_FILE" | tee -a "$LOG_FILE"
echo "  Log:  $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Pretty print results summary
echo "Summary:" | tee -a "$LOG_FILE"
if command -v jq &> /dev/null; then
    jq '.benchmarks' "$OUTPUT_FILE" | tee -a "$LOG_FILE"
else
    cat "$OUTPUT_FILE" | tee -a "$LOG_FILE"
fi
