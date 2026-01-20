# LLaMA Inference Benchmark Container
FROM docker.io/library/ubuntu:22.04

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Clone and build llama.cpp
WORKDIR /opt
RUN git clone https://github.com/ggerganov/llama.cpp.git && \
    cd llama.cpp && \
    cmake -B build && \
    cmake --build build --config Release -j$(nproc)

# Create benchmark script
COPY benchmark.sh /benchmark.sh
RUN chmod +x /benchmark.sh

WORKDIR /opt/llama.cpp

# Set entrypoint
ENTRYPOINT ["/benchmark.sh"]
