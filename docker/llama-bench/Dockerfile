# LLaMA Inference Benchmark Container for AMD Strix Halo
# Uses pre-built toolboxes from kyuz0/amd-strix-halo-toolboxes
# Defaults to Vulkan (RADV) - most stable
# Can be overridden with ROCm builds for better performance

ARG BACKEND=vulkan-radv
FROM docker.io/kyuz0/amd-strix-halo-toolboxes:${BACKEND}

# Add benchmark script
COPY benchmark.sh /benchmark.sh
RUN chmod +x /benchmark.sh

WORKDIR /workspace

# Set entrypoint
ENTRYPOINT ["/benchmark.sh"]
