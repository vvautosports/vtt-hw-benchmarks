# VTT Hardware Benchmarks

Comprehensive hardware benchmarking suite for Virtual Velocity Collective systems, designed to evaluate HP ZBook laptops and Framework desktop mainboards with AMD Ryzen AI Max+ 395 processors.

**Repository:** https://github.com/vvautosports/vtt-hw-benchmarks

---

## Overview

This project provides containerized benchmarks for consistent, reproducible performance testing across Linux and Windows systems. All benchmarks run in Docker/Podman containers for cross-platform compatibility.

**Target Systems:**
- Framework Desktop Mainboard (AMD Ryzen AI Max+ 395, 128GB RAM)
- HP ZBook Ultra G1a laptops (AMD Ryzen AI Max+ 395, varying configs)

**Use Cases:**
- Silicon lottery variance analysis across identical hardware
- Hardware assignment decisions for VTT team members
- Performance baseline documentation
- AI inference capability testing on AMD Strix Halo iGPU

---

## Quick Start

### Prerequisites

**Linux (Framework Desktop):**
- Podman installed
- Access to `/mnt/ai-models` (for AI benchmarks)

**Windows (HP ZBooks):**
- Docker Desktop installed
- Optional: AI model directory mounted

### Pull and Run All Benchmarks

```bash
# Clone repository
git clone https://github.com/vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks

# Pull pre-built images from GitHub Container Registry
./scripts/pull-from-ghcr.sh

# Run all benchmarks
cd docker
./run-all.sh
```

Results are saved to `results/` directory with timestamps.

---

## Available Benchmarks

### 1. CPU Performance (7-Zip)

Tests CPU compression performance using 7-Zip benchmark.

**What it measures:**
- Multi-threaded compression speed (MIPS)
- CPU core scaling efficiency
- Memory bandwidth under load

**Container:** `vtt-benchmark-7zip`

**Quick run:**
```bash
podman run --rm vtt-benchmark-7zip
```

**Typical results (AMD Ryzen AI Max+ 395):**
- ~119,000 MIPS (16 cores, 32 threads)

### 2. Memory Bandwidth (STREAM)

Measures memory subsystem performance using STREAM benchmark.

**What it measures:**
- Copy, Scale, Add, Triad operations (GB/s)
- Memory bandwidth under sustained load
- DDR5 performance characteristics

**Container:** `vtt-benchmark-stream`

**Quick run:**
```bash
podman run --rm vtt-benchmark-stream
```

**Typical results (AMD Ryzen AI Max+ 395, DDR5-5600):**
- Copy: ~96 GB/s
- Scale: ~96 GB/s
- Add: ~102 GB/s
- Triad: ~102 GB/s

### 3. Storage I/O (fio)

Tests disk performance with various I/O patterns.

**What it measures:**
- Sequential read/write bandwidth (MB/s)
- Random read/write IOPS
- Mixed workload performance
- Latency characteristics

**Container:** `vtt-benchmark-storage`

**Quick run:**
```bash
podman run --rm vtt-benchmark-storage
```

**Typical results (NVMe SSD):**
- Sequential read: ~3,300 MB/s
- Sequential write: ~3,000 MB/s
- Random read: ~22,000 IOPS
- Random write: ~17,000 IOPS

### 4. AI Inference (llama.cpp)

Tests AI model inference using llama.cpp with AMD Strix Halo iGPU acceleration.

**What it measures:**
- Prompt processing speed (tokens/sec)
- Text generation speed (tokens/sec)
- GPU offloading capability
- Memory bandwidth under AI workloads

**Container:** `vtt-benchmark-llama`

**Quick run:**
```bash
# Single model test
podman run --rm \
  --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render \
  --security-opt seccomp=unconfined \
  -v /mnt/ai-models/model.gguf:/models/model.gguf:ro,z \
  vtt-benchmark-llama

# Test all models in directory
./docker/run-ai-models.sh
```

**Supported features:**
- AMD Strix Halo iGPU offloading (Vulkan RADV backend)
- Flash attention for performance
- Multi-part model support (e.g., 3-part 235B models)
- Automatic model discovery
- Variable context size testing

**Typical results (AMD Ryzen AI Max+ 395, 4GB UMA):**
- Small models (20B): 1000-1500 t/s prompt, 40-60 t/s generation
- Large models (235B): 100-200 t/s prompt, 10-20 t/s generation

**See:** `docs/AMD-STRIX-HALO-SETUP.md` for iGPU configuration details.

### 5. Gaming Performance (Rocket League)

Tests GPU gaming performance using LTT MarkBench automation.

**What it measures:**
- Average FPS during standardized replay
- Frame time consistency
- GPU utilization

**Requirements:**
- Windows system (HP ZBooks)
- Rocket League installed (free-to-play via Epic)
- Keras OCR service running on MS-01

**Setup:**
See `docs/HP-ZBOOK-SETUP.md` and `docs/MS-01-LXC-DEPLOYMENT.md`

---

## Extended Testing: GLM-4.7 Models

Special testing suite for GLM-4.7 models with variable context sizes.

**Available models:**
1. **GLM-4.7-Flash-Q8** (33GB) - Best efficiency, 202K max context
2. **GLM-4.7-Flash-BF16** (56GB) - Best quality, 202K max context
3. **GLM-4.7-REAP-218B** (92GB) - Best reasoning, 65K practical max

**Run extended context tests:**
```bash
# Test Q8 at various context sizes
CONTEXT_SIZES="32768,65536,131072,202752" \
  ./docker/run-ai-models.sh --context-test --filter "GLM-4.7-Flash-Q8"

# Estimate VRAM requirements first
python3 /path/to/gguf-vram-estimator.py \
  /mnt/ai-models/GLM-4.7-Flash-Q8/GLM-4.7-Flash-UD-Q8_K_XL.gguf \
  --contexts 65536 131072 202752
```

**See:** `docs/GLM-4.7-TESTING.md` for complete use case analysis and recommendations.

---

## Directory Structure

```
vtt-hw-benchmarks/
├── docker/                    # Containerized benchmarks
│   ├── 7zip/                 # CPU compression benchmark
│   │   ├── Dockerfile
│   │   └── benchmark.sh
│   ├── stream/               # Memory bandwidth benchmark
│   │   ├── Dockerfile
│   │   └── benchmark.sh
│   ├── storage/              # Storage I/O benchmark
│   │   ├── Dockerfile
│   │   └── benchmark.sh
│   ├── llama-bench/          # AI inference benchmark
│   │   ├── Dockerfile
│   │   ├── benchmark.sh
│   │   └── benchmark-context.sh  # Variable context testing
│   ├── run-all.sh            # Run all benchmarks (Linux)
│   ├── run-all.ps1           # Run all benchmarks (Windows)
│   ├── run-ai-models.sh      # AI model testing with auto-discovery
│   └── README.md             # Detailed benchmark docs
├── scripts/                   # Helper utilities
│   ├── push-to-ghcr.sh       # Publish containers to registry
│   ├── pull-from-ghcr.sh     # Pull pre-built containers
│   └── README.md             # Script documentation
├── docs/                      # Documentation
│   ├── AMD-STRIX-HALO-SETUP.md      # AMD iGPU configuration
│   ├── GLM-4.7-TESTING.md           # GLM model testing guide
│   ├── HP-ZBOOK-SETUP.md            # Windows setup guide
│   ├── MS-01-SETUP.md               # Keras OCR deployment
│   ├── MS-01-LXC-DEPLOYMENT.md      # Proxmox LXC guide
│   ├── README.md                    # Documentation index
│   └── archive/                     # Archived planning docs
├── results/                   # Benchmark results (gitignored)
│   └── .gitkeep
├── .github/                   # CI/CD workflows
│   └── workflows/
│       ├── build-and-push-containers.yml  # Auto-build on push
│       └── ci.yml                         # Lint and validation
├── SESSION-SUMMARY.md         # Development progress tracking
└── README.md                  # This file
```

---

## Automation and CI/CD

### Automated Container Builds

Containers are automatically built and published to GitHub Container Registry on every push to `master`:

- **Registry:** `ghcr.io/vvautosports/vtt-hw-benchmarks`
- **Images:** `7zip`, `stream`, `storage`, `llama`
- **Workflow:** `.github/workflows/build-and-push-containers.yml`

**Pull pre-built images:**
```bash
./scripts/pull-from-ghcr.sh
```

### Multi-Run Automation

Run benchmarks multiple times for statistical analysis:

```bash
cd docker
./run-multiple.sh 5  # Run each benchmark 5 times
```

Results include mean, median, standard deviation, and variance analysis.

---

## Documentation

### Setup Guides
- **[AMD-STRIX-HALO-SETUP.md](docs/AMD-STRIX-HALO-SETUP.md)** - AMD iGPU configuration for AI inference
- **[HP-ZBOOK-SETUP.md](docs/HP-ZBOOK-SETUP.md)** - Windows setup for HP ZBooks
- **[MS-01-SETUP.md](docs/MS-01-SETUP.md)** - Keras OCR service deployment (legacy)
- **[MS-01-LXC-DEPLOYMENT.md](docs/MS-01-LXC-DEPLOYMENT.md)** - Proxmox LXC deployment (recommended)

### Testing Guides
- **[GLM-4.7-TESTING.md](docs/GLM-4.7-TESTING.md)** - Extended context testing for GLM models
- **[docker/README.md](docker/README.md)** - Detailed benchmark documentation
- **[scripts/README.md](scripts/README.md)** - Helper script usage

---

## Current Status

**Benchmarks Implemented:**
- ✅ 7-Zip CPU compression
- ✅ STREAM memory bandwidth
- ✅ Storage I/O (fio)
- ✅ AI inference (llama.cpp with AMD iGPU)
- ✅ GLM-4.7 extended context testing
- 🚧 Rocket League (requires MS-01 Keras OCR deployment)

**Systems Tested:**
- ✅ Framework Desktop Mainboard (AMD Ryzen AI Max+ 395)
- ⏸️ HP ZBook Ultra G1a (4 units) - Pending Keras OCR

**Infrastructure:**
- ✅ GitHub repository and CI/CD
- ✅ GHCR container distribution
- ✅ Automated builds on push
- ✅ Multi-run automation framework
- ⏸️ MS-01 Proxmox LXC deployment (guide ready, pending execution)

---

## Credits and Acknowledgments

This project builds on excellent work from the open-source community:

### Core Dependencies

**AMD Strix Halo Toolboxes** by [kyuz0](https://github.com/kyuz0)
- Pre-built llama.cpp containers with Vulkan/ROCm support for AMD iGPU
- VRAM estimation utility (`gguf-vram-estimator.py`)
- Critical configuration flags and setup for Strix Halo
- Repository: https://github.com/kyuz0/amd-strix-halo-toolboxes
- Used in: `docker/llama-bench/Dockerfile`, AI inference benchmarks

**llama.cpp** by Georgi Gerganov and contributors
- High-performance LLM inference engine
- GGUF model format support
- GPU acceleration via Vulkan and ROCm
- Repository: https://github.com/ggerganov/llama.cpp
- Used in: AI inference benchmarks

**LTT MarkBench** by Linus Tech Tips Labs
- Automated gaming benchmark framework
- Rocket League test automation
- Keras OCR integration for menu navigation
- Repository: https://github.com/LTTLabsOSS/markbench-tests
- Used in: Rocket League gaming benchmarks

### Benchmark Tools

**7-Zip** by Igor Pavlov
- CPU compression benchmark
- Website: https://www.7-zip.org/

**STREAM Benchmark** by Dr. John D. McCalpin
- Memory bandwidth measurement
- Website: https://www.cs.virginia.edu/stream/

**fio (Flexible I/O Tester)** by Jens Axboe
- Storage I/O benchmarking
- Repository: https://github.com/axboe/fio

---

## Contributing

This is an internal Virtual Velocity Collective project. For questions or issues, contact the VTT infrastructure team.

**Development workflow:**
1. Make changes in feature branch
2. Test locally with `docker/build-all.sh`
3. Push to trigger automated container builds
4. Verify GHCR images are published
5. Update documentation as needed

---

## License

Internal project for Virtual Velocity Collective. All third-party dependencies retain their original licenses.

---

**Last Updated:** 2026-01-21
**Project Status:** Active Development
**Maintainer:** VTT Infrastructure Team
