#!/bin/bash
# Detect container runtime (docker or podman)

if command -v docker &> /dev/null; then
    echo "docker"
elif command -v podman &> /dev/null; then
    echo "podman"
else
    echo "ERROR: Neither docker nor podman is installed" >&2
    exit 1
fi
