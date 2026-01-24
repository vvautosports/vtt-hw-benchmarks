#!/bin/bash
# Check if Windows VM is ready for testing
# Usage: bash check-vm-ready.sh

VM_NAME="windows11-vtt-test"

echo "═══════════════════════════════════════════════════════════════"
echo "  Windows VM Readiness Check"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if VM exists
if ! virsh list --all --name | grep -q "^${VM_NAME}$"; then
  echo "❌ VM '$VM_NAME' does not exist"
  echo ""
  echo "Create it with:"
  echo "  sudo bash scripts/setup/create-and-setup-vm.sh"
  exit 1
fi

echo "✅ VM exists: $VM_NAME"
echo ""

# Get VM status
VM_STATE=$(virsh dominfo "$VM_NAME" 2>/dev/null | grep "State:" | awk '{print $2}')
echo "VM State: $VM_STATE"
echo ""

if [ "$VM_STATE" = "running" ]; then
  echo "✅ VM is running"
  echo ""
  
  # Get VNC info
  VNC_DISPLAY=$(virsh vncdisplay "$VM_NAME" 2>/dev/null)
  if [ -n "$VNC_DISPLAY" ]; then
    echo "VNC Display: $VNC_DISPLAY"
    VNC_PORT=$(echo "$VNC_DISPLAY" | cut -d: -f2)
    echo "Connect to: localhost:$VNC_PORT"
    echo ""
  fi
  
  # Get resource stats
  echo "Resource Usage:"
  virsh domstats "$VM_NAME" 2>/dev/null | grep -E "(cpu\.|balloon\.|block\..*\.rd|block\..*\.wr)" | head -10
  echo ""
  
  echo "═══════════════════════════════════════════════════════════════"
  echo "  VM is ready!"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  echo "To connect:"
  echo "  virt-viewer $VM_NAME"
  echo "  or"
  echo "  virt-manager"
  echo ""
  echo "Once Windows is installed and ready, run the lite test:"
  echo "  (In Windows VM PowerShell as Admin)"
  echo "  cd C:\\vtt-hw-benchmarks"
  echo "  .\\scripts\\testing\\Test-Windows-Short.ps1"
  
elif [ "$VM_STATE" = "shut off" ]; then
  echo "⚠️  VM exists but is shut off"
  echo ""
  echo "Start it with:"
  echo "  virsh start $VM_NAME"
  echo ""
  echo "Then connect with:"
  echo "  virt-viewer $VM_NAME"
else
  echo "⚠️  VM state: $VM_STATE"
  echo ""
  echo "Check VM status:"
  echo "  virsh dominfo $VM_NAME"
fi
