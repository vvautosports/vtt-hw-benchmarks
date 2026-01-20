#!/bin/sh
# 7-Zip CPU Benchmark Script
# Outputs JSON-formatted results

echo "=== 7-Zip CPU Benchmark ==="
echo "System: $(uname -m)"
echo "Date: $(date -Iseconds)"
echo ""

# Run 7-Zip benchmark (dictionary size 32MB, multi-threaded)
echo "Running 7-Zip benchmark..."
OUTPUT=$(7z b -mmt=$(nproc) 2>&1)

# Extract results
COMP_RATING=$(echo "$OUTPUT" | grep "Avr:" | awk '{print $4}')
DECOMP_RATING=$(echo "$OUTPUT" | grep "Avr:" | awk '{print $7}')
OVERALL_RATING=$(echo "$OUTPUT" | grep "Avr:" | awk '{print $10}')

# Get CPU info
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)

# Output results
echo ""
echo "Results:"
echo "--------"
echo "CPU: $CPU_MODEL"
echo "Cores: $CPU_CORES"
echo "Compression Rating: $COMP_RATING MIPS"
echo "Decompression Rating: $DECOMP_RATING MIPS"
echo "Overall Rating: $OVERALL_RATING MIPS"
echo ""

# Output JSON for automated parsing
cat <<EOF
{
  "benchmark": "7zip",
  "timestamp": "$(date -Iseconds)",
  "cpu": "$CPU_MODEL",
  "cores": $CPU_CORES,
  "results": {
    "compression_mips": $COMP_RATING,
    "decompression_mips": $DECOMP_RATING,
    "overall_mips": $OVERALL_RATING
  }
}
EOF
