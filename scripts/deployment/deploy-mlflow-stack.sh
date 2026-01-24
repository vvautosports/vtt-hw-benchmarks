#!/bin/bash
# Deploy minimal MLflow stack for hardware benchmarking on MS-01
# Run this script directly on MS-01

set -e

echo "=== Deploying Minimal MLflow Stack for Hardware Benchmarking ==="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

echo "✅ Docker and Docker Compose available"

# Create directory for the compose file if it doesn't exist
COMPOSE_DIR="/opt/benchmark-mlflow"
mkdir -p "$COMPOSE_DIR"

# Copy the compose file (assuming it's in the same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/../docker-compose.mlflow.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ docker-compose.mlflow.yml not found in $SCRIPT_DIR/.."
    echo "Please ensure the compose file exists."
    exit 1
fi

cp "$COMPOSE_FILE" "$COMPOSE_DIR/docker-compose.yml"
echo "✅ Copied docker-compose.yml to $COMPOSE_DIR"

# Change to the compose directory
cd "$COMPOSE_DIR"

# Stop any existing containers
echo "Stopping any existing benchmark containers..."
docker-compose down || true

# Start the services
echo "Starting MLflow stack..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check service health
echo "Checking service status..."

# Check PostgreSQL
if docker-compose exec -T postgres pg_isready -U mlflow -d mlflow &>/dev/null; then
    echo "✅ PostgreSQL is ready"
else
    echo "⚠️  PostgreSQL may not be ready yet"
fi

# Check MLflow
if curl -s http://localhost:5000 &>/dev/null; then
    echo "✅ MLflow server is responding"
else
    echo "⚠️  MLflow server may not be ready yet"
fi

# Check Keras OCR
if curl -s http://localhost:8080/health &>/dev/null; then
    echo "✅ Keras OCR service is responding"
else
    echo "⚠️  Keras OCR service may not be ready yet"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✨ Deployment Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Services:"
echo "  MLflow Server:     http://localhost:5000"
echo "  MinIO Console:     http://localhost:9001"
echo "  Keras OCR:         http://localhost:8080"
echo ""
echo "For laptop access (from same network):"
echo "  MLflow Server:     http://192.168.7.30:5000"
echo "  Keras OCR:         http://192.168.7.30:8080"
echo ""
echo "Management commands:"
echo "  View logs:         docker-compose logs -f [service-name]"
echo "  Stop stack:        docker-compose down"
echo "  Restart service:   docker-compose restart [service-name]"
echo ""
echo "Next steps:"
echo "  1. Set MLFLOW_TRACKING_URI=http://192.168.7.30:5000 on laptops"
echo "  2. Import existing results: benchmark-to-mlflow.py results/*.json"
echo "  3. Run benchmarks and watch results appear in MLflow UI"
echo ""

# Optional: Import existing results if they exist
if [ -d "/path/to/benchmark/results" ] && [ -f "/path/to/benchmark-to-mlflow.py" ]; then
    echo "Importing existing benchmark results..."
    # This would need the actual paths adjusted
    echo "Run manually: python benchmark-to-mlflow.py /path/to/results/*.json"
fi