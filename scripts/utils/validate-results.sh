#!/bin/bash
# Post-test result validation
# Validates benchmark results after execution

set -e

RESULTS_DIR="${1:-../results}"
ERRORS=0
WARNINGS=0

echo "=== VTT Hardware Benchmarks - Results Validation ==="
echo ""

if [ ! -d "$RESULTS_DIR" ]; then
    echo "[ERROR] Results directory not found: $RESULTS_DIR"
    exit 1
fi

# Find most recent JSON result file
LATEST_JSON=$(find "$RESULTS_DIR" -name "ai-models-*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$LATEST_JSON" ]; then
    echo "[ERROR] No result files found in $RESULTS_DIR"
    exit 1
fi

echo "Validating: $(basename "$LATEST_JSON")"
echo ""

# Check JSON syntax
echo "Checking JSON syntax..."
if command -v jq &> /dev/null; then
    if jq empty "$LATEST_JSON" 2>/dev/null; then
        echo "  [OK] Valid JSON format"
    else
        echo "  [ERROR] Invalid JSON format"
        ((ERRORS++))
    fi
else
    echo "  [WARNING] jq not found, skipping JSON validation"
    ((WARNINGS++))
fi

# Check for required fields
if command -v jq &> /dev/null; then
    echo ""
    echo "Checking required fields..."

    if jq -e '.hostname' "$LATEST_JSON" &>/dev/null; then
        echo "  [OK] Hostname field present"
    else
        echo "  [ERROR] Missing hostname field"
        ((ERRORS++))
    fi

    if jq -e '.timestamp' "$LATEST_JSON" &>/dev/null; then
        echo "  [OK] Timestamp field present"
    else
        echo "  [ERROR] Missing timestamp field"
        ((ERRORS++))
    fi

    if jq -e '.models' "$LATEST_JSON" &>/dev/null; then
        echo "  [OK] Models field present"

        # Count models tested
        model_count=$(jq '.models | length' "$LATEST_JSON")
        echo "  [INFO] Tested $model_count model(s)"

        if [ "$model_count" -eq 0 ]; then
            echo "  [ERROR] No models were tested"
            ((ERRORS++))
        fi
    else
        echo "  [ERROR] Missing models field"
        ((ERRORS++))
    fi
fi

# Validate performance metrics
if command -v jq &> /dev/null; then
    echo ""
    echo "Checking performance metrics..."

    zero_results=$(jq '[.models[] | select(.results.prompt_processing_tps == 0 or .results.text_generation_tps == 0)] | length' "$LATEST_JSON")

    if [ "$zero_results" -gt 0 ]; then
        echo "  [WARNING] $zero_results model(s) have zero performance metrics"
        ((WARNINGS++))

        # Show which models failed
        jq -r '.models[] | select(.results.prompt_processing_tps == 0 or .results.text_generation_tps == 0) | "    - " + .model_name' "$LATEST_JSON"
    else
        echo "  [OK] All models have non-zero performance metrics"
    fi
fi

# Check file sizes
echo ""
echo "Checking file sizes..."
json_size=$(stat -c%s "$LATEST_JSON" 2>/dev/null || stat -f%z "$LATEST_JSON" 2>/dev/null || echo 0)
if [ "$json_size" -gt 1000 ]; then
    echo "  [OK] Results file size: $json_size bytes"
else
    echo "  [WARNING] Results file seems small: $json_size bytes"
    ((WARNINGS++))
fi

# Check for corresponding log file
LOG_FILE="${LATEST_JSON%.json}.log"
echo ""
echo "Checking for log file..."
if [ -f "$LOG_FILE" ]; then
    echo "  [OK] Log file found: $(basename "$LOG_FILE")"
else
    echo "  [WARNING] Log file not found: $(basename "$LOG_FILE")"
    ((WARNINGS++))
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo "Status: FAILED - Results have errors"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "Status: PASSED WITH WARNINGS - Review warnings above"
    exit 0
else
    echo "Status: PASSED - Results are valid"
    exit 0
fi
