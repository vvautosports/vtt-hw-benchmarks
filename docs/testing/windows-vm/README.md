# Windows VM Testing Guide

Complete guide for testing Windows setup in a virtual machine before deploying to physical HP ZBooks.

## Quick Start

### 1. Create VM

```bash
cd /path/to/vtt-hw-benchmarks
sudo bash scripts/setup/create-windows-vm.sh /path/to/Win11.iso
```

### 2. Connect and Install Windows

```bash
virt-viewer windows11-vtt-test
```

Follow Windows installation wizard (or use autounattend.xml for automated install).

### 3. Setup and Test in VM

In Windows VM (PowerShell as Administrator):

```powershell
# Authenticate and clone
winget install --id GitHub.cli
gh auth login
gh repo clone vvautosports/vtt-hw-benchmarks; cd vtt-hw-benchmarks

# Run interactive setup
.\HP-ZBOOK-SETUP-INTERACTIVE.ps1
```

## VM Management

### Create VM
```bash
sudo bash scripts/setup/create-windows-vm.sh /path/to/Win11.iso
```

### Connect to VM
```bash
virt-viewer windows11-vtt-test
# or
virt-manager
```

### Check VM Status
```bash
bash scripts/setup/check-vm-ready.sh
```

### Cleanup VM
```bash
sudo bash scripts/setup/cleanup-vm.sh
```

## Monitoring

Monitor VM resources during testing:

```bash
# Watch stats
watch -n 1 'virsh domstats windows11-vtt-test | grep -E "(cpu\.|balloon\.)"'

# Or use GUI
virt-manager
```

## Troubleshooting

See `docs/guides/WINDOWS-VM-TESTING.md` for detailed troubleshooting.

## Files

- `scripts/setup/create-windows-vm.sh` - VM creation
- `scripts/setup/check-vm-ready.sh` - Status checker
- `scripts/setup/cleanup-vm.sh` - VM cleanup
- `scripts/setup/autounattend.xml` - Automated Windows install (optional)
