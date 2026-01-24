#!/bin/bash
# Pre-test environment validation
# Checks system requirements before running benchmarks

set -e

ERRORS=0
WARNINGS=0

echo "=== VTT Hardware Benchmarks - Environment Validation ==="
echo ""

# Check container runtime
echo "Checking container runtime..."
if command -v docker &> /dev/null; then
    echo "  [OK] Docker found: $(docker --version)"
elif command -v podman &> /dev/null; then
    echo "  [OK] Podman found: $(podman --version)"
else
    echo "  [ERROR] Neither docker nor podman found"
    ((ERRORS++))
fi

# Check model directory
MODEL_DIR="${MODEL_DIR:-/mnt/ai-models}"
echo ""
echo "Checking model directory: $MODEL_DIR"
if [ -d "$MODEL_DIR" ]; then
    model_count=$(find "$MODEL_DIR" -name "*.gguf" -type f 2>/dev/null | wc -l)
    if [ "$model_count" -gt 0 ]; then
        echo "  [OK] Model directory exists with $model_count GGUF files"
    else
        echo "  [WARNING] Model directory exists but no GGUF files found"
        ((WARNINGS++))
    fi
else
    echo "  [ERROR] Model directory not found: $MODEL_DIR"
    ((ERRORS++))
fi

# Check GPU devices
echo ""
echo "Checking GPU access..."
if [ -e /dev/dri ] && [ -e /dev/kfd ]; then
    echo "  [OK] GPU devices found: /dev/dri, /dev/kfd"
elif [ -e /dev/dri ]; then
    echo "  [WARNING] Only /dev/dri found (Vulkan only, no ROCm)"
    ((WARNINGS++))
else
    echo "  [WARNING] No GPU devices found (CPU-only mode)"
    ((WARNINGS++))
fi

# Check disk space
echo ""
echo "Checking disk space..."
if command -v df &> /dev/null; then
    available=$(df -BG /var/lib/containers 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || echo "0")
    if [ "$available" -ge 50 ]; then
        echo "  [OK] Sufficient disk space: ${available}GB available"
    elif [ "$available" -ge 20 ]; then
        echo "  [WARNING] Low disk space: ${available}GB available (recommend 50GB+)"
        ((WARNINGS++))
    else
        echo "  [ERROR] Insufficient disk space: ${available}GB available (need 50GB+)"
        ((ERRORS++))
    fi
fi

# Check configuration file
CONFIG_FILE="${CONFIG_FILE:-./model-config.yaml}"
echo ""
echo "Checking configuration file: $CONFIG_FILE"
if [ -f "$CONFIG_FILE" ]; then
    echo "  [OK] Configuration file found"

    # Validate YAML syntax (basic check)
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
            echo "  [OK] Configuration file is valid YAML"
        else
            echo "  [WARNING] Configuration file may have YAML syntax errors"
            ((WARNINGS++))
        fi
    fi
else
    echo "  [WARNING] Configuration file not found (will use auto-discovery)"
    ((WARNINGS++))
fi

# Check for config parser
echo ""
echo "Checking config parser utility..."
PARSER_SCRIPT="$(dirname "$0")/config-parser.sh"
if [ -f "$PARSER_SCRIPT" ]; then
    echo "  [OK] Config parser found: $PARSER_SCRIPT"
else
    echo "  [ERROR] Config parser not found: $PARSER_SCRIPT"
    ((ERRORS++))
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "Status: FAILED - Fix errors before running tests"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "Status: PASSED WITH WARNINGS - Tests may not run optimally"
    exit 0
else
    echo "Status: PASSED - Environment ready for testing"
    exit 0
fi
