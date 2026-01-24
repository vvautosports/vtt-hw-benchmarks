#!/bin/bash
# Create Windows 11 VM for benchmark testing
# Usage: sudo bash create-windows-vm.sh [ISO_PATH]

set -euo pipefail

VM_NAME="windows11-vtt-test"
VM_RAM=49152  # 48GB
VM_CPUS=8
VM_DISK_SIZE=80
VM_DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"

if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: This script must be run with sudo"
  exit 1
fi

# Get ISO path
if [ -n "$1" ]; then
  ISO_PATH="$1"
else
  echo "Windows 11 ISO path required"
  echo "Usage: sudo bash create-windows-vm.sh /path/to/Win11.iso"
  echo ""
  echo "Download from: https://www.microsoft.com/en-us/software-download/windows11"
  exit 1
fi

if [ ! -f "$ISO_PATH" ]; then
  echo "ERROR: ISO file not found: $ISO_PATH"
  exit 1
fi

# Check/create default network
echo "Checking libvirt network..."
if ! virsh net-list --all --name | grep -q "^default$"; then
  echo "Creating default libvirt network..."
  if [ -f /usr/share/libvirt/networks/default.xml ]; then
    virsh net-define /usr/share/libvirt/networks/default.xml 2>/dev/null || \
      virsh net-create /usr/share/libvirt/networks/default.xml 2>/dev/null
  else
    # Create default network XML inline
    cat > /tmp/default-network.xml << 'EOF'
<network>
  <name>default</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    virsh net-define /tmp/default-network.xml
    rm /tmp/default-network.xml
  fi
fi

if virsh net-list --all --name | grep -q "^default$"; then
  NET_STATE=$(virsh net-info default 2>/dev/null | grep 'Active:' | awk '{print $2}' || echo "no")
  if [ "$NET_STATE" != "yes" ]; then
    echo "Starting default network..."
    virsh net-start default
    virsh net-autostart default
  fi
  NETWORK_ARG="network=default"
else
  echo "WARNING: Default network not available, trying bridge=virbr0..."
  NETWORK_ARG="bridge=virbr0"
fi

# Copy ISO to libvirt images directory so qemu user can access it
ISO_FILENAME=$(basename "$ISO_PATH")
LIBVIRT_ISO="/var/lib/libvirt/images/$ISO_FILENAME"

if [ ! -f "$LIBVIRT_ISO" ] || [ "$ISO_PATH" != "$LIBVIRT_ISO" ]; then
  echo "Copying ISO to libvirt directory (for qemu user access)..."
  cp "$ISO_PATH" "$LIBVIRT_ISO"
  chmod 644 "$LIBVIRT_ISO"
  echo "ISO copied to: $LIBVIRT_ISO"
  USE_ISO="$LIBVIRT_ISO"
else
  USE_ISO="$ISO_PATH"
fi

# Create ISO with autounattend.xml for unattended installation
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUTOUNATTEND_XML="$SCRIPT_DIR/autounattend.xml"
AUTOUNATTEND_ISO="/var/lib/libvirt/images/${VM_NAME}-autounattend.iso"

if [ -f "$AUTOUNATTEND_XML" ]; then
  echo "Creating ISO with autounattend.xml for unattended installation..."
  genisoimage -o "$AUTOUNATTEND_ISO" -J -r "$AUTOUNATTEND_XML" 2>/dev/null
  if [ -f "$AUTOUNATTEND_ISO" ]; then
    FLOPPY_ARG="--disk path=$AUTOUNATTEND_ISO,device=cdrom"
    echo "Unattended installation enabled"
  else
    echo "Warning: Could not create autounattend ISO, installation will be manual"
    FLOPPY_ARG=""
  fi
else
  echo "Warning: autounattend.xml not found at $AUTOUNATTEND_XML"
  echo "Installation will require manual interaction"
  FLOPPY_ARG=""
fi

echo ""
echo "Creating Windows 11 VM: $VM_NAME"
echo "  RAM: ${VM_RAM}MB (48GB)"
echo "  CPUs: $VM_CPUS"
echo "  Disk: ${VM_DISK_SIZE}GB at $VM_DISK_PATH"
echo "  ISO: $USE_ISO"
[ -n "$FLOPPY_ARG" ] && echo "  Unattended install: Enabled (autounattend.xml)"
echo ""

virt-install \
  --name "$VM_NAME" \
  --ram $VM_RAM \
  --vcpus $VM_CPUS \
  --disk path="$VM_DISK_PATH",size=$VM_DISK_SIZE \
  --cdrom "$USE_ISO" \
  $FLOPPY_ARG \
  --os-variant win11 \
  --network $NETWORK_ARG \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole \
  --cpu host-passthrough

echo ""
echo "VM created successfully!"
echo ""
echo "To view the VM:"
echo "  1. Open virt-manager: virt-manager"
echo "  2. Or connect with: virt-viewer $VM_NAME"
echo "  3. Or find VNC port: virsh vncdisplay $VM_NAME"
echo ""
