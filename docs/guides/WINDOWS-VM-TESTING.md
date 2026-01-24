# Windows VM Testing Guide

Test Windows setup scripts in a virtual machine before deploying to physical Windows machines.

## Overview

This guide covers setting up a Windows VM to test the `setup-windows-full.ps1` script and validate the complete Windows setup process.

## Options

### Option 1: QEMU/KVM (Recommended for Linux Hosts)

**Pros:**
- Native performance with KVM
- Full hardware virtualization
- Works on Linux hosts
- Free and open source

**Cons:**
- Requires Windows ISO/license
- More setup complexity

### Option 2: VirtualBox

**Pros:**
- Cross-platform (Windows, Linux, macOS)
- Easy GUI management
- Good documentation

**Cons:**
- Slightly slower than KVM
- Requires VirtualBox installation

### Option 3: VMware Workstation/Player

**Pros:**
- Excellent performance
- Great Windows support
- Professional tools

**Cons:**
- Commercial license (Workstation)
- Player is free but limited

### Option 4: Windows Containers (Not Recommended)

**Why not:** Windows containers require Windows host OS and don't support WSL2 installation, which is required for our setup.

## Quick Start: QEMU/KVM Setup

### Prerequisites

```bash
# Install QEMU and virt-manager
sudo dnf install -y qemu-kvm libvirt virt-install virt-manager

# Start libvirt service
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Add user to libvirt group
sudo usermod -aG libvirt $USER
# Log out and back in for group to take effect
```

### Create Windows VM

#### Step 1: Download Windows ISO

Download Windows 11 evaluation ISO from Microsoft:
- https://www.microsoft.com/en-us/software-download/windows11
- Or use Windows 10: https://www.microsoft.com/en-us/software-download/windows10

#### Step 2: Create VM with virt-install

```bash
# Create Windows 11 VM
sudo virt-install \
  --name windows11-test \
  --ram 8192 \
  --vcpus 4 \
  --disk path=/var/lib/libvirt/images/windows11-test.qcow2,size=60 \
  --cdrom /path/to/Win11_23H2_English_x64.iso \
  --os-variant win11 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# Or use virt-manager GUI
virt-manager
```

#### Step 3: Connect to VM

```bash
# Find VNC port
sudo virsh vncdisplay windows11-test

# Connect with VNC viewer
# Or use virt-viewer
virt-viewer windows11-test
```

#### Step 4: Install Windows

1. Follow Windows installation wizard
2. Create local user account (no Microsoft account needed for testing)
3. Complete initial setup

#### Step 5: Install Guest Tools (Optional)

For better performance and clipboard sharing:

```bash
# Install SPICE guest tools in Windows VM
# Download from: https://www.spice-space.org/download.html
# Or use virtio drivers
```

### Test Setup Script

#### Step 1: Clone Repository in VM

```powershell
# In Windows VM PowerShell
cd C:\
git clone https://github.com/vvautosports/vtt-hw-benchmarks.git
cd vtt-hw-benchmarks
```

#### Step 2: Run Setup Script

```powershell
# Run as Administrator
.\scripts\utils\setup-windows-full.ps1
```

#### Step 3: Verify Results

```powershell
# Check WSL2
wsl --status

# Check Docker
wsl bash -c "docker --version"

# Check containers
wsl bash -c "docker images | grep vtt-benchmark"

# Run quick test
wsl bash -c "cd /mnt/c/vtt-hw-benchmarks/docker && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test"
```

## Automated Testing Script

Create a test script to automate validation:

```powershell
# scripts/testing/Test-Windows-Setup.ps1
param(
    [switch]$FullTest
)

Write-Host "=== Windows Setup Test Suite ===" -ForegroundColor Cyan

# Test 1: WSL2 Installation
Write-Host "Test 1: WSL2 Status..." -ForegroundColor Yellow
$wslStatus = wsl --status 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[PASS] WSL2 installed" -ForegroundColor Green
} else {
    Write-Host "[FAIL] WSL2 not installed" -ForegroundColor Red
    exit 1
}

# Test 2: Docker in WSL2
Write-Host "Test 2: Docker in WSL2..." -ForegroundColor Yellow
$dockerVersion = wsl bash -c "docker --version" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "[PASS] Docker installed: $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Docker not installed" -ForegroundColor Red
    exit 1
}

# Test 3: Containers Available
Write-Host "Test 3: Benchmark Containers..." -ForegroundColor Yellow
$containers = wsl bash -c "docker images | grep vtt-benchmark" 2>&1
if ($containers -match "vtt-benchmark") {
    Write-Host "[PASS] Containers available" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Containers not found" -ForegroundColor Red
    exit 1
}

# Test 4: Quick Benchmark (if FullTest)
if ($FullTest) {
    Write-Host "Test 4: Running Quick Benchmark..." -ForegroundColor Yellow
    wsl bash -c "cd /mnt/c/vtt-hw-benchmarks/docker && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[PASS] Quick benchmark completed" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Quick benchmark failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== All Tests Passed ===" -ForegroundColor Green
```

## VirtualBox Alternative

If you prefer VirtualBox:

### Install VirtualBox

```bash
# Fedora
sudo dnf install -y VirtualBox

# Ubuntu/Debian
sudo apt install -y virtualbox
```

### Create VM

1. Open VirtualBox
2. New → Name: "Windows11-Test"
3. Memory: 8GB
4. Hard disk: 60GB, dynamically allocated
5. Settings → Storage → Add Windows ISO
6. Settings → Network → Bridged Adapter
7. Start VM and install Windows

### Test Setup

Same as QEMU/KVM steps above.

## Cloud Testing Options

### GitHub Actions (Limited)

GitHub Actions supports Windows runners, but:
- Limited to 2 hours runtime
- No WSL2 support in GitHub-hosted runners
- Would need self-hosted Windows runner

### Azure DevTest Labs

- Free tier available
- Windows VMs on-demand
- Good for CI/CD testing

### AWS EC2 Windows Instances

- Pay-per-use
- Windows Server or Windows 10/11
- Can automate with Terraform

## Testing Checklist

After VM setup, verify:

- [ ] Windows installed and updated
- [ ] PowerShell execution policy allows scripts
- [ ] Git installed (for cloning repo)
- [ ] Network connectivity
- [ ] Sufficient disk space (60GB+)
- [ ] VM has 8GB+ RAM allocated
- [ ] Can access shared folders (if using)

## Troubleshooting

### WSL2 Installation Fails in VM

**Issue:** WSL2 requires nested virtualization

**Solution:**
```bash
# Enable nested virtualization in KVM
echo 'options kvm_intel nested=1' | sudo tee /etc/modprobe.d/kvm.conf
# Or for AMD:
echo 'options kvm_amd nested=1' | sudo tee /etc/modprobe.d/kvm.conf

# Reboot host
sudo reboot
```

### Docker Not Starting in WSL2

**Issue:** Docker service not running

**Solution:**
```bash
# In WSL2
sudo service docker start
sudo systemctl enable docker  # If systemd available
```

### Performance Issues

**Solutions:**
- Allocate more CPU cores to VM
- Enable CPU passthrough features
- Use virtio drivers for disk/network
- Allocate more RAM

## Next Steps

1. **Test setup script** in VM
2. **Document any issues** found
3. **Update setup script** based on findings
4. **Create automated test suite**
5. **Deploy to physical Windows machines**

## References

- [QEMU Documentation](https://www.qemu.org/documentation/)
- [libvirt Documentation](https://libvirt.org/docs.html)
- [VirtualBox Manual](https://www.virtualbox.org/manual/)
- [WSL2 Installation Guide](https://learn.microsoft.com/en-us/windows/wsl/install)
