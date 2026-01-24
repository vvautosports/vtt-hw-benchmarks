# Configuration Reference

VTT Hardware Benchmarks uses a two-tier configuration system:

1. **`benchmark-config.yaml`** - High-level test configuration (what to run)
2. **`models-inventory.yaml`** - AI model inventory (model specifications)

## High-Level Configuration

### benchmark-config.yaml

Controls which benchmarks to run and test modes:

```yaml
# System Profile
system:
  type: "framework-desktop"  # framework-desktop, hp-zbook, ms-01
  name: "auto"               # auto-detect or specify name

# Benchmark Selection
benchmarks:
  enabled:
    - cpu              # 7-Zip compression
    - memory           # STREAM bandwidth
    - storage          # fio I/O testing
    - ai-inference     # llama.cpp models

# AI Testing Configuration
ai_testing:
  mode: "default"      # light (16GB), default (5 models), all (auto-discover)
  test_depth: "quick"  # quick, standard, comprehensive
```

### System Types

- **framework-desktop**: Framework mainboard with 128GB RAM
- **hp-zbook**: HP ZBook laptops (various configs)
- **ms-01**: Minisforum MS-01 server

### AI Testing Modes

- **light**: 1-2 small models for 16GB VRAM systems (GPT-OSS-20B, Qwen3-8B)
- **default**: 5 curated models for comprehensive testing
- **all**: Auto-discover all GGUF files in `/mnt/ai-models`

### Test Depth

- **quick**: Single context size (512p/128g), ~2-3 min per model
- **standard**: Multiple context sizes (512p to 16K), ~10-15 min per model
- **comprehensive**: Full context range (512p to 32K), ~30-45 min per model

## Model Inventory

### models-inventory.yaml

Defines available AI models and their specifications:

```yaml
version: "1.0"
mode: "default"
model_dir: "/mnt/ai-models"

# Light mode models (16GB VRAM)
light_models:
  - name: "GPT-OSS-20B"
    path: "gpt-oss-20b-F16/gpt-oss-20b-F16.gguf"
    size_gb: 13
    vram_gb: 14
    use_case: "Speed champion"
    hf_repo: "unsloth/gpt-oss-20b-F16-GGUF"
    hf_file: "gpt-oss-20b-F16.gguf"

# Default 5 models
default_models:
  - name: "GLM-4.7-Flash-Q8"
    path: "GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf"
    size_gb: 33
    vram_gb: 35
    parts: 1
    test_strategy: "both"  # llama-bench and llama-server
    use_case: "Current champion - best efficiency"
```

### Model Properties

- **name**: Display name for results
- **path**: Relative path from `model_dir`
- **size_gb**: Model file size on disk
- **vram_gb**: Estimated VRAM requirement
- **parts**: Number of files (1 = single-file, 2+ = multi-part)
- **test_strategy**: `both` (quick+comprehensive) or `server_only` (comprehensive only)
- **use_case**: Description of model's purpose
- **hf_repo/hf_file**: HuggingFace download info

## Environment Variables

Override config values at runtime:

```bash
# Override model directory
MODEL_DIR=/custom/path ./run-ai-models.sh

# Use specific config file
CONFIG_FILE=./custom-inventory.yaml ./run-ai-models.sh

# Select test mode
MODEL_CONFIG_MODE=light ./run-ai-models.sh
```

## Basic Usage Examples

### Quick Test (Default Models)

```bash
cd docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test
```

### Comprehensive Test (All Models)

```bash
MODEL_CONFIG_MODE=all ./run-ai-models.sh
```

### Custom Model Selection

Edit `models-inventory.yaml` to add/remove models from `default_models` list.

### Light Mode (16GB Systems)

```bash
MODEL_CONFIG_MODE=light ./run-ai-models.sh
```

## Example Configurations

Pre-configured examples in `config/examples/`:

- **models-inventory.default.yaml** - Default 5-model setup
- **models-inventory.all-models.yaml** - Auto-discovery setup

Copy and customize:

```bash
cp config/examples/models-inventory.default.yaml models-inventory.yaml
# Edit as needed
```

## Configuration Workflow

1. **Set system type** in `benchmark-config.yaml`
2. **Choose benchmarks** to enable
3. **Select AI test mode** (light/default/all)
4. **Customize model inventory** if needed
5. **Run benchmarks** with desired test depth

## See Also

- [Quick Start Guide](QUICK-START.md)
- [Multi-Part Model Testing](MULTI-PART-MODEL-TESTING.md)
- [Model Testing Strategy](../reference/AI-MODEL-STRATEGY.md)
