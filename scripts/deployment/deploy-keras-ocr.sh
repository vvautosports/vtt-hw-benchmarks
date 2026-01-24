#!/bin/bash
# Deploy Keras OCR service on MS-01 for MarkBench Rocket League testing
# Run this script on MS-01

set -e

echo "=== Deploying Keras OCR Service for MarkBench ==="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

# Stop and remove existing container if it exists
if docker ps -a | grep -q keras-ocr; then
    echo "Stopping existing keras-ocr container..."
    docker stop keras-ocr 2>/dev/null || true
    docker rm keras-ocr 2>/dev/null || true
fi

# Try to pull and run the LTT MarkBench Keras OCR image
echo "Attempting to pull LTT MarkBench Keras OCR image..."
if docker pull ghcr.io/lttlabsoss/markbench-keras-ocr:latest 2>/dev/null; then
    echo "Running Keras OCR container from LTT image..."
    docker run -d \
        --name keras-ocr \
        --restart unless-stopped \
        -p 8080:8080 \
        ghcr.io/lttlabsoss/markbench-keras-ocr:latest
else
    echo "WARNING: Could not pull LTT image. Trying alternative approach..."
    echo "You may need to clone the LTT MarkBench repo and build the Keras service manually:"
    echo ""
    echo "  git clone https://github.com/LTTLabsOSS/markbench-tests.git"
    echo "  cd markbench-tests/keras-ocr-service"
    echo "  docker build -t keras-ocr ."
    echo "  docker run -d --name keras-ocr --restart unless-stopped -p 8080:8080 keras-ocr"
    echo ""
    exit 1
fi

# Wait for service to be ready
echo "Waiting for Keras OCR service to start..."
sleep 5

# Check if service is responding
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ Keras OCR service is running successfully!"
    echo ""
    echo "Service URL: http://localhost:8080"
    echo "Container name: keras-ocr"
    echo ""
    echo "To check logs: docker logs keras-ocr"
    echo "To stop: docker stop keras-ocr"
    echo "To restart: docker restart keras-ocr"
    echo ""
    echo "Test from HP ZBook with: curl http://<MS-01-IP>:8080/health"
else
    echo "ERROR: Keras OCR service is not responding on port 8080"
    echo "Check container logs: docker logs keras-ocr"
    exit 1
fi
