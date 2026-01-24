#!/bin/bash
# Comprehensive AI model testing with llama-server
# Supports both single-file and multi-part GGUF models
# Tests multiple context sizes: 512, 4K, 16K, 32K, 65K

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESULTS_DIR="${PROJECT_ROOT}/results"
MODEL_DIR="${MODEL_DIR:-/mnt/ai-models}"
CONFIG_FILE="${PROJECT_ROOT}/models-inventory.yaml"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTNAME=$(hostname)

# Test configuration
PORT=8001
HOST="127.0.0.1"
CONTEXT_SIZES=(512 4096 16384 32768 65536)
TEST_PROMPT="Write a Python function to calculate the Fibonacci sequence up to n terms. Include error handling and docstrings."

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Test AI models comprehensively using llama-server.
Supports both single-file and multi-part GGUF models.

OPTIONS:
    --model-dir PATH    Path to models directory (default: /mnt/ai-models)
    --model NAME        Test specific model (directory name)
    --mode MODE         Test mode: quick, standard, comprehensive (default: standard)
    --port PORT         llama-server port (default: 8001)
    --help              Show this help message

MODES:
    quick          512p/128g only (1 context size)
    standard       512, 4K, 16K contexts
    comprehensive  512, 4K, 16K, 32K, 65K contexts

EXAMPLES:
    # Test all models with standard contexts
    $0 --mode standard
    
    # Test specific model with all contexts
    $0 --model GLM-4.7-REAP-218B-A32B --mode comprehensive
    
    # Quick test of MiniMax
    $0 --model MiniMax-M2.1 --mode quick

NOTES:
    - Automatically detects single-file vs multi-part models
    - Multi-part models require all parts in same directory
    - Results saved to results/comprehensive-{timestamp}.json
    - llama-server must be available in PATH or container

EOF
    exit 1
}

# Parse arguments
MODE="standard"
SPECIFIC_MODEL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --model-dir)
            MODEL_DIR="$2"
            shift 2
            ;;
        --model)
            SPECIFIC_MODEL="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Set context sizes based on mode
case $MODE in
    quick)
        CONTEXT_SIZES=(512)
        GEN_TOKENS=128
        ;;
    standard)
        CONTEXT_SIZES=(512 4096 16384)
        GEN_TOKENS=512
        ;;
    comprehensive)
        CONTEXT_SIZES=(512 4096 16384 32768 65536)
        GEN_TOKENS=1024
        ;;
    *)
        echo -e "${RED}ERROR: Invalid mode: $MODE${NC}"
        echo "Valid modes: quick, standard, comprehensive"
        exit 1
        ;;
esac

echo "=== VTT Comprehensive AI Model Testing ==="
echo "Host: $HOSTNAME"
echo "Date: $(date +%Y-%m-%dT%H:%M:%S)"
echo "Mode: $MODE"
echo "Model Directory: $MODEL_DIR"
echo "Context Sizes: ${CONTEXT_SIZES[*]}"
echo "Generation Tokens: $GEN_TOKENS"
echo ""

# Find models to test
if [ -n "$SPECIFIC_MODEL" ]; then
    MODEL_PATH="$MODEL_DIR/$SPECIFIC_MODEL"
    if [ ! -d "$MODEL_PATH" ]; then
        echo -e "${RED}ERROR: Model directory not found: $MODEL_PATH${NC}"
        exit 1
    fi
    MODELS=("$SPECIFIC_MODEL")
else
    # Find all model directories
    mapfile -t MODELS < <(find "$MODEL_DIR" -maxdepth 1 -type d -name "*" | grep -v "lost+found" | xargs -n1 basename | grep -v "^ai-models$" | sort)
fi

echo "Found ${#MODELS[@]} model(s) to test"
echo ""

# Check if llama-server is available
if ! command -v llama-server &> /dev/null; then
    echo -e "${RED}ERROR: llama-server not found in PATH${NC}"
    echo "Please install llama.cpp or add llama-server to PATH"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/comprehensive-$HOSTNAME-$TIMESTAMP.json"
LOG_FILE="$RESULTS_DIR/comprehensive-$HOSTNAME-$TIMESTAMP.log"

# Initialize JSON output
cat > "$RESULTS_FILE" <<EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": "$(date +%Y-%m-%dT%H:%M:%S)",
  "mode": "$MODE",
  "context_sizes": [$(IFS=,; echo "${CONTEXT_SIZES[*]}")],
  "generation_tokens": $GEN_TOKENS,
  "models": [
EOF

FIRST_MODEL=true

# Test each model
for model_name in "${MODELS[@]}"; do
    model_path="$MODEL_DIR/$model_name"
    
    echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "Testing: $model_name" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    
    # Find GGUF files
    mapfile -t gguf_files < <(find "$model_path" -name "*.gguf" -type f 2>/dev/null | sort)
    
    if [ ${#gguf_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}SKIP: No GGUF files found${NC}" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        continue
    fi
    
    # Determine if multi-part
    primary_file="${gguf_files[0]}"
    part_count=${#gguf_files[@]}
    
    if [[ $(basename "$primary_file") =~ -00001-of-[0-9]+ ]]; then
        echo "Type: Multi-part model ($part_count parts)" | tee -a "$LOG_FILE"
    else
        echo "Type: Single-file model" | tee -a "$LOG_FILE"
    fi
    
    # Get model size
    total_size=0
    for file in "${gguf_files[@]}"; do
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        total_size=$((total_size + size))
    done
    size_gb=$(echo "scale=2; $total_size / 1024 / 1024 / 1024" | bc)
    
    echo "Size: ${size_gb} GB" | tee -a "$LOG_FILE"
    echo "Primary file: $(basename "$primary_file")" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Test each context size
    context_results=()
    
    for ctx_size in "${CONTEXT_SIZES[@]}"; do
        echo "Testing context: ${ctx_size}" | tee -a "$LOG_FILE"
        
        # Start llama-server
        echo "Starting llama-server..." | tee -a "$LOG_FILE"
        llama-server \
            -m "$primary_file" \
            -c "$ctx_size" \
            -ngl 999 \
            -fa 1 \
            -mmp 0 \
            --port "$PORT" \
            --host "$HOST" \
            > /tmp/llama-server-$$.log 2>&1 &
        
        SERVER_PID=$!
        
        # Wait for server to start
        sleep 5
        
        # Check if server is running
        if ! kill -0 $SERVER_PID 2>/dev/null; then
            echo -e "${RED}ERROR: llama-server failed to start${NC}" | tee -a "$LOG_FILE"
            cat /tmp/llama-server-$$.log | tee -a "$LOG_FILE"
            context_results+=('{"context":'"$ctx_size"',"status":"failed","error":"server_start_failed"}')
            continue
        fi
        
        # Wait for server to be ready
        for i in {1..30}; do
            if curl -s "http://$HOST:$PORT/health" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        
        # Test inference
        start_time=$(date +%s)
        
        response=$(curl -s "http://$HOST:$PORT/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"test\",
                \"messages\": [{\"role\": \"user\", \"content\": \"$TEST_PROMPT\"}],
                \"max_tokens\": $GEN_TOKENS,
                \"stream\": false
            }" 2>&1)
        
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        
        # Parse response
        if echo "$response" | jq . > /dev/null 2>&1; then
            tokens=$(echo "$response" | jq -r '.usage.completion_tokens // 0')
            tps=$(echo "scale=2; $tokens / $duration" | bc)
            
            echo "  Duration: ${duration}s" | tee -a "$LOG_FILE"
            echo "  Tokens: $tokens" | tee -a "$LOG_FILE"
            echo "  Speed: ${tps} t/s" | tee -a "$LOG_FILE"
            
            context_results+=("{\"context\":$ctx_size,\"duration\":$duration,\"tokens\":$tokens,\"tps\":$tps}")
        else
            echo -e "  ${RED}ERROR: Invalid response${NC}" | tee -a "$LOG_FILE"
            echo "$response" | tee -a "$LOG_FILE"
            context_results+=("{\"context\":$ctx_size,\"status\":\"failed\",\"error\":\"invalid_response\"}")
        fi
        
        # Stop server
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        rm -f /tmp/llama-server-$$.log
        
        echo "" | tee -a "$LOG_FILE"
    done
    
    # Add model results to JSON
    if [ "$FIRST_MODEL" = false ]; then
        echo "," >> "$RESULTS_FILE"
    fi
    FIRST_MODEL=false
    
    cat >> "$RESULTS_FILE" <<EOF
    {
      "model_name": "$model_name",
      "parts": $part_count,
      "size_gb": $size_gb,
      "results": [
        $(IFS=,; echo "${context_results[*]}")
      ]
    }
EOF
    
    echo "" | tee -a "$LOG_FILE"
done

# Finalize JSON
cat >> "$RESULTS_FILE" <<EOF

  ]
}
EOF

echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "Testing Complete" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Results saved to:" | tee -a "$LOG_FILE"
echo "  JSON: $RESULTS_FILE" | tee -a "$LOG_FILE"
echo "  Log:  $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Show summary
echo "Summary:" | tee -a "$LOG_FILE"
cat "$RESULTS_FILE" | jq -r '.models[] | "  \(.model_name): \(.size_gb)GB, \(.parts) part(s)"' | tee -a "$LOG_FILE"
