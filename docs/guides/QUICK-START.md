# Quick Start Guide

Get running in under 10 minutes.

## Prerequisites

- Docker or Podman installed
- Model directory at `/mnt/ai-models` with GGUF files
- AMD GPU access (`/dev/dri`, `/dev/kfd`)

## Run Default Test (5 Models)

```bash
cd docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

**Expected:** 30-45 minute test of 5 models (DeepSeek-R1, GLM-4.7, MiniMax, Qwen3-235B, GPT-OSS-20B)

## View Results

```bash
# JSON output
cat ../results/ai-models-*-latest.json | jq .

# Full log
less ../results/ai-models-*-latest.log
```

## Quick Validation Test

Test one model in 2-3 minutes:

```bash
MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test
```

## Run All Models (20+)

```bash
MODEL_CONFIG_MODE=all ./run-ai-models.sh
```

**Expected:** 2-3 hours, auto-discovers all GGUF files in model directory

## Next Steps

- **Customize models:** Edit `models-inventory.yaml` (see [CONFIGURATION.md](CONFIGURATION.md))
- **Windows setup:** See [WINDOWS-SETUP.md](WINDOWS-SETUP.md)
- **Deploy to MS-01:** See [MS-01-LXC-DEPLOYMENT.md](MS-01-LXC-DEPLOYMENT.md)

## Troubleshooting

**No models found:**
```bash
ls -la /mnt/ai-models  # Verify directory exists
```

**GPU not accessible:**
```bash
ls -l /dev/dri /dev/kfd  # Should show device files
```

**Container runtime missing:**
```bash
docker --version || podman --version
```
