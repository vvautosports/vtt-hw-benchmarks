#!/bin/bash
# Deploy Keras OCR service in Proxmox LXC container on MS-01
#
# Usage: ./scripts/deploy-keras-ocr-lxc.sh [PROXMOX_HOST] [CONTAINER_ID]
#
# This script creates an LXC container on MS-01 Proxmox and deploys
# the Keras OCR service for MarkBench Rocket League testing.

set -e

# Configuration
PROXMOX_HOST="${1:-pve-02.kaloud9.xyz}"
CONTAINER_ID="${2:-201}"
CONTAINER_NAME="keras-ocr"
TEMPLATE="ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
STORAGE="local-lvm"
MEMORY="4096"
CORES="2"
DISK_SIZE="16"
BRIDGE="vmbr0"

echo "=== Keras OCR LXC Deployment ==="
echo ""
echo "Proxmox Host: $PROXMOX_HOST"
echo "Container ID: $CONTAINER_ID"
echo "Container Name: $CONTAINER_NAME"
echo ""

# Check if we can SSH to Proxmox
echo "Testing SSH connection to Proxmox..."
if ! ssh -o ConnectTimeout=5 root@$PROXMOX_HOST "echo 'Connected'" &>/dev/null; then
    echo "❌ Cannot connect to Proxmox host: $PROXMOX_HOST"
    echo ""
    echo "Ensure:"
    echo "  1. SSH key is configured for root@$PROXMOX_HOST"
    echo "  2. Host is reachable (try: ssh root@$PROXMOX_HOST)"
    echo "  3. Or use Headscale IP if on mesh VPN"
    exit 1
fi
echo "✅ Connected to Proxmox"
echo ""

# Check if container ID already exists
echo "Checking if container $CONTAINER_ID already exists..."
if ssh root@$PROXMOX_HOST "pct status $CONTAINER_ID" &>/dev/null; then
    echo "⚠️  Container $CONTAINER_ID already exists"
    echo ""
    read -p "Delete existing container and recreate? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Stopping and removing container $CONTAINER_ID..."
        ssh root@$PROXMOX_HOST "pct stop $CONTAINER_ID || true"
        ssh root@$PROXMOX_HOST "pct destroy $CONTAINER_ID"
        echo "✅ Removed existing container"
    else
        echo "Aborting deployment"
        exit 0
    fi
fi
echo ""

# Check if template exists
echo "Checking for Ubuntu 24.04 template..."
if ! ssh root@$PROXMOX_HOST "ls /var/lib/vz/template/cache/$TEMPLATE" &>/dev/null; then
    echo "Template not found. Downloading..."
    ssh root@$PROXMOX_HOST "pveam update && pveam download local $TEMPLATE"
    echo "✅ Template downloaded"
else
    echo "✅ Template already available"
fi
echo ""

# Create LXC container
echo "Creating LXC container..."
ssh root@$PROXMOX_HOST <<EOF
pct create $CONTAINER_ID local:vztmpl/$TEMPLATE \
  --hostname $CONTAINER_NAME \
  --memory $MEMORY \
  --cores $CORES \
  --rootfs $STORAGE:$DISK_SIZE \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --unprivileged 0 \
  --features nesting=1 \
  --onboot 1 \
  --password vvtbenchmarks
EOF
echo "✅ Container created"
echo ""

# Start container
echo "Starting container..."
ssh root@$PROXMOX_HOST "pct start $CONTAINER_ID"
sleep 10  # Wait for container to fully boot
echo "✅ Container started"
echo ""

# Get container IP
echo "Getting container IP address..."
CONTAINER_IP=$(ssh root@$PROXMOX_HOST "pct exec $CONTAINER_ID -- ip -4 addr show eth0 | grep inet | awk '{print \$2}' | cut -d'/' -f1")
echo "✅ Container IP: $CONTAINER_IP"
echo ""

# Install Docker
echo "Installing Docker in container..."
ssh root@$PROXMOX_HOST <<'EOF'
pct exec 201 -- bash <<'DOCKER_INSTALL'
# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y ca-certificates curl gnupg

# Add Docker GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

echo "Docker installed successfully"
DOCKER_INSTALL
EOF
echo "✅ Docker installed"
echo ""

# Deploy Keras OCR service
echo "Deploying Keras OCR service..."
ssh root@$PROXMOX_HOST <<'EOF'
pct exec 201 -- bash <<'DEPLOY_KERAS'
# Pull image
docker pull ghcr.io/lttlabsoss/markbench-keras-ocr:latest

# Run container
docker run -d \
  --name keras-ocr \
  --restart unless-stopped \
  -p 8080:8080 \
  ghcr.io/lttlabsoss/markbench-keras-ocr:latest

echo "Keras OCR service deployed"
DEPLOY_KERAS
EOF
echo "✅ Keras OCR deployed"
echo ""

# Configure firewall
echo "Configuring firewall..."
ssh root@$PROXMOX_HOST <<'EOF'
pct exec 201 -- bash <<'FIREWALL_CONFIG'
# Install UFW
apt install -y ufw

# Configure rules
ufw allow 22/tcp
ufw allow 8080/tcp
ufw --force enable

echo "Firewall configured"
FIREWALL_CONFIG
EOF
echo "✅ Firewall configured"
echo ""

# Wait for service to start
echo "Waiting for Keras OCR service to start..."
sleep 5
echo ""

# Test service
echo "Testing Keras OCR service..."
if ssh root@$PROXMOX_HOST "pct exec $CONTAINER_ID -- curl -s http://localhost:8080/health" &>/dev/null; then
    echo "✅ Service is responding"
else
    echo "⚠️  Service may not be ready yet (check logs with: ssh root@$PROXMOX_HOST pct exec $CONTAINER_ID -- docker logs keras-ocr)"
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════"
echo "✨ Deployment Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Container Details:"
echo "  ID: $CONTAINER_ID"
echo "  Name: $CONTAINER_NAME"
echo "  IP: $CONTAINER_IP"
echo "  Port: 8080"
echo ""
echo "Service URL: http://$CONTAINER_IP:8080"
echo ""
echo "Test from HP ZBook:"
echo "  curl http://$CONTAINER_IP:8080/health"
echo ""
echo "Or in MarkBench:"
echo "  python rocket_league.py --kerasHost $CONTAINER_IP --kerasPort 8080"
echo ""
echo "Container Management:"
echo "  Start:   ssh root@$PROXMOX_HOST pct start $CONTAINER_ID"
echo "  Stop:    ssh root@$PROXMOX_HOST pct stop $CONTAINER_ID"
echo "  Shell:   ssh root@$PROXMOX_HOST pct enter $CONTAINER_ID"
echo "  Logs:    ssh root@$PROXMOX_HOST pct exec $CONTAINER_ID -- docker logs keras-ocr"
echo ""

# Optional: Install Headscale
echo "Optional: Install Headscale for mesh VPN access?"
echo "This allows access from anywhere on Virtual Velocity network."
echo ""
read -p "Install Headscale client? (yes/no): " install_headscale

if [ "$install_headscale" = "yes" ]; then
    echo ""
    echo "Installing Headscale client..."
    ssh root@$PROXMOX_HOST <<'EOF'
pct exec 201 -- bash <<'HEADSCALE_INSTALL'
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to Headscale (manual step required)
echo ""
echo "Run this command to connect to Headscale:"
echo "  tailscale up --login-server=https://headscale.vvautosports.com"
echo ""
echo "Then approve the node on the Headscale server."
HEADSCALE_INSTALL
EOF

    echo ""
    echo "Headscale client installed."
    echo "To complete setup:"
    echo "  1. SSH into container: ssh root@$PROXMOX_HOST pct enter $CONTAINER_ID"
    echo "  2. Run: tailscale up --login-server=https://headscale.vvautosports.com"
    echo "  3. Approve node on Headscale server"
    echo "  4. Get Headscale IP: tailscale ip -4"
fi

echo ""
echo "✨ Done!"
