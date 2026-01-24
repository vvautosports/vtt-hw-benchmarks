#!/bin/bash
# Download AI models from HuggingFace with size warnings
# Usage: ./download-models.sh [light|default|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../../models-inventory.yaml}"
MODEL_DIR="${MODEL_DIR:-/mnt/ai-models}"
MODE="${1:-light}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== VTT Model Download Utility ===${NC}"
echo ""

# Check if huggingface-cli is installed
if ! command -v huggingface-cli &> /dev/null; then
    echo -e "${RED}ERROR: huggingface-cli not found${NC}"
    echo "Install with: pip install huggingface_hub"
    echo "Or: pip install 'huggingface_hub[cli]'"
    exit 1
fi

# Source config parser
source "$SCRIPT_DIR/config-parser.sh"

# Get model list based on mode
case "$MODE" in
    light)
        echo -e "${GREEN}Mode: Light (1-2 models, <16GB VRAM)${NC}"
        MODEL_LIST_KEY="light_models"
        ;;
    default)
        echo -e "${YELLOW}Mode: Default (5 models, requires 128GB RAM + large UMA)${NC}"
        MODEL_LIST_KEY="default_models"
        ;;
    all)
        echo -e "${RED}Mode: All (20+ models, auto-discovery not supported for download)${NC}"
        echo "Please specify 'light' or 'default'"
        exit 1
        ;;
    *)
        echo "Usage: $0 [light|default]"
        echo "  light   - 1-2 models for 16GB VRAM systems (21GB total)"
        echo "  default - 5 models for large systems (301GB total)"
        exit 1
        ;;
esac

echo ""

# Parse config to get model info
# Extract model names, sizes, and HF info from config
mapfile -t MODEL_NAMES < <(awk -v section="$MODEL_LIST_KEY" '
    $0 ~ "^" section ":" { in_section = 1; next }
    /^[a-z_]+:/ && in_section { exit }
    in_section && /name:/ {
        match($0, /name:[[:space:]]*["'\''"']?([^"'\''"]+)["'\''"']?/, arr)
        if (arr[1] != "") print arr[1]
    }
' "$CONFIG_FILE")

mapfile -t MODEL_SIZES < <(awk -v section="$MODEL_LIST_KEY" '
    $0 ~ "^" section ":" { in_section = 1; next }
    /^[a-z_]+:/ && in_section { exit }
    in_section && /size_gb:/ {
        match($0, /size_gb:[[:space:]]*([0-9]+)/, arr)
        if (arr[1] != "") print arr[1]
    }
' "$CONFIG_FILE")

mapfile -t HF_REPOS < <(awk -v section="$MODEL_LIST_KEY" '
    $0 ~ "^" section ":" { in_section = 1; next }
    /^[a-z_]+:/ && in_section { exit }
    in_section && /hf_repo:/ {
        match($0, /hf_repo:[[:space:]]*["'\''"']?([^"'\''"]+)["'\''"']?/, arr)
        if (arr[1] != "") print arr[1]
    }
' "$CONFIG_FILE")

mapfile -t HF_FILES < <(awk -v section="$MODEL_LIST_KEY" '
    $0 ~ "^" section ":" { in_section = 1; next }
    /^[a-z_]+:/ && in_section { exit }
    in_section && /hf_file:/ {
        match($0, /hf_file:[[:space:]]*["'\''"']?([^"'\''"]+)["'\''"']?/, arr)
        if (arr[1] != "") print arr[1]
    }
' "$CONFIG_FILE")

if [ ${#MODEL_NAMES[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No models found in config for mode: $MODE${NC}"
    exit 1
fi

# Get full paths for each model and check if they exist
mapfile -t MODEL_PATHS < <(awk -v section="$MODEL_LIST_KEY" '
    $0 ~ "^" section ":" { in_section = 1; next }
    /^[a-z_]+:/ && in_section { exit }
    in_section && /path:/ {
        match($0, /path:[[:space:]]*["'\''"']?([^"'\''"]+)["'\''"']?/, arr)
        if (arr[1] != "") print arr[1]
    }
' "$CONFIG_FILE")

# Check which models already exist
EXISTING_MODELS=()
MISSING_MODELS=()
TOTAL_SIZE=0
DOWNLOAD_SIZE=0

for i in "${!MODEL_NAMES[@]}"; do
    model_path="$MODEL_DIR/${MODEL_PATHS[$i]}"
    size="${MODEL_SIZES[$i]}"
    TOTAL_SIZE=$((TOTAL_SIZE + size))

    if [ -f "$model_path" ]; then
        EXISTING_MODELS+=("$i")
    else
        MISSING_MODELS+=("$i")
        DOWNLOAD_SIZE=$((DOWNLOAD_SIZE + size))
    fi
done

# Display model status
echo -e "${CYAN}Model Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-40s %10s %10s\n" "Model" "Size (GB)" "Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for i in "${!MODEL_NAMES[@]}"; do
    model_path="$MODEL_DIR/${MODEL_PATHS[$i]}"
    if [ -f "$model_path" ]; then
        printf "%-40s %10s ${GREEN}%10s${NC}\n" "${MODEL_NAMES[$i]}" "${MODEL_SIZES[$i]} GB" "✓ EXISTS"
    else
        printf "%-40s %10s ${YELLOW}%10s${NC}\n" "${MODEL_NAMES[$i]}" "${MODEL_SIZES[$i]} GB" "MISSING"
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-40s %10s\n" "Total size (all models)" "${TOTAL_SIZE} GB"
if [ ${#MISSING_MODELS[@]} -gt 0 ]; then
    printf "%-40s ${YELLOW}%10s${NC}\n" "Download needed" "${DOWNLOAD_SIZE} GB"
else
    echo -e "${GREEN}All models already downloaded!${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Exit if all models exist
if [ ${#MISSING_MODELS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All required models are already present in $MODEL_DIR${NC}"
    echo ""
    echo "Models are ready for testing:"
    echo "  cd docker && MODEL_CONFIG_MODE=$MODE ./run-ai-models.sh"
    echo ""
    exit 0
fi

echo -e "${YELLOW}Found ${#EXISTING_MODELS[@]} existing, need to download ${#MISSING_MODELS[@]} models${NC}"
echo ""

# Check disk space
if command -v df &> /dev/null; then
    AVAILABLE=$(df -BG "$MODEL_DIR" 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || echo "unknown")
    if [ "$AVAILABLE" != "unknown" ]; then
        echo -e "${CYAN}Available disk space: ${AVAILABLE} GB${NC}"
        if [ "$AVAILABLE" -lt "$DOWNLOAD_SIZE" ]; then
            echo -e "${RED}ERROR: Insufficient disk space!${NC}"
            echo -e "Need: ${DOWNLOAD_SIZE} GB, Available: ${AVAILABLE} GB"
            echo ""
            exit 1
        fi
    fi
fi

# Confirm download
echo -e "${YELLOW}This will download ${DOWNLOAD_SIZE} GB of missing model files to:${NC}"
echo "  $MODEL_DIR"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Download cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Starting downloads...${NC}"
echo ""

# Create model directory
mkdir -p "$MODEL_DIR"

# Download only missing models
for i in "${MISSING_MODELS[@]}"; do
    model_name="${MODEL_NAMES[$i]}"
    hf_repo="${HF_REPOS[$i]}"
    hf_file="${HF_FILES[$i]}"
    size="${MODEL_SIZES[$i]}"
    model_path="$MODEL_DIR/${MODEL_PATHS[$i]}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Downloading: $model_name ($size GB)${NC}"
    echo "Repository: $hf_repo"
    echo "File: $hf_file"
    echo "Destination: $model_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Create output directory
    output_dir=$(dirname "$model_path")
    mkdir -p "$output_dir"

    # Download using huggingface-cli
    if huggingface-cli download "$hf_repo" "$hf_file" --local-dir "$output_dir" --local-dir-use-symlinks False; then
        echo -e "${GREEN}✓ Download complete: $model_name${NC}"

        # Verify file exists
        if [ -f "$model_path" ]; then
            actual_size=$(du -h "$model_path" | cut -f1)
            echo -e "  File size: $actual_size"
        fi
    else
        echo -e "${RED}✗ Download failed: $model_name${NC}"
        echo "You can try manually downloading from:"
        echo "  https://huggingface.co/$hf_repo/blob/main/$hf_file"
    fi

    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Download process complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Models downloaded to: $MODEL_DIR"
echo ""
echo "Next steps:"
echo "  1. Validate environment: ./scripts/utils/validate-environment.sh"
echo "  2. Run tests: cd docker && MODEL_CONFIG_MODE=$MODE ./run-ai-models.sh"
echo ""
