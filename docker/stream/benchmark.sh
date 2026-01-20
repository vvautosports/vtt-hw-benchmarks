#!/bin/bash
# STREAM Memory Bandwidth Benchmark Script

THREADS="${OMP_NUM_THREADS:-$(nproc)}"
export OMP_NUM_THREADS=$THREADS

echo "=== STREAM Memory Bandwidth Benchmark ==="
echo "System: $(uname -m)"
echo "Date: $(date -Iseconds)"
echo "Threads: $THREADS"
echo ""

# Get CPU and memory info
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f", $2/1024/1024}')

echo "CPU: $CPU_MODEL"
echo "Cores: $CPU_CORES"
echo "Memory: ${MEM_TOTAL} GB"
echo ""
echo "Running STREAM benchmark..."
echo "This will take about 30-60 seconds..."
echo ""

# Run STREAM
OUTPUT=$(/opt/stream 2>&1)
echo "$OUTPUT"

# Parse results (extract best rate for each test)
COPY=$(echo "$OUTPUT" | grep "Copy:" | awk '{print $2}')
SCALE=$(echo "$OUTPUT" | grep "Scale:" | awk '{print $2}')
ADD=$(echo "$OUTPUT" | grep "Add:" | awk '{print $2}')
TRIAD=$(echo "$OUTPUT" | grep "Triad:" | awk '{print $2}')

echo ""
echo "Results Summary:"
echo "----------------"
echo "Copy:  $COPY MB/s"
echo "Scale: $SCALE MB/s"
echo "Add:   $ADD MB/s"
echo "Triad: $TRIAD MB/s"
echo ""

# Output JSON
cat <<EOF
{
  "benchmark": "stream",
  "timestamp": "$(date -Iseconds)",
  "cpu": "$CPU_MODEL",
  "cores": $CPU_CORES,
  "threads": $THREADS,
  "memory_gb": $MEM_TOTAL,
  "results": {
    "copy_mbps": $COPY,
    "scale_mbps": $SCALE,
    "add_mbps": $ADD,
    "triad_mbps": $TRIAD
  }
}
EOF
