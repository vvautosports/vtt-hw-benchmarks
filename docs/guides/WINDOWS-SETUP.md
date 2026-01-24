# Windows Setup Guide

Two options: **WSL2 (Recommended)** for 1:1 Linux parity, or **Docker Desktop**.

## Option 1: WSL2 (Recommended)

### Install WSL2

```powershell
# Run as Administrator
wsl --install
# Restart when prompted
```

### Install Docker in WSL2

```bash
# In WSL2 terminal (Ubuntu)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo service docker start
```

### Configure Model Directory

Models on Windows D:\ are accessible at `/mnt/d/` in WSL2:

```bash
# Verify models are accessible
ls /mnt/d/ai-models

# Set environment variable
export MODEL_DIR=/mnt/d/ai-models
echo 'export MODEL_DIR=/mnt/d/ai-models' >> ~/.bashrc
```

### Run Tests

Same commands as Linux:

```bash
cd /mnt/c/repos/vtt-hw-benchmarks/docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

## Option 2: Docker Desktop

### Install

1. Download from [docker.com](https://www.docker.com/products/docker-desktop)
2. Enable "Use WSL2 based engine" in settings
3. Enable drive sharing for D:\ in settings

### Run Tests

```powershell
# In PowerShell
cd C:\repos\vtt-hw-benchmarks\docker
$env:MODEL_DIR="D:/ai-models"
$env:MODEL_CONFIG_MODE="default"
bash ./run-ai-models.sh
```

**Note:** Use forward slashes in paths: `D:/ai-models`

## GPU Access in WSL2

AMD GPU passthrough to WSL2 requires:
- Windows 11 or Windows 10 21H2+
- Latest AMD drivers
- GPU-P (GPU Paravirtualization) enabled

Verify GPU access:
```bash
ls -l /dev/dri /dev/kfd  # Should show device files
```

## Troubleshooting

**WSL2 not found:**
- Ensure Windows version supports WSL2 (Win 10 1903+ or Win 11)
- Run `wsl --update`

**Models not accessible:**
```bash
# WSL2 auto-mounts Windows drives at /mnt/
ls /mnt/c  # C:\
ls /mnt/d  # D:\
```

**Docker Desktop can't see models:**
- Verify drive sharing is enabled in Docker Desktop settings
- Use forward slashes: `D:/ai-models` not `D:\ai-models`

**Performance slower than Linux:**
- File I/O across WSL/Windows boundary is slow
- Consider moving models to WSL2 filesystem: `/home/user/ai-models`
