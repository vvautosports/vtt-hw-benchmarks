# Configuration Reference

Configuration is controlled by `model-config.yaml` in the repository root.

## Basic Usage

### Default 5 Models

```bash
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

### All Models (Auto-Discovery)

```bash
MODEL_CONFIG_MODE=all ./run-ai-models.sh
```

### Quick Test (One Model)

```bash
MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test
```

## Configuration File Structure

```yaml
version: "1.0"
mode: "default"              # default or all
model_dir: "/mnt/ai-models"  # Base directory for models

default_models:
  - name: "Model-Name"
    path: "subdir/model.gguf"  # Relative to model_dir
    size_gb: 33
    use_case: "Description"

context_profiles:
  quick:
    - prompt: 512
      generation: 128

  standard:
    - prompt: 512
      generation: 128
    - prompt: 4096
      generation: 512
```

## Environment Variables

Override config values:

```bash
MODEL_CONFIG_MODE=default    # Force default or all mode
MODEL_DIR=/custom/path       # Override model directory
CONFIG_FILE=/path/config.yaml # Use different config file
```

## Custom Model Selection

Edit `model-config.yaml` to change default models:

```yaml
default_models:
  - name: "YourModel"
    path: "your-model-dir/model.gguf"
    size_gb: 50
    use_case: "Custom testing"
```

For multi-part models, reference the first file:

```yaml
  - name: "Large-Model"
    path: "large-dir/model-00001-of-00003.gguf"
    size_gb: 120
    use_case: "Ultra-large"
```

## Examples

See `config/examples/` for:
- `model-config.default.yaml` - Default 5-model setup
- `model-config.all-models.yaml` - Auto-discovery setup

## Context Profiles

Not yet implemented in run-ai-models.sh. Reserved for future use to control prompt/generation token counts.
