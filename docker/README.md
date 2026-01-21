# Containerized Benchmarks

Cross-platform benchmark suite using Docker containers for consistent, reproducible testing.

## Available Benchmarks

### 7-Zip (CPU Compression)
Tests CPU performance using compression/decompression workloads.
- **Duration:** ~2 minutes
- **Metric:** MIPS (Million Instructions Per Second)

### STREAM (Memory Bandwidth)
Tests memory bandwidth using standard STREAM benchmark.
- **Duration:** ~1 minute
- **Metric:** MB/s for Copy, Scale, Add, Triad operations

### Storage (Disk I/O)
Tests storage performance using fio (Flexible I/O Tester).
- **Duration:** ~2.5 minutes
- **Metric:** MB/s for sequential, IOPS for random operations
- **Tests:** Sequential R/W, Random 4K R/W, Mixed 70/30 workload

### LLaMA Inference (AI Performance)
Tests AI inference performance using llama.cpp.
- **Duration:** ~2-5 minutes (depends on model)
- **Metric:** Tokens/second for prompt processing and text generation
- **Requirements:** GGUF model file

## Quick Start

### Option 1: Pull Pre-Built Images (Recommended for HP ZBooks)

Pull ready-to-use images from GitHub Container Registry:

```bash
# Pull all benchmark images
./scripts/pull-from-ghcr.sh
```

This skips the build process entirely - perfect for quick deployment on HP ZBooks and other test systems.

### Option 2: Build Locally

Build all benchmarks from source:

```bash
cd docker
./build-all.sh
```

### Run Individual Benchmarks

**7-Zip:**
```bash
docker run --rm vtt-benchmark-7zip
```

**STREAM:**
```bash
docker run --rm vtt-benchmark-stream
```

**Storage:**
```bash
docker run --rm vtt-benchmark-storage
```

**LLaMA Inference:**
```bash
# Requires model file
docker run --rm \
  -v /path/to/model.gguf:/models/model.gguf \
  vtt-benchmark-llama
```

### Run All Benchmarks (Single Run)
```bash
./run-all.sh
```

### Run Multiple Times for Statistical Analysis
```bash
# Run all benchmarks 3 times (default)
./run-multiple.sh

# Custom number of runs and cooldown
BENCHMARK_RUNS=5 COOLDOWN_SECONDS=30 ./run-multiple.sh
```

**Output includes:**
- Mean, median, standard deviation
- Min and max values
- Coefficient of variation (CV%)
- Raw run data for each metric
- Statistical summary table

## Output Format

Each benchmark outputs:
1. Human-readable results to stdout
2. JSON results for automated parsing

JSON output can be captured with:
```bash
docker run --rm vtt-benchmark-7zip > results.json
```

## Configuration

### Environment Variables

**7-Zip:**
- No configuration needed (auto-detects CPU cores)

**STREAM:**
- `OMP_NUM_THREADS`: Number of threads (default: all cores)

**LLaMA:**
- `MODEL_PATH`: Path to GGUF model (default: /models/model.gguf)
- `PROMPT_SIZE`: Prompt tokens (default: 512)
- `GEN_SIZE`: Generation tokens (default: 128)
- `BATCH_SIZE`: Batch size (default: 512)
- `THREADS`: Number of threads (default: all cores)

Example with custom config:
```bash
docker run --rm \
  -e THREADS=8 \
  -e PROMPT_SIZE=1024 \
  -v ~/models/llama-3.2-3b-q4.gguf:/models/model.gguf \
  vtt-benchmark-llama
```

## Building Individual Benchmarks

```bash
# 7-Zip
cd 7zip
docker build -t vtt-benchmark-7zip .

# STREAM
cd stream
docker build -t vtt-benchmark-stream .

# LLaMA
cd llama-bench
docker build -t vtt-benchmark-llama .
```

## System Requirements

- Docker installed and running (Docker Desktop on Windows, docker on Linux)
- Sufficient RAM (minimum 8GB recommended, 16GB+ for LLaMA)
- For LLaMA: GGUF model file (2-8GB depending on model size)

## Windows Support

These containerized benchmarks work on both Linux and Windows:

**Linux (Framework laptop, servers):**
```bash
./build-all.sh
./run-all.sh
```

**Windows (HP ZBooks with Docker Desktop):**
```powershell
.\build-all.sh  # Run in Git Bash or WSL
.\run-all.ps1   # Native PowerShell script
```

**Windows-Only Benchmarks:**
- Rocket League (via LTT MarkBench) - See `docs/HP-ZBOOK-SETUP.md`
- Cinebench R23 - Native Windows application

**Cross-Platform Benchmarks (via Docker):**
- 7-Zip - CPU compression performance
- STREAM - Memory bandwidth
- LLaMA - AI inference performance

## Recommended Models for LLaMA Benchmark

- **Llama 3.2 3B Q4_K_M** (~2GB) - Fast, good for comparison
- **Llama 3.2 1B Q4_K_M** (~800MB) - Very fast, lighter weight
- **Qwen 2.5 7B Q4_K_M** (~4.5GB) - Larger model for testing scaling

Download from Hugging Face or other GGUF model repositories.

## Notes

- All benchmarks run in isolated containers with consistent environments
- Results are reproducible across different systems
- CPU core detection is automatic
- Multi-threaded by default for maximum performance
- JSON output format allows easy integration with databases or dashboards
