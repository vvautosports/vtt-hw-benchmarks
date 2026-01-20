#!/bin/bash
# Verify Keras OCR service is accessible
# Can be run from any machine that should access the service

MS01_IP="${1:-192.168.4.x}"  # Replace with actual MS-01 IP or pass as argument

echo "=== Verifying Keras OCR Service ==="
echo "Target: http://${MS01_IP}:8080"
echo ""

# Test health endpoint
echo "Testing /health endpoint..."
if curl -s -f "http://${MS01_IP}:8080/health" > /dev/null 2>&1; then
    echo "✓ Service is responding"
    response=$(curl -s "http://${MS01_IP}:8080/health")
    echo "Response: $response"
else
    echo "✗ Service is not accessible"
    echo ""
    echo "Troubleshooting:"
    echo "1. Verify MS-01 IP address is correct: $MS01_IP"
    echo "2. Check if service is running on MS-01: docker ps | grep keras-ocr"
    echo "3. Check firewall on MS-01: sudo firewall-cmd --list-ports"
    echo "4. Test from MS-01 locally: ssh ms01 'curl http://localhost:8080/health'"
    exit 1
fi

echo ""
echo "✓ Keras OCR service is ready for MarkBench testing"
echo ""
echo "Use in Rocket League benchmark:"
echo "  python rocket_league.py --kerasHost ${MS01_IP} --kerasPort 8080"
