#!/bin/bash
# Build all benchmark containers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect container runtime
if command -v docker &> /dev/null; then
    RUNTIME="docker"
elif command -v podman &> /dev/null; then
    RUNTIME="podman"
else
    echo "ERROR: Neither docker nor podman is installed"
    exit 1
fi

echo "=== Building VTT Benchmark Containers ==="
echo "Using container runtime: $RUNTIME"
echo ""

# 7-Zip
echo "Building 7-Zip benchmark..."
cd "$SCRIPT_DIR/7zip"
$RUNTIME build -t vtt-benchmark-7zip .
echo "✓ 7-Zip benchmark built"
echo ""

# STREAM
echo "Building STREAM benchmark..."
cd "$SCRIPT_DIR/stream"
$RUNTIME build -t vtt-benchmark-stream .
echo "✓ STREAM benchmark built"
echo ""

# LLaMA
echo "Building LLaMA benchmark..."
cd "$SCRIPT_DIR/llama-bench"
$RUNTIME build -t vtt-benchmark-llama .
echo "✓ LLaMA benchmark built"
echo ""

echo "=== All benchmarks built successfully ==="
echo ""
echo "Available images:"
$RUNTIME images | grep vtt-benchmark
echo ""
echo "Run individual benchmarks:"
echo "  $RUNTIME run --rm vtt-benchmark-7zip"
echo "  $RUNTIME run --rm vtt-benchmark-stream"
echo "  $RUNTIME run --rm -v /path/to/model.gguf:/models/model.gguf vtt-benchmark-llama"
echo ""
echo "Or run all with: ./run-all.sh"
