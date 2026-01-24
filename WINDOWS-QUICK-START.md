# Windows Quick Start - Fresh Install

Complete interactive setup from a fresh Windows install to running all benchmarks.

## One-Command Setup

**Run as Administrator:**

```powershell
cd C:\repos\vtt-hw-benchmarks
.\scripts\utils\setup-windows-full.ps1
```

## What It Does

The script automatically:

1. **Checks prerequisites** - WSL2, Docker, models, containers
2. **Installs WSL2** - If missing (requires restart)
3. **Installs Docker** - In WSL2 automatically
4. **Configures models** - Sets up model directory paths
5. **Pulls containers** - From GHCR or builds locally
6. **Runs benchmarks** - Full suite interactively (optional)

## Options

```powershell
# Check status only (no installation)
.\scripts\utils\setup-windows-full.ps1 -CheckOnly

# Skip running tests after setup
.\scripts\utils\setup-windows-full.ps1 -SkipTests

# Specify custom model directory
.\scripts\utils\setup-windows-full.ps1 -ModelPath "E:\models"
```

## Manual Steps (if needed)

If the automated script doesn't work, follow these steps:

### 1. Install WSL2
```powershell
wsl --install
# Restart when prompted
```

### 2. Install Docker in WSL2
```bash
# In WSL2 terminal
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo service docker start
```

### 3. Pull Containers
```bash
# In WSL2 terminal
cd /mnt/c/repos/vtt-hw-benchmarks
./scripts/ci-cd/pull-from-ghcr.sh
```

### 4. Run Benchmarks
```bash
cd docker
./run-all.sh                                    # All non-AI benchmarks
MODEL_CONFIG_MODE=default ./run-ai-models.sh   # AI model benchmarks
```

## Troubleshooting

**WSL2 installation fails:**
- Ensure Windows 10 1903+ or Windows 11
- Run `wsl --update` manually
- Check Windows Features: Enable "Virtual Machine Platform" and "Windows Subsystem for Linux"

**Docker not working in WSL2:**
```bash
# In WSL2
sudo service docker start
wsl --shutdown  # Restart WSL2
```

**Models not found:**
- Ensure models are in `D:\ai-models` (or your specified path)
- Verify in WSL2: `ls /mnt/d/ai-models`

**Containers not found:**
- Pull from GHCR: `./scripts/ci-cd/pull-from-ghcr.sh`
- Or build locally: `cd docker && ./build-all.sh`

## Next Steps

After setup completes:
- Results saved to `results/` directory
- View logs: `results/benchmark-*.log`
- View JSON: `results/benchmark-*.json`

For detailed documentation, see `docs/guides/WINDOWS-SETUP.md`
