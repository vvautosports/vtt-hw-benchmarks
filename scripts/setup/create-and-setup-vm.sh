#!/bin/bash
# Create Windows VM and provide connection instructions
# Usage: sudo bash create-and-setup-vm.sh

set -e

VM_NAME="windows11-vtt-test"
ISO_PATH="/home/kalman9/Downloads/Win11_25H2_English_x64.iso"

if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: This script must be run with sudo"
  echo "Usage: sudo bash $0"
  exit 1
fi

# Check if VM already exists
if virsh list --all --name | grep -q "^${VM_NAME}$"; then
  echo "VM '$VM_NAME' already exists!"
  echo ""
  echo "Current status:"
  virsh dominfo "$VM_NAME" | head -5
  echo ""
  echo "To connect:"
  echo "  virt-viewer $VM_NAME"
  echo "  or"
  echo "  virt-manager"
  exit 0
fi

# Verify ISO exists
if [ ! -f "$ISO_PATH" ]; then
  echo "ERROR: ISO file not found: $ISO_PATH"
  exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "  Creating Windows 11 VM"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "VM Name: $VM_NAME"
echo "RAM: 48GB (49152 MB)"
echo "CPUs: 8"
echo "Disk: 80GB"
echo "ISO: $ISO_PATH"
echo ""

# Start libvirt if not running
if ! systemctl is-active --quiet libvirtd; then
  echo "Starting libvirt service..."
  systemctl start libvirtd
fi

# Create the VM
echo "Creating VM (this may take a minute)..."
virt-install \
  --name "$VM_NAME" \
  --ram 49152 \
  --vcpus 8 \
  --disk path="/var/lib/libvirt/images/${VM_NAME}.qcow2",size=80 \
  --cdrom "$ISO_PATH" \
  --os-variant win11 \
  --network bridge=virbr0 \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --cpu host-passthrough

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VM Created Successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Get VNC port
VNC_PORT=$(virsh vncdisplay "$VM_NAME" 2>/dev/null | cut -d: -f2)
if [ -n "$VNC_PORT" ]; then
  VNC_NUM=$((VNC_PORT - 5900))
  echo "VNC Connection:"
  echo "  Port: $VNC_PORT (display :$VNC_NUM)"
  echo "  Connect to: localhost:$VNC_PORT"
  echo ""
fi

echo "To connect to the VM:"
echo ""
echo "  Option 1 (Recommended):"
echo "    virt-viewer $VM_NAME"
echo ""
echo "  Option 2 (GUI Manager):"
echo "    virt-manager"
echo "    Then double-click '$VM_NAME' in the list"
echo ""
echo "  Option 3 (VNC Client):"
if [ -n "$VNC_PORT" ]; then
  echo "    Connect to: localhost:$VNC_PORT"
else
  echo "    Find port with: virsh vncdisplay $VM_NAME"
fi
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Next Steps:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1. Connect to VM using one of the methods above"
echo "2. Follow Windows 11 installation wizard"
echo "3. Create local user account (no Microsoft account needed)"
echo "4. Complete initial Windows setup"
echo "5. Once Windows is ready, clone the repo and run the lite test:"
echo ""
echo "   In Windows VM (PowerShell as Admin):"
echo "   git clone https://github.com/vvautosports/vtt-hw-benchmarks.git"
echo "   cd vtt-hw-benchmarks"
echo "   .\\scripts\\utils\\Setup-HP-ZBook-Automated.ps1"
echo "   .\\scripts\\testing\\Test-Windows-Short.ps1"
echo ""
echo "═══════════════════════════════════════════════════════════════"
