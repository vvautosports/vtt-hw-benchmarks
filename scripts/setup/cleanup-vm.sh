#!/bin/bash
# Cleanup Windows VM completely
# Usage: sudo bash cleanup-vm.sh [VM_NAME]

VM_NAME="${1:-windows11-vtt-test}"

if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: This script must be run with sudo"
  exit 1
fi

echo "Cleaning up VM: $VM_NAME"
echo ""

# Destroy if running
virsh destroy "$VM_NAME" 2>/dev/null && echo "VM destroyed" || echo "VM not running"

# Remove NVRAM file if it exists
NVRAM_FILE="/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd"
if [ -f "$NVRAM_FILE" ]; then
  echo "Removing NVRAM file..."
  rm -f "$NVRAM_FILE"
fi

# Undefine with NVRAM removal
virsh undefine "$VM_NAME" --nvram --remove-all-storage 2>/dev/null && echo "VM undefined" || {
  # Try without --remove-all-storage if that fails
  virsh undefine "$VM_NAME" --nvram 2>/dev/null && echo "VM undefined (storage not removed)" || {
    echo "Warning: Could not undefine VM, may need manual cleanup"
  }
}

# Clean up any remaining files
DISK_FILE="/var/lib/libvirt/images/${VM_NAME}.qcow2"
if [ -f "$DISK_FILE" ]; then
  echo "Removing disk file..."
  rm -f "$DISK_FILE"
fi

AUTOUNATTEND_ISO="/var/lib/libvirt/images/${VM_NAME}-autounattend.iso"
if [ -f "$AUTOUNATTEND_ISO" ]; then
  echo "Removing autounattend ISO..."
  rm -f "$AUTOUNATTEND_ISO"
fi

echo ""
echo "Cleanup complete!"
