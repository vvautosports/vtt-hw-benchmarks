#!/bin/bash
# Setup VM Monitoring Tools for Windows VM Testing
# Run with: sudo bash setup-vm-monitoring.sh

set -e

if [ "$EUID" -ne 0 ]; then 
  echo "ERROR: This script must be run with sudo"
  exit 1
fi

echo "Installing virt-manager and related tools..."
dnf install -y virt-manager virt-viewer libvirt virt-install

echo "Starting libvirt service..."
systemctl enable --now libvirtd

USER=$(logname 2>/dev/null || echo $SUDO_USER || echo $USER)
if [ -n "$USER" ]; then
  usermod -aG libvirt "$USER"
fi

echo "Setup complete. Log out and back in, then run: virt-manager"
