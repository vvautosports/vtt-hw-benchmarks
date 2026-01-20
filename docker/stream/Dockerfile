# STREAM Memory Bandwidth Benchmark Container
FROM docker.io/library/gcc:latest

# Install required tools
RUN apt-get update && apt-get install -y \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download STREAM benchmark
WORKDIR /opt
RUN wget https://www.cs.virginia.edu/stream/FTP/Code/stream.c

# Compile STREAM with optimizations
# Array size: 80 million elements (approx 1.8GB total)
RUN gcc -O3 -march=native -mtune=native -fopenmp \
    -DSTREAM_ARRAY_SIZE=80000000 \
    -DNTIMES=20 \
    stream.c -o stream

# Create benchmark script
COPY benchmark.sh /benchmark.sh
RUN chmod +x /benchmark.sh

# Set entrypoint
ENTRYPOINT ["/benchmark.sh"]
