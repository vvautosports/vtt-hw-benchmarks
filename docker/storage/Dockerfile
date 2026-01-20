# Storage I/O Benchmark Container using fio
FROM docker.io/library/ubuntu:22.04

# Install fio and utilities
RUN apt-get update && apt-get install -y \
    fio \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Create benchmark script and config
COPY benchmark.sh /benchmark.sh
COPY fio-config.fio /fio-config.fio
RUN chmod +x /benchmark.sh

# Create test directory
RUN mkdir -p /benchdata

WORKDIR /benchdata

# Set entrypoint
ENTRYPOINT ["/benchmark.sh"]
