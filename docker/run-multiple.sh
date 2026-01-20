#!/bin/bash
# Run benchmarks multiple times for statistical analysis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$SCRIPT_DIR/../results}"
RUNS="${BENCHMARK_RUNS:-3}"
COOLDOWN="${COOLDOWN_SECONDS:-10}"
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

OUTPUT_FILE="$RESULTS_DIR/multi-run-${HOSTNAME}-${TIMESTAMP}.json"
LOG_FILE="$RESULTS_DIR/multi-run-${HOSTNAME}-${TIMESTAMP}.log"

echo "=== VTT Hardware Benchmark Suite (Multi-Run) ===" | tee "$LOG_FILE"
echo "Host: $HOSTNAME" | tee -a "$LOG_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$LOG_FILE"
echo "Runs: $RUNS" | tee -a "$LOG_FILE"
echo "Cooldown: ${COOLDOWN}s between runs" | tee -a "$LOG_FILE"
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

# Initialize arrays for results
declare -a RESULTS_7ZIP_COMP=()
declare -a RESULTS_7ZIP_DECOMP=()
declare -a RESULTS_7ZIP_OVERALL=()
declare -a RESULTS_STREAM_COPY=()
declare -a RESULTS_STREAM_SCALE=()
declare -a RESULTS_STREAM_ADD=()
declare -a RESULTS_STREAM_TRIAD=()
declare -a RESULTS_STORAGE_SEQ_READ=()
declare -a RESULTS_STORAGE_RAND_READ=()
declare -a RESULTS_STORAGE_MIXED=()

# Function to extract JSON field
extract_field() {
    local json="$1"
    local field="$2"
    echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*[0-9.]*" | grep -o '[0-9.]*$'
}

# Run benchmarks multiple times
for ((run=1; run<=RUNS; run++)); do
    echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "Run $run of $RUNS" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # 7-Zip
    echo "[Run $run/$RUNS] Running 7-Zip benchmark..." | tee -a "$LOG_FILE"
    RESULT_7ZIP=$($RUNTIME run --rm vtt-benchmark-7zip 2>&1)
    JSON_7ZIP=$(echo "$RESULT_7ZIP" | tail -n 1)

    COMP=$(extract_field "$JSON_7ZIP" "compression_mips")
    DECOMP=$(extract_field "$JSON_7ZIP" "decompression_mips")
    OVERALL=$(extract_field "$JSON_7ZIP" "overall_mips")

    RESULTS_7ZIP_COMP+=("$COMP")
    RESULTS_7ZIP_DECOMP+=("$DECOMP")
    RESULTS_7ZIP_OVERALL+=("$OVERALL")

    echo "  ✓ 7-Zip: Comp=${COMP} MIPS, Decomp=${DECOMP} MIPS, Overall=${OVERALL} MIPS" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Cooldown
    if [ $run -lt $RUNS ]; then
        echo "Cooldown: ${COOLDOWN}s..." | tee -a "$LOG_FILE"
        sleep $COOLDOWN
        echo "" | tee -a "$LOG_FILE"
    fi

    # STREAM
    echo "[Run $run/$RUNS] Running STREAM benchmark..." | tee -a "$LOG_FILE"
    RESULT_STREAM=$($RUNTIME run --rm vtt-benchmark-stream 2>&1)
    JSON_STREAM=$(echo "$RESULT_STREAM" | tail -n 1)

    COPY=$(extract_field "$JSON_STREAM" "copy_mbps")
    SCALE=$(extract_field "$JSON_STREAM" "scale_mbps")
    ADD=$(extract_field "$JSON_STREAM" "add_mbps")
    TRIAD=$(extract_field "$JSON_STREAM" "triad_mbps")

    RESULTS_STREAM_COPY+=("$COPY")
    RESULTS_STREAM_SCALE+=("$SCALE")
    RESULTS_STREAM_ADD+=("$ADD")
    RESULTS_STREAM_TRIAD+=("$TRIAD")

    echo "  ✓ STREAM: Copy=${COPY} MB/s, Scale=${SCALE} MB/s, Add=${ADD} MB/s, Triad=${TRIAD} MB/s" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Cooldown
    if [ $run -lt $RUNS ]; then
        echo "Cooldown: ${COOLDOWN}s..." | tee -a "$LOG_FILE"
        sleep $COOLDOWN
        echo "" | tee -a "$LOG_FILE"
    fi

    # Storage
    echo "[Run $run/$RUNS] Running Storage benchmark..." | tee -a "$LOG_FILE"
    RESULT_STORAGE=$($RUNTIME run --rm vtt-benchmark-storage 2>&1)
    JSON_STORAGE=$(echo "$RESULT_STORAGE" | tail -n 1)

    SEQ_READ=$(extract_field "$JSON_STORAGE" "sequential_read_mbps")
    RAND_READ=$(extract_field "$JSON_STORAGE" "random_read_4k_iops")
    MIXED=$(extract_field "$JSON_STORAGE" "mixed_rw_70_30_iops")

    RESULTS_STORAGE_SEQ_READ+=("$SEQ_READ")
    RESULTS_STORAGE_RAND_READ+=("$RAND_READ")
    RESULTS_STORAGE_MIXED+=("$MIXED")

    echo "  ✓ Storage: SeqRead=${SEQ_READ} MB/s, RandRead=${RAND_READ} IOPS, Mixed=${MIXED} IOPS" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Cooldown before next run
    if [ $run -lt $RUNS ]; then
        echo "Cooldown before next run: ${COOLDOWN}s..." | tee -a "$LOG_FILE"
        sleep $COOLDOWN
        echo "" | tee -a "$LOG_FILE"
    fi
done

echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "All runs complete. Calculating statistics..." | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Function to calculate statistics
calc_stats() {
    local values=("$@")
    local count=${#values[@]}

    # Sort array
    IFS=$'\n' sorted=($(sort -n <<<"${values[*]}"))
    unset IFS

    # Min/Max
    local min="${sorted[0]}"
    local max="${sorted[$((count-1))]}"

    # Mean
    local sum=0
    for v in "${values[@]}"; do
        sum=$(echo "$sum + $v" | bc)
    done
    local mean=$(echo "scale=2; $sum / $count" | bc)

    # Median
    local median_idx=$((count / 2))
    if [ $((count % 2)) -eq 0 ]; then
        local m1="${sorted[$((median_idx-1))]}"
        local m2="${sorted[$median_idx]}"
        local median=$(echo "scale=2; ($m1 + $m2) / 2" | bc)
    else
        local median="${sorted[$median_idx]}"
    fi

    # Stddev
    local variance=0
    for v in "${values[@]}"; do
        local diff=$(echo "$v - $mean" | bc)
        local sq=$(echo "$diff * $diff" | bc)
        variance=$(echo "$variance + $sq" | bc)
    done
    variance=$(echo "scale=2; $variance / $count" | bc)
    local stddev=$(echo "scale=2; sqrt($variance)" | bc)

    # Coefficient of variation
    local cv=$(echo "scale=4; ($stddev / $mean) * 100" | bc)

    echo "$mean,$median,$stddev,$min,$max,$cv"
}

# Calculate stats for each metric
echo "Calculating statistics..." | tee -a "$LOG_FILE"

STATS_7ZIP_OVERALL=$(calc_stats "${RESULTS_7ZIP_OVERALL[@]}")
STATS_STREAM_TRIAD=$(calc_stats "${RESULTS_STREAM_TRIAD[@]}")
STATS_STORAGE_SEQ_READ=$(calc_stats "${RESULTS_STORAGE_SEQ_READ[@]}")

# Output JSON with statistics
cat > "$OUTPUT_FILE" <<EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": "$(date -Iseconds)",
  "runs": $RUNS,
  "system": {
    "cpu": "$CPU_MODEL",
    "cores": $CPU_CORES,
    "memory_gb": $MEM_TOTAL
  },
  "benchmarks": {
    "7zip": {
      "overall_mips": {
        "mean": $(echo $STATS_7ZIP_OVERALL | cut -d',' -f1),
        "median": $(echo $STATS_7ZIP_OVERALL | cut -d',' -f2),
        "stddev": $(echo $STATS_7ZIP_OVERALL | cut -d',' -f3),
        "min": $(echo $STATS_7ZIP_OVERALL | cut -d',' -f4),
        "max": $(echo $STATS_7ZIP_OVERALL | cut -d',' -f5),
        "cv_percent": $(echo $STATS_7ZIP_OVERALL | cut -d',' -f6),
        "raw_runs": [$(IFS=,; echo "${RESULTS_7ZIP_OVERALL[*]}")]
      }
    },
    "stream": {
      "triad_mbps": {
        "mean": $(echo $STATS_STREAM_TRIAD | cut -d',' -f1),
        "median": $(echo $STATS_STREAM_TRIAD | cut -d',' -f2),
        "stddev": $(echo $STATS_STREAM_TRIAD | cut -d',' -f3),
        "min": $(echo $STATS_STREAM_TRIAD | cut -d',' -f4),
        "max": $(echo $STATS_STREAM_TRIAD | cut -d',' -f5),
        "cv_percent": $(echo $STATS_STREAM_TRIAD | cut -d',' -f6),
        "raw_runs": [$(IFS=,; echo "${RESULTS_STREAM_TRIAD[*]}")]
      }
    },
    "storage": {
      "sequential_read_mbps": {
        "mean": $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f1),
        "median": $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f2),
        "stddev": $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f3),
        "min": $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f4),
        "max": $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f5),
        "cv_percent": $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f6),
        "raw_runs": [$(IFS=,; echo "${RESULTS_STORAGE_SEQ_READ[*]}")]
      }
    }
  }
}
EOF

echo "" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "Statistical Summary" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Pretty print summary
printf "%-30s %10s %10s %10s %10s %10s\n" "Benchmark" "Mean" "Median" "StdDev" "Min" "Max" | tee -a "$LOG_FILE"
echo "────────────────────────────────────────────────────────────────────────────" | tee -a "$LOG_FILE"

printf "%-30s %10.2f %10.2f %10.2f %10.2f %10.2f\n" \
    "7-Zip Overall (MIPS)" \
    $(echo $STATS_7ZIP_OVERALL | cut -d',' -f1) \
    $(echo $STATS_7ZIP_OVERALL | cut -d',' -f2) \
    $(echo $STATS_7ZIP_OVERALL | cut -d',' -f3) \
    $(echo $STATS_7ZIP_OVERALL | cut -d',' -f4) \
    $(echo $STATS_7ZIP_OVERALL | cut -d',' -f5) | tee -a "$LOG_FILE"

printf "%-30s %10.2f %10.2f %10.2f %10.2f %10.2f\n" \
    "STREAM Triad (MB/s)" \
    $(echo $STATS_STREAM_TRIAD | cut -d',' -f1) \
    $(echo $STATS_STREAM_TRIAD | cut -d',' -f2) \
    $(echo $STATS_STREAM_TRIAD | cut -d',' -f3) \
    $(echo $STATS_STREAM_TRIAD | cut -d',' -f4) \
    $(echo $STATS_STREAM_TRIAD | cut -d',' -f5) | tee -a "$LOG_FILE"

printf "%-30s %10.2f %10.2f %10.2f %10.2f %10.2f\n" \
    "Storage Seq Read (MB/s)" \
    $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f1) \
    $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f2) \
    $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f3) \
    $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f4) \
    $(echo $STATS_STORAGE_SEQ_READ | cut -d',' -f5) | tee -a "$LOG_FILE"

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
