#!/bin/bash
# Quick validation test for MiniMax-M2.1-Q3_K_XL Unsloth GGUF
# Validates Unsloth quality claims before downloading larger DeepSeek models

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$REPO_ROOT/results}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)

MODEL_PATH="${1:-/mnt/ai-models/MiniMax-M2.1-GGUF/MiniMax-M2.1-Q3_K_XL.gguf}"

if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Model not found: $MODEL_PATH"
    echo ""
    echo "Usage: $0 [path-to-minimax-gguf]"
    echo ""
    echo "Default path: /mnt/ai-models/MiniMax-M2.1-GGUF/MiniMax-M2.1-Q3_K_XL.gguf"
    exit 1
fi

# Detect runtime
if command -v podman &> /dev/null; then
    RUNTIME="podman"
elif command -v docker &> /dev/null; then
    RUNTIME="docker"
else
    echo "❌ No container runtime found"
    exit 1
fi

mkdir -p "$RESULTS_DIR"
REPORT_FILE="$RESULTS_DIR/minimax-unsloth-validation-${HOSTNAME}-${TIMESTAMP}.md"

echo "═══════════════════════════════════════════════════════" | tee "$REPORT_FILE"
echo "MiniMax-M2.1-Q3_K_XL Unsloth GGUF Validation Test" | tee -a "$REPORT_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Date: $(date -Iseconds)" | tee -a "$REPORT_FILE"
echo "Host: $HOSTNAME" | tee -a "$REPORT_FILE"
echo "Model: $MODEL_PATH" | tee -a "$REPORT_FILE"
echo "Size: $(du -h "$MODEL_PATH" | cut -f1)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test 1: Baseline Performance
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "Test 1: Baseline Performance (512 prompt, 128 gen)" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

MODEL_DIR_PATH=$(dirname "$MODEL_PATH")

BASELINE_OUTPUT=$($RUNTIME run --rm \
    --device /dev/dri --device /dev/kfd \
    --group-add video --group-add render \
    --security-opt seccomp=unconfined \
    -v "$MODEL_DIR_PATH":/models:ro,z \
    -e MODEL_PATH=/models/$(basename "$MODEL_PATH") \
    vtt-benchmark-llama 2>&1 || echo "FAILED")

PROMPT_TPS=$(echo "$BASELINE_OUTPUT" | grep "Prompt Processing:" | awk '{print $3}')
GEN_TPS=$(echo "$BASELINE_OUTPUT" | grep "Text Generation:" | awk '{print $3}')

echo "Prompt Processing: ${PROMPT_TPS:-FAILED} t/s" | tee -a "$REPORT_FILE"
echo "Text Generation: ${GEN_TPS:-FAILED} t/s" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test 2: Quality Check - Simple reasoning task
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "Test 2: Quality Validation - Reasoning Task" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

QUALITY_PROMPT="Explain the trade-offs between monolithic and microservices architecture for a startup with 8 developers building a fintech platform. Be specific about team size and timeline implications."

echo "Prompt:" | tee -a "$REPORT_FILE"
echo "  $QUALITY_PROMPT" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Running inference..." | tee -a "$REPORT_FILE"

QUALITY_OUTPUT=$($RUNTIME run --rm \
    --device /dev/dri --device /dev/kfd \
    --group-add video --group-add render \
    --security-opt seccomp=unconfined \
    -v "$MODEL_DIR_PATH":/models:ro,z \
    --entrypoint llama-cli \
    vtt-benchmark-llama \
    -m /models/$(basename "$MODEL_PATH") \
    -p "$QUALITY_PROMPT" \
    -n 256 \
    -c 4096 \
    -ngl 999 -fa 1 -mmp 0 2>&1)

# Extract just the response (skip llama.cpp metadata)
RESPONSE=$(echo "$QUALITY_OUTPUT" | sed -n '/^[^[].*[a-zA-Z]/p' | tail -n +2 | head -n 20)

echo "" | tee -a "$REPORT_FILE"
echo "Response (first 20 lines):" | tee -a "$REPORT_FILE"
echo "$RESPONSE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Test 3: Gibberish Detection
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "Test 3: Coherence Check (Gibberish Detection)" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Simple heuristic: check for repeated patterns, excessive punctuation
REPEATED_PATTERNS=$(echo "$RESPONSE" | grep -o -E '(.{3,})\1{3,}' | wc -l)
EXCESSIVE_PUNCT=$(echo "$RESPONSE" | grep -o -E '[!?.,]{5,}' | wc -l)

if [ "$REPEATED_PATTERNS" -gt 2 ] || [ "$EXCESSIVE_PUNCT" -gt 2 ]; then
    echo "⚠️  WARNING: Possible gibberish detected" | tee -a "$REPORT_FILE"
    echo "  Repeated patterns: $REPEATED_PATTERNS" | tee -a "$REPORT_FILE"
    echo "  Excessive punctuation: $EXCESSIVE_PUNCT" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "  This may indicate low quantization quality." | tee -a "$REPORT_FILE"
    echo "  Manual review recommended before downloading DeepSeek-V3.1-1bit." | tee -a "$REPORT_FILE"
else
    echo "✅ Response appears coherent" | tee -a "$REPORT_FILE"
    echo "  No obvious gibberish patterns detected" | tee -a "$REPORT_FILE"
fi
echo "" | tee -a "$REPORT_FILE"

# Comparison to current champions
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "Comparison to Current Champions" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

cat >> "$REPORT_FILE" <<EOF
Current Reasoning Champions:
- GLM-4.7-REAP-218B: 101 t/s prompt, 11.5 t/s gen (218B params, 92GB)
- Qwen3-235B-Q3:     131 t/s prompt, 17.1 t/s gen (235B params, 97GB)

MiniMax-M2.1-Q3_K_XL (229B params, 101GB):
- Prompt: ${PROMPT_TPS:-N/A} t/s
- Gen:    ${GEN_TPS:-N/A} t/s

Performance vs REAP-218B:
EOF

if [ -n "$PROMPT_TPS" ] && [ "$PROMPT_TPS" != "FAILED" ]; then
    PROMPT_DIFF=$(echo "scale=2; (($PROMPT_TPS - 101) / 101) * 100" | bc)
    GEN_DIFF=$(echo "scale=2; (($GEN_TPS - 11.5) / 11.5) * 100" | bc)

    echo "- Prompt: ${PROMPT_DIFF}% faster" | tee -a "$REPORT_FILE"
    echo "- Gen:    ${GEN_DIFF}% faster" | tee -a "$REPORT_FILE"
else
    echo "- Unable to compare (benchmark failed)" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"

# Decision tree
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "Decision: Should You Download DeepSeek-V3.1-1bit (192GB)?" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

cat >> "$REPORT_FILE" <<EOF
Evaluation criteria:

1. Quality Check:
   - Is response coherent? (not gibberish)
   - Does reasoning quality match or exceed REAP-218B?
   - Manual review: Does answer show deep analysis?

2. Performance Check:
   - Is speed acceptable for reasoning tasks? (>10 t/s gen OK)
   - Does MiniMax fit comfortably in 128GB? (yes, ~121GB total)

3. Value Proposition:
   - If MiniMax quality ≥ REAP-218B → MiniMax is new reasoning champion
   - If MiniMax quality excellent → Validates Unsloth optimization
   - If quality disappointing → Don't download larger Unsloth models

Recommendation:
EOF

if [ "$REPEATED_PATTERNS" -gt 2 ] || [ "$EXCESSIVE_PUNCT" -gt 2 ]; then
    echo "⚠️  CAUTION: Possible gibberish detected" | tee -a "$REPORT_FILE"
    echo "Manually review response quality before proceeding." | tee -a "$REPORT_FILE"
    echo "If gibberish confirmed, SKIP DeepSeek-V3.1-1bit download." | tee -a "$REPORT_FILE"
elif [ -z "$PROMPT_TPS" ] || [ "$PROMPT_TPS" = "FAILED" ]; then
    echo "⚠️  WARNING: Benchmark failed" | tee -a "$REPORT_FILE"
    echo "Investigate error before proceeding with larger models." | tee -a "$REPORT_FILE"
else
    echo "✅ Preliminary validation PASSED" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "Next steps:" | tee -a "$REPORT_FILE"
    echo "1. Manually review response quality above" | tee -a "$REPORT_FILE"
    echo "2. If quality excellent → Consider DeepSeek-V3.1-1bit download" | tee -a "$REPORT_FILE"
    echo "3. If quality good → MiniMax may be sufficient (better fit)" | tee -a "$REPORT_FILE"
    echo "4. Run full benchmark suite: ./scripts/comprehensive-ai-test.sh" | tee -a "$REPORT_FILE"
fi

echo "" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "✅ Validation test complete" | tee -a "$REPORT_FILE"
echo "─────────────────────────────────────────────────────────" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Full output saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "To run full benchmark suite:" | tee -a "$REPORT_FILE"
echo "  ./scripts/comprehensive-ai-test.sh" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
