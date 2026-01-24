# HP ZBook Deployment Guide

Complete deployment procedure for HP ZBook Ultra G1a laptops with VTT Hardware Benchmarks in light mode configuration.

## Overview

This guide covers the complete setup process for HP ZBook laptops using the automated setup script. The light mode configuration uses two small models suitable for systems with limited VRAM:

- **GPT-OSS-20B** (13GB) - Speed champion
- **Qwen3-8B-128K-Q8** (9GB) - Latest Qwen3 with 128K context

**Total download:** ~22GB
**Setup time:** 30-45 minutes (including downloads)

## Prerequisites

### Hardware Requirements

- HP ZBook Ultra G1a with AMD Ryzen AI Max+ 395
- Minimum 16GB RAM (48GB recommended for VM testing)
- 40GB+ free disk space
- Network connectivity

### Software Requirements

- Windows 11 (recommended) or Windows 10 21H2+
- Administrator access
- Git for Windows (or download repo as ZIP)

### Network Access

Ensure the laptop can access:
- `github.com` - Repository and container registry
- `huggingface.co` - Model downloads
- `get.docker.com` - Docker installation

## Pre-Deployment Checklist

Before starting deployment on HP laptops:

- [ ] Docker images built and pushed to GHCR from Framework
- [ ] Tested complete workflow in Windows VM
- [ ] Models available on HuggingFace (verify links work)
- [ ] HP laptop has Windows 11 installed and updated
- [ ] HP laptop has minimum 40GB free disk space
- [ ] Network connectivity verified
- [ ] Administrator account ready

## Deployment Steps

### Step 1: Clone Repository

```powershell
# Option 1: Using Git
cd C:\
git clone https://github.com/vvautosports/vtt-hw-benchmarks.git
cd vtt-hw-benchmarks

# Option 2: Download ZIP
# Download from: https://github.com/vvautosports/vtt-hw-benchmarks/archive/refs/heads/master.zip
# Extract to C:\vtt-hw-benchmarks
```

### Step 2: Run Automated Setup

Open PowerShell as Administrator:

```powershell
cd C:\vtt-hw-benchmarks

# Run automated setup
.\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath "D:\ai-models"
```

**What it does:**
1. Validates system requirements (Windows version, disk space, network)
2. Installs WSL2 (requires restart)
3. Installs Docker in WSL2
4. Downloads light models from HuggingFace (~22GB)
5. Pulls benchmark containers from GHCR
6. Runs validation test (2-3 minutes)

**Expected behavior:**
- First run will install WSL2 and require restart
- After restart, run the script again
- Second run will complete setup
- Total time: 30-45 minutes

### Step 3: Verify Installation

After setup completes, verify:

```powershell
# Check WSL2
wsl --status

# Check Docker
wsl bash -c "docker --version"

# Check containers
wsl bash -c "docker images | grep vtt-benchmark"

# Check models
dir D:\ai-models
```

**Expected output:**
- WSL2 status shows default version 2
- Docker version 24.x or later
- 4 benchmark containers (7zip, stream, storage, llama)
- 2 model directories with GGUF files

### Step 4: Run Benchmarks

```powershell
# Open WSL2
wsl

# Navigate to repository
cd /mnt/c/vtt-hw-benchmarks/docker

# Run light mode benchmarks (both models)
MODEL_CONFIG_MODE=light ./run-ai-models.sh

# Or run quick test (first model only)
MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test
```

**Expected results:**
- Quick test: 2-3 minutes
- Full light test: 5-10 minutes
- Results saved to `results/` directory

### Step 5: Commit Results

```powershell
# In PowerShell (not WSL)
cd C:\vtt-hw-benchmarks

# Add results
git add results/

# Commit with hostname
git commit -m "results: HP ZBook light mode - $(hostname)"

# Push to repository
git push
```

## Advanced Options

### Non-Interactive Mode

For bulk deployment or scripted setups:

```powershell
.\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath "D:\ai-models" -NonInteractive
```

### Skip Model Download

If models are already downloaded or will be copied from USB:

```powershell
.\scripts\utils\Setup-HP-ZBook-Automated.ps1 -SkipModels
```

### Skip Validation Test

To complete setup faster without running the validation test:

```powershell
.\scripts\utils\Setup-HP-ZBook-Automated.ps1 -SkipTests
```

### Manual Model Download

If automated download fails, download models manually:

```powershell
.\scripts\utils\Download-Light-Models.ps1 -ModelPath "D:\ai-models"
```

## Troubleshooting

### WSL2 Installation Fails

**Symptoms:**
- `wsl --install` fails or hangs
- Error: "Virtual Machine Platform not enabled"

**Solutions:**
1. Enable Windows features:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```
2. Restart computer
3. Run: `wsl --update`
4. Set WSL2 as default: `wsl --set-default-version 2`

### Docker Not Starting

**Symptoms:**
- `docker --version` fails in WSL2
- Error: "Cannot connect to Docker daemon"

**Solutions:**
```bash
# In WSL2
sudo service docker start

# If still fails, reinstall Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

### Model Download Fails

**Symptoms:**
- Download script times out
- BITS transfer fails

**Solutions:**
1. Check network connection
2. Verify HuggingFace is accessible: https://huggingface.co
3. Try manual download with browser
4. Use `-Force` flag to retry: `.\Download-Light-Models.ps1 -Force`

### Container Pull Fails

**Symptoms:**
- `pull-from-ghcr.sh` fails
- Error: "manifest unknown" or "unauthorized"

**Solutions:**
1. Verify images are published to GHCR:
   - Visit: https://github.com/orgs/vvautosports/packages
   - Ensure images are public or you're authenticated
2. Manually pull images:
   ```bash
   docker pull ghcr.io/vvautosports/vtt-hw-benchmarks/vtt-benchmark-llama:latest
   ```
3. If images are private, authenticate:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

### Insufficient Disk Space

**Symptoms:**
- Setup fails with disk space errors
- Models don't download completely

**Solutions:**
1. Free up space on target drive
2. Use different drive: `-ModelPath "E:\ai-models"`
3. Clean Docker: `wsl docker system prune -a`

### GPU Not Detected

**Symptoms:**
- Benchmarks run but very slow
- No GPU acceleration

**Solutions:**
1. Verify AMD GPU drivers installed:
   - Download from: https://www.amd.com/en/support
2. Check GPU access in WSL2:
   ```bash
   ls /dev/dri
   ls /dev/kfd
   ```
3. Update WSL2: `wsl --update`

## Validation Checklist

After deployment, verify:

- [ ] WSL2 installed and running
- [ ] Docker service running in WSL2
- [ ] All 4 benchmark containers present
- [ ] 2 model files downloaded (~22GB total)
- [ ] `/dev/dri` and `/dev/kfd` devices present
- [ ] Quick test completes successfully
- [ ] Results saved to `results/` directory
- [ ] Can commit and push results to Git

## Performance Expectations

### Light Mode Benchmarks

**GPT-OSS-20B (13GB):**
- Prompt processing: 1000-1500 tokens/sec
- Text generation: 40-60 tokens/sec
- VRAM usage: ~14GB

**Qwen3-8B-128K-Q8 (9GB):**
- Prompt processing: 1500-2000 tokens/sec
- Text generation: 50-70 tokens/sec
- VRAM usage: ~10GB

**System Requirements:**
- 16GB unified RAM minimum
- AMD Strix Halo iGPU with RADV/Vulkan
- DDR5-5600 memory

## Next Steps After Deployment

1. **Run full light benchmark suite:**
   ```bash
   cd /mnt/c/vtt-hw-benchmarks/docker
   MODEL_CONFIG_MODE=light ./run-ai-models.sh
   ```

2. **Compare results across HP laptops:**
   - Analyze silicon lottery variance
   - Document performance differences
   - Assign laptops based on performance

3. **Run additional benchmarks:**
   ```bash
   # CPU, memory, storage benchmarks
   ./run-all.sh
   ```

4. **Deploy to remaining HP laptops:**
   - Use this procedure for all 4 units
   - Compare results in MLflow dashboard (Phase 2)

## Bulk Deployment Notes

For deploying to multiple HP laptops:

1. **Prepare USB drive with models:**
   - Copy downloaded models to USB
   - Saves bandwidth and time

2. **Use non-interactive mode:**
   ```powershell
   .\Setup-HP-ZBook-Automated.ps1 -NonInteractive -SkipModels
   # Then copy models from USB
   ```

3. **Create deployment checklist:**
   - Laptop serial number
   - Deployment date/time
   - Benchmark results
   - Any issues encountered

4. **Track in spreadsheet:**
   - HP ZBook #1-4
   - Performance metrics
   - Hardware assignments

## Support and Resources

### Documentation
- [README.md](../../README.md) - Main documentation
- [WINDOWS-SETUP.md](WINDOWS-SETUP.md) - Windows setup details
- [WINDOWS-VM-TESTING.md](WINDOWS-VM-TESTING.md) - VM testing guide
- [CONFIGURATION.md](CONFIGURATION.md) - Model configuration

### Scripts
- `Setup-HP-ZBook-Automated.ps1` - Main setup script
- `Download-Light-Models.ps1` - Model download helper
- `Test-Windows-Setup.ps1` - Validation script
- `Test-Windows-Short.ps1` - Quick validation

### Container Registry
- GHCR: https://github.com/orgs/vvautosports/packages
- Images: `vtt-benchmark-{7zip,stream,storage,llama}`

### Model Sources
- GPT-OSS-20B: https://huggingface.co/unsloth/gpt-oss-20b-F16-GGUF
- Qwen3-8B-128K: https://huggingface.co/unsloth/Qwen3-8B-128K-GGUF

## Appendix: Manual Setup Steps

If automated setup fails, follow these manual steps:

### 1. Install WSL2
```powershell
wsl --install
# Restart
wsl --set-default-version 2
```

### 2. Install Docker
```bash
# In WSL2
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo service docker start
```

### 3. Download Models
Visit HuggingFace and download manually:
- [gpt-oss-20b-F16.gguf](https://huggingface.co/unsloth/gpt-oss-20b-F16-GGUF/resolve/main/gpt-oss-20b-F16.gguf)
- [qwen3-8b-128k-q8_0.gguf](https://huggingface.co/unsloth/Qwen3-8B-128K-GGUF/resolve/main/qwen3-8b-128k-q8_0.gguf)

### 4. Pull Containers
```bash
# In WSL2
cd /mnt/c/vtt-hw-benchmarks
./scripts/ci-cd/pull-from-ghcr.sh
```

### 5. Run Tests
```bash
cd docker
MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test
```

---

**Last Updated:** 2026-01-24
**Version:** 1.0
**Maintainer:** VTT Infrastructure Team
