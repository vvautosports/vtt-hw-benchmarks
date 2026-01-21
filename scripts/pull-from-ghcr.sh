#!/bin/bash
# Pull benchmark container images from GitHub Container Registry
# Usage: ./scripts/pull-from-ghcr.sh [VERSION]
#
# This script pulls pre-built benchmark images from GHCR
# for quick deployment on HP ZBooks and other test systems.

set -e

VERSION="${1:-latest}"

# GitHub Container Registry settings
GHCR_REGISTRY="ghcr.io"
GHCR_NAMESPACE="vvautosports"
GHCR_REPO="vtt-hw-benchmarks"

# Detect container runtime
if command -v docker &> /dev/null; then
    RUNTIME="docker"
elif command -v podman &> /dev/null; then
    RUNTIME="podman"
else
    echo "❌ ERROR: Neither docker nor podman is installed"
    exit 1
fi

# Image list
IMAGES=(
    "vtt-benchmark-7zip"
    "vtt-benchmark-stream"
    "vtt-benchmark-storage"
    "vtt-benchmark-llama"
)

echo "=== Pull VTT Benchmark Images from GHCR ==="
echo ""
echo "Runtime: $RUNTIME"
echo "Registry: $GHCR_REGISTRY"
echo "Namespace: $GHCR_NAMESPACE/$GHCR_REPO"
echo "Version: $VERSION"
echo ""

# Note: GHCR public images don't require authentication to pull
# But if images are private, uncomment this:
# echo "Checking GHCR authentication..."
# if ! $RUNTIME login --get-login $GHCR_REGISTRY &> /dev/null; then
#     echo "⚠️  Not authenticated with GHCR"
#     echo "For private images, authenticate with:"
#     echo "  echo \$GITHUB_TOKEN | $RUNTIME login ghcr.io -u USERNAME --password-stdin"
#     exit 1
# fi

# Pull images
for image in "${IMAGES[@]}"; do
    REMOTE_IMAGE="$GHCR_REGISTRY/$GHCR_NAMESPACE/$GHCR_REPO/$image:$VERSION"
    LOCAL_TAG="$image:latest"

    echo "───────────────────────────────────────────────"
    echo "📥 Pulling: $image"
    echo "───────────────────────────────────────────────"
    echo "Source: $REMOTE_IMAGE"
    echo "Local tag: $LOCAL_TAG"
    echo ""

    # Pull image
    $RUNTIME pull "$REMOTE_IMAGE"

    # Tag as local name for convenience
    $RUNTIME tag "$REMOTE_IMAGE" "$LOCAL_TAG"

    echo "✅ Pulled and tagged: $LOCAL_TAG"
    echo ""
done

echo "═══════════════════════════════════════════════"
echo "✨ All images pulled successfully!"
echo "═══════════════════════════════════════════════"
echo ""

echo "📦 Available images:"
$RUNTIME images | grep -E "(REPOSITORY|vtt-benchmark-)" || echo "No images found"
echo ""

echo "🚀 Run benchmarks with:"
echo "  cd docker"
echo "  ./run-all.sh"
echo ""
echo "Or individual benchmarks:"
for image in "${IMAGES[@]}"; do
    echo "  $RUNTIME run --rm $image"
done
echo ""
