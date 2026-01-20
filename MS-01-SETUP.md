# MS-01 Setup Guide - Keras OCR Service

Quick guide for setting up the MS-01 server to support MarkBench Rocket League testing.

## Requirements

- MS-01 server running Linux
- Docker installed and running
- Network connectivity to HP ZBooks (Headscale VPN or local LAN)
- Port 8080 available

## Quick Deploy (5 minutes)

### Option 1: Using LTT Docker Image (Recommended)

```bash
# Navigate to repo
cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks

# Run deployment script
./scripts/deploy-keras-ocr.sh
```

The script will:
1. Check if Docker is installed
2. Stop any existing keras-ocr container
3. Pull the LTT MarkBench Keras OCR image
4. Run the container on port 8080
5. Verify the service is responding

### Option 2: Manual Docker Run

```bash
docker run -d \
  --name keras-ocr \
  --restart unless-stopped \
  -p 8080:8080 \
  ghcr.io/lttlabsoss/markbench-keras-ocr:latest
```

### Option 3: Build from LTT Repository

If the pre-built image isn't available:

```bash
# Clone LTT MarkBench repository
git clone https://github.com/LTTLabsOSS/markbench-tests.git /tmp/markbench
cd /tmp/markbench/keras-ocr-service

# Build Docker image
docker build -t keras-ocr .

# Run container
docker run -d \
  --name keras-ocr \
  --restart unless-stopped \
  -p 8080:8080 \
  keras-ocr
```

## Verification

### Local Test (on MS-01)

```bash
# Check container is running
docker ps | grep keras-ocr

# Test health endpoint
curl http://localhost:8080/health

# Check logs
docker logs keras-ocr
```

Expected response from health endpoint:
```json
{"status": "healthy"}
```
or similar positive response.

### Remote Test (from HP ZBook)

```powershell
# From Windows PowerShell on HP ZBook
curl http://[MS-01-IP]:8080/health
```

Or from another Linux machine:
```bash
# From repo directory
./scripts/verify-keras-ocr.sh [MS-01-IP]
```

## Firewall Configuration

If the service isn't accessible from HP ZBooks, check the firewall:

```bash
# Check if port 8080 is allowed
sudo firewall-cmd --list-ports

# Add port 8080 (if needed)
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports | grep 8080
```

## Finding MS-01 IP Address

```bash
# Show all IP addresses
ip addr show

# Show only IPv4 addresses
ip -4 addr show | grep inet
```

Common interfaces:
- `enp*` - Ethernet
- `wlp*` - WiFi
- `tailscale0` - Headscale/Tailscale VPN

Use the appropriate IP based on network topology:
- Local LAN: Use ethernet/wifi IP (e.g., 192.168.x.x)
- Headscale VPN: Use tailscale0 IP (e.g., 100.64.x.x)

## Container Management

### View Logs
```bash
docker logs keras-ocr
docker logs -f keras-ocr  # Follow logs in real-time
```

### Restart Service
```bash
docker restart keras-ocr
```

### Stop Service
```bash
docker stop keras-ocr
```

### Remove Container
```bash
docker stop keras-ocr
docker rm keras-ocr
```

### Update Service
```bash
# Pull latest image
docker pull ghcr.io/lttlabsoss/markbench-keras-ocr:latest

# Stop and remove old container
docker stop keras-ocr
docker rm keras-ocr

# Run new container
docker run -d \
  --name keras-ocr \
  --restart unless-stopped \
  -p 8080:8080 \
  ghcr.io/lttlabsoss/markbench-keras-ocr:latest
```

## Troubleshooting

### Container won't start

```bash
# Check if port 8080 is already in use
sudo netstat -tlnp | grep 8080

# or with ss
sudo ss -tlnp | grep 8080

# Check Docker logs for errors
docker logs keras-ocr
```

### Service not responding

```bash
# Check container status
docker ps -a | grep keras-ocr

# Check if container is running
docker inspect keras-ocr | grep Status

# Restart container
docker restart keras-ocr
```

### Can't pull Docker image

```bash
# Check Docker Hub/GitHub Container Registry access
docker pull ghcr.io/lttlabsoss/markbench-keras-ocr:latest

# If image doesn't exist, build from source (Option 3 above)
```

### Network connectivity issues

```bash
# From MS-01, verify service is accessible
curl http://localhost:8080/health

# Check firewall
sudo firewall-cmd --list-all

# Test from HP ZBook IP to MS-01
ping [MS-01-IP]
telnet [MS-01-IP] 8080
```

## Performance Monitoring

### Resource Usage

```bash
# Check container resource usage
docker stats keras-ocr

# Check detailed container info
docker inspect keras-ocr
```

### Logs Analysis

```bash
# View recent logs
docker logs --tail 100 keras-ocr

# Follow logs during benchmark
docker logs -f keras-ocr
```

## Auto-start on Boot

The `--restart unless-stopped` flag ensures the container automatically starts when Docker daemon starts (typically on boot).

Verify:
```bash
docker inspect keras-ocr | grep RestartPolicy -A 3
```

## API Endpoints

The Keras OCR service likely exposes these endpoints:

- `GET /health` - Health check
- `POST /ocr` or `/predict` - OCR inference (used by MarkBench)

Check the [LTT MarkBench documentation](https://github.com/LTTLabsOSS/markbench-tests) for exact API details.

## Network Topology

For tonight's testing, ensure:

1. MS-01 is accessible from HP ZBook network
2. Either:
   - Both on same local LAN, OR
   - Both connected via Headscale VPN
3. No firewall blocking port 8080

## Quick Reference Commands

```bash
# Deploy service
./scripts/deploy-keras-ocr.sh

# Check status
docker ps | grep keras-ocr
curl http://localhost:8080/health

# View logs
docker logs keras-ocr

# Restart
docker restart keras-ocr

# Get MS-01 IP
ip -4 addr show | grep inet
```

## Next Steps

After Keras OCR is running:
1. Note the MS-01 IP address
2. Test connectivity from HP ZBook
3. Proceed with HP ZBook software setup
4. Run Rocket League benchmark

See `HP-ZBOOK-SETUP.md` for Windows setup steps.
