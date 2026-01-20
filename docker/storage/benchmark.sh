#!/bin/bash
# Storage I/O Benchmark Script using fio

echo "=== Storage I/O Benchmark (fio) ==="
echo "System: $(uname -m)"
echo "Date: $(date -Iseconds)"
echo ""

# Get CPU and storage info
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)

echo "CPU: $CPU_MODEL"
echo "Cores: $CPU_CORES"
echo ""
echo "Running fio benchmark..."
echo "This will take approximately 2.5 minutes (5 tests × 30 seconds each)"
echo ""

# Run fio with terse output for easier parsing
echo "[1/5] Sequential Read (1MB blocks)..."
SEQ_READ_OUTPUT=$(fio --name=seq-read --filename=/benchdata/testfile --rw=read --bs=1M --direct=1 --size=1G --runtime=30 --time_based=1 --output-format=json 2>/dev/null)
SEQ_READ_BW=$(echo "$SEQ_READ_OUTPUT" | grep -o '"bw"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')
SEQ_READ_MBPS=$(echo "scale=2; $SEQ_READ_BW / 1024" | bc)
echo "    ✓ ${SEQ_READ_MBPS} MB/s"

echo "[2/5] Sequential Write (1MB blocks)..."
SEQ_WRITE_OUTPUT=$(fio --name=seq-write --filename=/benchdata/testfile --rw=write --bs=1M --direct=1 --size=1G --runtime=30 --time_based=1 --output-format=json 2>/dev/null)
SEQ_WRITE_BW=$(echo "$SEQ_WRITE_OUTPUT" | grep -o '"bw"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')
SEQ_WRITE_MBPS=$(echo "scale=2; $SEQ_WRITE_BW / 1024" | bc)
echo "    ✓ ${SEQ_WRITE_MBPS} MB/s"

echo "[3/5] Random Read 4K (IOPS)..."
RAND_READ_OUTPUT=$(fio --name=rand-read --filename=/benchdata/testfile --rw=randread --bs=4k --direct=1 --size=1G --iodepth=32 --runtime=30 --time_based=1 --output-format=json 2>/dev/null)
RAND_READ_IOPS=$(echo "$RAND_READ_OUTPUT" | grep -o '"iops"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$' | cut -d'.' -f1)
echo "    ✓ ${RAND_READ_IOPS} IOPS"

echo "[4/5] Random Write 4K (IOPS)..."
RAND_WRITE_OUTPUT=$(fio --name=rand-write --filename=/benchdata/testfile --rw=randwrite --bs=4k --direct=1 --size=1G --iodepth=32 --runtime=30 --time_based=1 --output-format=json 2>/dev/null)
RAND_WRITE_IOPS=$(echo "$RAND_WRITE_OUTPUT" | grep -o '"iops"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$' | cut -d'.' -f1)
echo "    ✓ ${RAND_WRITE_IOPS} IOPS"

echo "[5/5] Mixed 70/30 Read/Write 4K (IOPS)..."
MIXED_OUTPUT=$(fio --name=mixed-rw --filename=/benchdata/testfile --rw=randrw --rwmixread=70 --bs=4k --direct=1 --size=1G --iodepth=32 --runtime=30 --time_based=1 --output-format=json 2>/dev/null)
MIXED_IOPS=$(echo "$MIXED_OUTPUT" | grep -o '"iops"[[:space:]]*:[[:space:]]*[0-9.]*' | head -1 | grep -o '[0-9.]*$' | cut -d'.' -f1)
echo "    ✓ ${MIXED_IOPS} IOPS"

echo ""

# Detect storage type (best effort)
STORAGE_TYPE="Unknown"
if [ -e /sys/block/sda/queue/rotational ]; then
    ROTATIONAL=$(cat /sys/block/sda/queue/rotational 2>/dev/null || echo "1")
    if [ "$ROTATIONAL" = "0" ]; then
        STORAGE_TYPE="SSD"
    else
        STORAGE_TYPE="HDD"
    fi
fi

# Check for NVMe
if ls /dev/nvme* >/dev/null 2>&1; then
    STORAGE_TYPE="NVMe SSD"
fi

echo "Results Summary:"
echo "────────────────────────────────────────"
printf "%-25s %s\n" "Sequential Read:" "${SEQ_READ_MBPS} MB/s"
printf "%-25s %s\n" "Sequential Write:" "${SEQ_WRITE_MBPS} MB/s"
printf "%-25s %s\n" "Random Read 4K:" "${RAND_READ_IOPS} IOPS"
printf "%-25s %s\n" "Random Write 4K:" "${RAND_WRITE_IOPS} IOPS"
printf "%-25s %s\n" "Mixed 70/30 R/W:" "${MIXED_IOPS} IOPS"
echo "────────────────────────────────────────"
echo ""

# Output JSON
cat <<EOF
{
  "benchmark": "storage",
  "timestamp": "$(date -Iseconds)",
  "cpu": "$CPU_MODEL",
  "cores": $CPU_CORES,
  "storage_type": "$STORAGE_TYPE",
  "results": {
    "sequential_read_mbps": ${SEQ_READ_MBPS:-0},
    "sequential_write_mbps": ${SEQ_WRITE_MBPS:-0},
    "random_read_4k_iops": ${RAND_READ_IOPS:-0},
    "random_write_4k_iops": ${RAND_WRITE_IOPS:-0},
    "mixed_rw_70_30_iops": ${MIXED_IOPS:-0}
  }
}
EOF

# Cleanup
rm -f /benchdata/testfile
