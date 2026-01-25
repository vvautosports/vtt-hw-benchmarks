# Windows VM Testing Guide

Complete guide for testing Windows setup in a virtual machine on Framework desktop before deploying to physical HP ZBook laptops.

## Overview

This guide covers setting up a Windows 11 VM with nested virtualization to test the complete HP ZBook deployment workflow, including WSL2, Docker, model downloads, and AI benchmarking.

**Purpose:**
- Validate setup scripts before deploying to physical hardware
- Test AI model benchmarking in Windows environment
- Identify and resolve issues in a safe, isolated environment
- Document expected performance (CPU-only in nested VM)

**Expected Time:**
- VM setup: 30-60 minutes
- Windows installation: 20-30 minutes
- Complete setup and testing: 30-45 minutes
- **Total: ~2 hours**

---

## Prerequisites

### Host System (Framework Desktop)

- **OS:** Linux (Fedora recommended)
- **CPU:** AMD Ryzen (supports nested virtualization)
- **RAM:** 48GB+ recommended (VM needs 8GB, host needs overhead)
- **Software:**
  - KVM/QEMU installed
  - virt-manager (GUI) or virt-install (CLI)
  - Windows 11 ISO image

### Verify KVM Support

```bash
# Check if KVM is available
lsmod | grep kvm

# Should show: kvm_amd (or kvm_intel for Intel)
```

---

## Phase 1: Enable Nested Virtualization

Nested virtualization is required for WSL2 to work inside the Windows VM.

### Step 1: Enable on Host

```bash
# For AMD processors
echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf

# For Intel processors (if needed)
# echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf

# Reboot the host system
sudo reboot
```

### Step 2: Verify Nested Virtualization

After reboot:

```bash
# For AMD
cat /sys/module/kvm_amd/parameters/nested
# Should output: 1 or Y

# For Intel
# cat /sys/module/kvm_intel/parameters/nested
# Should output: 1 or Y
```

---

## Phase 2: Create Windows VM

### Using virt-manager (GUI)

1. **Open virt-manager:**
   ```bash
   virt-manager
   ```

2. **Create New VM:**
   - File → New Virtual Machine
   - Select "Local install media (ISO image or CDROM)"
   - Browse to Windows 11 ISO
   - Memory: **8192 MB** (8GB)
   - CPUs: **4**
   - Disk: **60 GB** (minimum, 80GB recommended)

3. **Configure VM Settings:**
   - Before finishing, check "Customize configuration before install"
   - In CPU settings:
     - Enable "Copy host CPU configuration"
     - **Enable nested virtualization** (if option available)
   - In Features:
     - Enable "Hyper-V enlightenments" (helps Windows detect it's in a VM)

4. **Start Installation:**
   - Click "Begin Installation"
   - Follow Windows 11 installation wizard

### Using virt-install (CLI)

```bash
virt-install \
  --name windows11-vm \
  --ram 8192 \
  --vcpus 4 \
  --disk path=/var/lib/libvirt/images/windows11-vm.qcow2,size=60 \
  --cdrom /path/to/windows11.iso \
  --os-variant win11 \
  --network network=default \
  --graphics vnc \
  --cpu host-passthrough \
  --features hyperv_relaxed=on,hyperv_vapic=on,hyperv_spinlocks=on
```

**Note:** The `--cpu host-passthrough` enables nested virtualization.

---

## Phase 3: Install Windows 11

1. **Complete Windows Installation:**
   - Follow standard Windows 11 setup
   - Create local account (or Microsoft account)
   - Complete initial configuration

2. **Install VirtIO Drivers (if needed):**
   - Download from: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/
   - Install in VM for better performance

3. **Update Windows:**
   - Run Windows Update
   - Install all available updates
   - Reboot if needed

---

## Phase 4: Clone Repository in VM

1. **Install Prerequisites:**
   ```powershell
   # Install Git for Windows
   winget install --id Git.Git

   # Install GitHub CLI
   winget install --id GitHub.cli
   ```

2. **Authenticate GitHub:**
   ```powershell
   gh auth login
   # Follow browser prompts
   ```

3. **Clone Repository:**
   ```powershell
   cd C:\
   gh repo clone vvautosports/vtt-hw-benchmarks
   cd vtt-hw-benchmarks
   ```

---

## Phase 5: Run Setup Script

**Recommended: Use SETUP.bat (Docker Desktop approach)**

```powershell
# Right-click and Run as Administrator
scripts\setup\hp-zbook\SETUP.bat
```

**What SETUP.bat does:**
- Checks prerequisites (GitHub CLI, Docker Desktop, repository)
- Installs missing components automatically
- Provides interactive menu with:
  - Pull benchmark containers
  - **Run validation test** (calls Test-Windows-Short.ps1)
  - Run quick benchmark (2-3 min)
  - Run default benchmark (30-45 min)
  - Run comprehensive benchmark (2-3 hrs)

**Alternative: WSL2 Direct Setup**

If you prefer WSL2 direct (without Docker Desktop):

```powershell
# Run as Administrator
powershell -ExecutionPolicy Bypass -File .\scripts\utils\setup-windows-full.ps1 -ModelPath "D:\ai-models"
```

**What it does:**
- Installs WSL2 (requires restart)
- Installs Docker in WSL2
- Configures model directory
- Pulls/builds containers

---

## Phase 6: Download Light Models

```powershell
# Run as Administrator
.\scripts\utils\Download-Light-Models.ps1 -ModelPath "D:\ai-models"
```

**Expected:**
- Downloads GPT-OSS-20B (13GB)
- Downloads Qwen3-8B-128K-Q8 (9GB)
- Total: ~22GB
- Time: 15-30 minutes (depending on connection)

---

## Phase 7: Test AI Models

### Using SETUP.bat Menu (Recommended)

The `SETUP.bat` script has built-in testing:

1. **Run validation test:**
   - Select option 2: "Run validation test"
   - This runs `Test-Windows-Short.ps1` which validates setup and runs a quick benchmark

2. **Run quick benchmark:**
   - Select option 3: "Run quick benchmark (2-3 min)"
   - Tests default models with quick settings

### Manual Testing (Alternative)

```powershell
# Quick validation
.\scripts\testing\Test-Windows-Short.ps1

# Or manually in WSL2
wsl
cd /mnt/c/vtt-hw-benchmarks/docker
MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test
```

**Expected Results:**
- Test completes successfully
- Results saved to `results/` directory
- Performance will be **much slower** than native (CPU-only, 5-10x slower)
- This is **expected** in a nested VM

---

## Known Limitations

### GPU Acceleration

**GPU passthrough does NOT work in nested VMs.**

- AI models will run on CPU only
- Performance will be 5-10x slower than native
- This is expected and acceptable for testing setup workflow
- For actual performance testing, use physical hardware

### Performance Expectations

**In VM (CPU-only):**
- GPT-OSS-20B: 50-100 tokens/sec (vs 40-60 tokens/sec native with GPU)
- Qwen3-8B-128K-Q8: 60-120 tokens/sec (vs 50-70 tokens/sec native with GPU)
- Quick test: 5-10 minutes (vs 2-3 minutes native)

**Purpose of VM Testing:**
- Validate setup scripts work correctly
- Test model downloads and paths
- Verify Docker containers run
- Confirm results are saved properly
- **NOT for performance benchmarking**

---

## Troubleshooting

### Nested Virtualization Not Working

**Symptoms:**
- WSL2 installation fails
- Error: "Virtual Machine Platform not enabled"
- WSL2 runs but very slowly

**Solutions:**
1. Verify nested virtualization on host:
   ```bash
   cat /sys/module/kvm_amd/parameters/nested
   # Should show: 1 or Y
   ```

2. Check VM CPU settings in virt-manager:
   - CPU should be set to "host-passthrough" or "Copy host CPU"
   - Enable "Hyper-V enlightenments"

3. Verify in Windows VM:
   ```powershell
   systeminfo | findstr /C:"Hyper-V"
   # Should show Hyper-V requirements: Yes
   ```

### WSL2 Installation Fails

**Symptoms:**
- `wsl --install` fails or hangs
- Error about Virtual Machine Platform

**Solutions:**
1. Enable Windows features manually:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```

2. Restart VM

3. Run: `wsl --update`

4. Set WSL2 as default: `wsl --set-default-version 2`

### Docker Not Starting in WSL2

**Symptoms:**
- `docker --version` fails
- Error: "Cannot connect to Docker daemon"

**Solutions:**
```bash
# In WSL2
sudo service docker start

# If still fails, reinstall Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

### Model Path Issues

**Symptoms:**
- Models not found in WSL2
- Path errors in benchmarks

**Solutions:**
1. Verify models are accessible:
   ```bash
   # In WSL2
   ls /mnt/d/ai-models
   # Should show model directories
   ```

2. Check path format:
   - Windows: `D:\ai-models`
   - WSL2: `/mnt/d/ai-models`
   - Use forward slashes in WSL2

3. Set environment variable:
   ```bash
   export MODEL_DIR=/mnt/d/ai-models
   echo 'export MODEL_DIR=/mnt/d/ai-models' >> ~/.bashrc
   ```

### Slow Performance

**This is expected!**

- VM is running CPU-only (no GPU)
- Nested virtualization adds overhead
- 5-10x slower than native is normal
- Focus on verifying setup works, not performance

---

## Validation Checklist

After completing VM setup, verify:

- [ ] Windows 11 installed and updated
- [ ] WSL2 installed and working
- [ ] Docker installed in WSL2 (or Docker Desktop running)
- [ ] Repository cloned successfully
- [ ] Light models downloaded (~22GB in D:\ai-models)
- [ ] Containers pulled from GHCR
- [ ] Quick validation test passes
- [ ] AI benchmark completes (even if slow)
- [ ] Results saved to `results/` directory

---

## Next Steps

After successful VM testing:

1. **Document any issues found:**
   - Update this guide with solutions
   - Fix any script bugs discovered

2. **Deploy to physical HP ZBooks:**
   - Use same procedure as VM
   - Expect better performance (GPU acceleration)
   - See [HP-ZBOOK-DEPLOYMENT.md](../guides/HP-ZBOOK-DEPLOYMENT.md)

3. **Run Linux baseline on Framework:**
   - Compare VM vs native Linux performance
   - See plan for details

---

## Support and Resources

### Documentation
- [HP-ZBOOK-DEPLOYMENT.md](../guides/HP-ZBOOK-DEPLOYMENT.md) - Physical deployment guide
- [WINDOWS-SETUP.md](../guides/WINDOWS-SETUP.md) - Windows setup details
- [DOCUMENTATION-ANALYSIS.md](../DOCUMENTATION-ANALYSIS.md) - Documentation inventory

### Scripts
- `scripts/setup/hp-zbook/SETUP.bat` - **Main setup script** with built-in validation and testing menu
- `scripts/utils/setup-windows-full.ps1` - WSL2 direct setup (alternative)
- `scripts/utils/Download-Light-Models.ps1` - Model download helper
- `scripts/testing/Test-Windows-Short.ps1` - Validation script (called by SETUP.bat)
- `scripts/testing/Test-Windows-Setup.ps1` - Detailed setup validation

---

**Last Updated:** 2026-01-24  
**Version:** 1.0  
**Maintainer:** VTT Infrastructure Team
