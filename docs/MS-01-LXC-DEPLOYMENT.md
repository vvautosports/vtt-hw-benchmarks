# MS-01 LXC Deployment - Keras OCR Service

Deploy Keras OCR service in Proxmox LXC container on MS-01 for MarkBench Rocket League testing.

**Target:** MS-01 Proxmox host (pve-02.kaloud9.xyz / 192.168.7.30)
**Service:** LTT MarkBench Keras OCR
**Access:** Headscale mesh VPN + optional local network
**Container Type:** Privileged LXC with Docker support

---

## Prerequisites

- MS-01 Proxmox accessible via `ssh root@pve-02.kaloud9.xyz` or Headscale IP
- Proxmox credentials configured
- Available container ID (e.g., 201)
- Network access configured (bridge vmbr0 or vmbr1)

---

## Quick Deploy

### Option 1: Automated Deployment Script (Recommended)

```bash
# From vtt-hw-benchmarks repo
./scripts/deploy-keras-ocr-lxc.sh
```

This will:
1. Create Ubuntu 24.04 LXC container
2. Install Docker
3. Deploy Keras OCR service
4. Configure firewall and network
5. Optionally install Headscale client

### Option 2: Manual Deployment

Follow steps below for manual LXC creation and configuration.

---

## Manual Deployment Steps

### Step 1: Create LXC Container on MS-01

**SSH to MS-01 Proxmox:**
```bash
ssh root@pve-02.kaloud9.xyz
# Or via Headscale: ssh root@<ms-01-headscale-ip>
```

**Download Ubuntu 24.04 template (if not already available):**
```bash
pveam update
pveam available | grep ubuntu
pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
```

**Create LXC container:**
```bash
# Container ID: 201 (adjust if needed)
# Storage: local-lvm (or app-storage if using ZFS)
# CPU: 2 cores
# RAM: 4GB
# Disk: 16GB

pct create 201 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname keras-ocr \
  --memory 4096 \
  --cores 2 \
  --rootfs local-lvm:16 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 0 \
  --features nesting=1 \
  --onboot 1 \
  --password <set-password>
```

**Notes:**
- `--unprivileged 0` = Privileged container (required for Docker)
- `--features nesting=1` = Enable Docker support
- `--onboot 1` = Auto-start on Proxmox boot
- `vmbr0` = Default bridge (adjust to vmbr1 if using separate network)

**Start container:**
```bash
pct start 201
```

### Step 2: Configure Container Networking

**Get container IP:**
```bash
pct exec 201 -- ip -4 addr show eth0
```

**Or set static IP (optional):**
```bash
pct set 201 --net0 name=eth0,bridge=vmbr0,ip=192.168.7.201/24,gw=192.168.7.1
pct reboot 201
```

### Step 3: Install Docker in Container

**Enter container:**
```bash
pct enter 201
```

**Update and install Docker:**
```bash
# Update system
apt update && apt upgrade -y

# Install Docker dependencies
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

# Verify Docker installation
docker --version
docker compose version

# Enable Docker service
systemctl enable docker
systemctl start docker
```

### Step 4: Deploy Keras OCR Service

**Still inside container (pct enter 201):**

```bash
# Pull Keras OCR image
docker pull ghcr.io/lttlabsoss/markbench-keras-ocr:latest

# Run Keras OCR service
docker run -d \
  --name keras-ocr \
  --restart unless-stopped \
  -p 8080:8080 \
  ghcr.io/lttlabsoss/markbench-keras-ocr:latest

# Verify service is running
docker ps | grep keras-ocr
```

**Test service locally:**
```bash
curl http://localhost:8080/health
```

Expected response: `{"status": "healthy"}` or similar.

### Step 5: Configure Firewall (if needed)

**Inside container:**
```bash
# Install UFW if not present
apt install -y ufw

# Allow SSH (important!)
ufw allow 22/tcp

# Allow Keras OCR port
ufw allow 8080/tcp

# Enable firewall
ufw --force enable

# Verify rules
ufw status
```

### Step 6: Install Headscale (Optional)

For mesh VPN access from anywhere on Virtual Velocity network:

**Inside container:**
```bash
# Download Headscale client
wget https://github.com/juanfont/headscale/releases/latest/download/headscale_linux_amd64

# Or for ARM (check MS-01 architecture)
# wget https://github.com/juanfont/headscale/releases/latest/download/headscale_linux_arm64

# Make executable and move to PATH
chmod +x headscale_*
mv headscale_* /usr/local/bin/headscale

# Install Tailscale client
curl -fsSL https://tailscale.com/install.sh | sh

# Connect to Headscale server
# (Get auth URL from Headscale admin)
tailscale up --login-server=https://headscale.vvautosports.com
```

**On Headscale server, approve node:**
```bash
headscale nodes list
headscale nodes register --user vtt-benchmarks <node-id>
```

### Step 7: Exit Container and Get IPs

**Exit container:**
```bash
exit  # Back to Proxmox host
```

**Get all network addresses:**
```bash
# Local network IP
pct exec 201 -- ip -4 addr show eth0 | grep inet

# Headscale IP (if installed)
pct exec 201 -- tailscale ip -4
```

---

## Verification

### From MS-01 Proxmox Host

```bash
# Check container status
pct status 201

# Test service via local IP
curl http://<container-local-ip>:8080/health

# Check logs
pct exec 201 -- docker logs keras-ocr
```

### From HP ZBook (Windows)

**Via local network:**
```powershell
# Test connectivity
Test-NetConnection -ComputerName <container-ip> -Port 8080

# Test service
curl http://<container-ip>:8080/health
```

**Via Headscale VPN:**
```powershell
# Get Headscale IP from MS-01
# Then test
curl http://<headscale-ip>:8080/health
```

### From Framework Desktop (Linux)

```bash
# Test service
curl http://<container-ip>:8080/health
# Or via Headscale
curl http://<headscale-ip>:8080/health
```

---

## Container Management

### Start/Stop/Restart

```bash
# From Proxmox host
pct start 201
pct stop 201
pct restart 201
pct status 201
```

### Access Container

```bash
# Interactive shell
pct enter 201

# Execute single command
pct exec 201 -- <command>
```

### View Logs

```bash
# Container system logs
pct exec 201 -- journalctl -xe

# Docker service logs
pct exec 201 -- docker logs keras-ocr
pct exec 201 -- docker logs -f keras-ocr  # Follow
```

### Resource Usage

```bash
# From Proxmox host
pct config 201  # Show config
pct status 201  # Show status

# Inside container
pct exec 201 -- docker stats keras-ocr
```

---

## Network Configuration

### Ports Exposed

| Port | Service | Access |
|------|---------|--------|
| 8080 | Keras OCR HTTP API | Local + Headscale |
| 22 | SSH (LXC) | Proxmox management |

### Firewall Rules

**Proxmox host firewall (optional):**
```bash
# Allow 8080 from anywhere (if using Proxmox firewall)
# Datacenter → Firewall → Add Rule
# Or via CLI on Proxmox host:
# firewall-cmd --permanent --add-port=8080/tcp
# firewall-cmd --reload
```

**Container UFW firewall:**
- Port 22: SSH access
- Port 8080: Keras OCR service

---

## Headscale Integration

### Benefits

- Access from anywhere on Virtual Velocity mesh network
- No port forwarding or public IP required
- End-to-end encrypted VPN mesh
- Access service at `http://<headscale-ip>:8080`

### Configuration

**Container Headscale IP:**
```bash
pct exec 201 -- tailscale ip -4
```

**DNS (optional):**
```bash
# Add to Headscale DNS or local hosts file
keras-ocr.vvautosports.internal  <headscale-ip>
```

**Usage from any VV network device:**
```bash
curl http://<headscale-ip>:8080/health
# Or with DNS:
curl http://keras-ocr.vvautosports.internal:8080/health
```

---

## Troubleshooting

### Container won't start

```bash
# Check Proxmox logs
journalctl -u pve-container@201 -n 50

# Check container config
pct config 201

# Try starting with debug
pct start 201 --debug
```

### Docker not working in container

```bash
# Verify nesting is enabled
pct config 201 | grep features

# Should show: features: nesting=1

# If not, enable it:
pct set 201 --features nesting=1
pct reboot 201
```

### Service not accessible from network

```bash
# Check container firewall
pct exec 201 -- ufw status

# Check if port is listening
pct exec 201 -- ss -tlnp | grep 8080

# Test from Proxmox host
curl http://<container-ip>:8080/health

# Check Proxmox firewall
# Web UI: Datacenter → Firewall
```

### Headscale connection issues

```bash
# Check Tailscale status
pct exec 201 -- tailscale status

# Reconnect
pct exec 201 -- tailscale up --login-server=https://headscale.vvautosports.com

# Check connectivity
pct exec 201 -- tailscale ping <other-node>
```

---

## Backup and Recovery

### Manual Backup

```bash
# From Proxmox host
vzdump 201 --mode snapshot --compress zstd

# Backups stored in: /var/lib/vz/dump/
```

### Restore from Backup

```bash
# List backups
ls -lh /var/lib/vz/dump/vzdump-lxc-201-*

# Restore
pct restore 201 /var/lib/vz/dump/vzdump-lxc-201-<timestamp>.tar.zst --force
```

### Automated Backup (Proxmox)

Configure in Web UI:
1. Datacenter → Backup
2. Add → Schedule
3. Select container 201
4. Configure retention policy

---

## Performance Tuning

### Allocate More Resources (if needed)

```bash
# Increase CPU cores
pct set 201 --cores 4

# Increase RAM
pct set 201 --memory 8192

# Apply changes (requires restart)
pct reboot 201
```

### Monitor Resource Usage

```bash
# Real-time stats
pct exec 201 -- top

# Docker stats
pct exec 201 -- docker stats keras-ocr

# Proxmox web UI: Container → Summary
```

---

## Next Steps

After deployment:

1. ✅ Note container IP addresses (local + Headscale)
2. ✅ Test connectivity from HP ZBook
3. ✅ Update HP-ZBOOK-SETUP.md with actual IP
4. ✅ Run Rocket League benchmark test
5. ⏸️ Configure automated backups (optional)
6. ⏸️ Add monitoring/alerts (optional)

---

## Quick Reference

```bash
# Container management
pct start 201
pct stop 201
pct restart 201
pct enter 201

# Get IP addresses
pct exec 201 -- ip -4 addr show eth0 | grep inet
pct exec 201 -- tailscale ip -4

# Service management
pct exec 201 -- docker ps
pct exec 201 -- docker logs keras-ocr
pct exec 201 -- docker restart keras-ocr

# Test service
curl http://<ip>:8080/health
```

---

## Integration with VTT Benchmarks

**From HP ZBooks:**
```powershell
# In markbench config or command line
python rocket_league.py --kerasHost <container-ip> --kerasPort 8080
```

**From benchmark script:**
```bash
# Set environment variable
export KERAS_OCR_HOST="<container-ip>"
export KERAS_OCR_PORT="8080"

# Or pass to script
./run-rocket-league-benchmark.sh <container-ip>
```

---

## References

- [Proxmox LXC Documentation](https://pve.proxmox.com/wiki/Linux_Container)
- [Docker in LXC](https://pve.proxmox.com/wiki/Linux_Container#pct_container_storage)
- [LTT MarkBench](https://github.com/LTTLabsOSS/markbench-tests)
- [Headscale Documentation](https://headscale.net/)
- [VVT Infrastructure](../../vvt-infrastructure/)

---

**Last Updated:** January 20, 2026
