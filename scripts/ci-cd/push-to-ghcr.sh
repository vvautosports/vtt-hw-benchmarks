#!/bin/bash
# Push benchmark container images to GitHub Container Registry
# Usage: ./scripts/push-to-ghcr.sh [--dry-run] [VERSION]
#
# This script tags and pushes all benchmark images to ghcr.io
# for deployment on HP ZBooks and other test systems.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="${1:---push}"
VERSION="${2:-latest}"

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

echo "=== Push VTT Benchmark Images to GHCR ==="
echo ""
echo "Runtime: $RUNTIME"
echo "Registry: $GHCR_REGISTRY"
echo "Namespace: $GHCR_NAMESPACE/$GHCR_REPO"
echo "Version: $VERSION"
echo "Mode: $MODE"
echo ""

if [ "$MODE" = "--dry-run" ]; then
    echo "🔍 DRY RUN MODE (no actual push)"
    echo ""
fi

# Check authentication
if [ "$MODE" != "--dry-run" ]; then
    echo "Checking GHCR authentication..."

    if [ "$RUNTIME" = "podman" ]; then
        if ! podman login --get-login $GHCR_REGISTRY &> /dev/null; then
            echo ""
            echo "⚠️  Not authenticated with GHCR"
            echo ""
            echo "Authenticate with:"
            echo "  1. Create GitHub Personal Access Token (classic) with 'write:packages' scope"
            echo "     Go to: https://github.com/settings/tokens"
            echo ""
            echo "  2. Login to GHCR:"
            echo "     echo \$GITHUB_TOKEN | podman login ghcr.io -u USERNAME --password-stdin"
            echo ""
            echo "Or run in dry-run mode:"
            echo "  ./scripts/push-to-ghcr.sh --dry-run"
            exit 1
        fi
    else
        if ! docker login $GHCR_REGISTRY --get-login &> /dev/null 2>&1; then
            echo ""
            echo "⚠️  Not authenticated with GHCR"
            echo ""
            echo "Authenticate with:"
            echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
            exit 1
        fi
    fi

    echo "✅ Authenticated with GHCR"
    echo ""
fi

# Check if images exist locally
echo "Checking local images..."
for image in "${IMAGES[@]}"; do
    if ! $RUNTIME images | grep -q "$image"; then
        echo "❌ ERROR: Image $image not found locally"
        echo ""
        echo "Build images first:"
        echo "  cd docker"
        echo "  ./build-all.sh"
        exit 1
    fi
done
echo "✅ All images found locally"
echo ""

# Tag and push images
for image in "${IMAGES[@]}"; do
    LOCAL_IMAGE="$image"
    REMOTE_IMAGE="$GHCR_REGISTRY/$GHCR_NAMESPACE/$GHCR_REPO/$image"

    echo "───────────────────────────────────────────────"
    echo "📦 Processing: $image"
    echo "───────────────────────────────────────────────"

    # Tag with version
    echo "Tagging: $REMOTE_IMAGE:$VERSION"
    if [ "$MODE" != "--dry-run" ]; then
        $RUNTIME tag "$LOCAL_IMAGE:latest" "$REMOTE_IMAGE:$VERSION"
    fi

    # Also tag as latest if version is not latest
    if [ "$VERSION" != "latest" ]; then
        echo "Tagging: $REMOTE_IMAGE:latest"
        if [ "$MODE" != "--dry-run" ]; then
            $RUNTIME tag "$LOCAL_IMAGE:latest" "$REMOTE_IMAGE:latest"
        fi
    fi

    # Push versioned image
    echo "Pushing: $REMOTE_IMAGE:$VERSION"
    if [ "$MODE" != "--dry-run" ]; then
        $RUNTIME push "$REMOTE_IMAGE:$VERSION"
        echo "✅ Pushed $REMOTE_IMAGE:$VERSION"
    else
        echo "🔍 Would push: $REMOTE_IMAGE:$VERSION"
    fi

    # Push latest tag
    if [ "$VERSION" != "latest" ] && [ "$MODE" != "--dry-run" ]; then
        echo "Pushing: $REMOTE_IMAGE:latest"
        $RUNTIME push "$REMOTE_IMAGE:latest"
        echo "✅ Pushed $REMOTE_IMAGE:latest"
    fi

    echo ""
done

echo "═══════════════════════════════════════════════"
if [ "$MODE" = "--dry-run" ]; then
    echo "✨ Dry run complete - no images pushed"
else
    echo "✨ All images pushed successfully!"
fi
echo "═══════════════════════════════════════════════"
echo ""

# Show pull commands
echo "📥 To pull these images on other systems:"
echo ""
for image in "${IMAGES[@]}"; do
    echo "  $RUNTIME pull ghcr.io/$GHCR_NAMESPACE/$GHCR_REPO/$image:$VERSION"
done
echo ""

if [ "$MODE" != "--dry-run" ]; then
    echo "🌐 View packages at:"
    echo "  https://github.com/orgs/$GHCR_NAMESPACE/packages"
fi
echo ""
