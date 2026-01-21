# VTT Hardware Benchmarks

Virtual Velocity Collective hardware benchmarking project for HP ZBook laptops and Framework desktop mainboard.

## Containerized Benchmarks (Cross-Platform)

Pre-built container images available on GitHub Container Registry for quick deployment.

### Quick Start

**Pull and run pre-built images:**
```bash
# Clone repository
git clone https://github.com/vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks

# Pull all benchmark images from GHCR
./scripts/pull-from-ghcr.sh

# Run all benchmarks
cd docker
./run-all.sh
```

**Available benchmarks:**
- **7-Zip** - CPU compression performance
- **STREAM** - Memory bandwidth
- **Storage (fio)** - Disk I/O performance
- **LLaMA (llama.cpp)** - AI inference with AMD Strix Halo iGPU

**See:** `docker/README.md` for detailed benchmark documentation.

## Quick Start (Tonight's Testing)

### Goal
Test ONE HP ZBook with basic benchmarks tonight. Iterate and expand later.

### Prerequisites

**On MS-01 (Linux):**
- Docker installed
- Keras OCR service running on port 8080

**On HP ZBook (Windows 11):**
- Python 3.11
- Poetry
- Epic Games Launcher + Rocket League
- Cinebench R23

### Setup Steps

#### 1. Deploy Keras OCR on MS-01
```bash
docker run -d -p 8080:8080 --name keras-ocr \
  ghcr.io/lttlabsoss/markbench-keras-ocr:latest

# Verify it's running
curl http://localhost:8080/health
```

#### 2. Install Software on HP ZBook
```powershell
# Install Python 3.11
winget install Python.Python.3.11

# Install Poetry
pip install poetry

# Clone LTT MarkBench
git clone https://github.com/LTTLabsOSS/markbench-tests C:\benchmarks\markbench
cd C:\benchmarks\markbench
poetry install

# Install Epic Games Launcher and Rocket League (manual)
# Download Cinebench R23 from Maxon website
```

#### 3. Configure Rocket League
1. Launch Rocket League from Epic Games Launcher
2. Go to Settings → Video
3. Set:
   - Resolution: 1920x1080
   - Display Mode: Fullscreen
   - Render Quality: High Quality
   - FPS: Uncapped
4. Exit properly (don't Alt+F4)

#### 4. Run Benchmarks

**Rocket League:**
```powershell
cd C:\benchmarks\markbench\rocket_league
python rocket_league.py --kerasHost <MS-01-IP> --kerasPort 8080
```
Manually observe and note the FPS during playback.

**Cinebench R23:**
1. Launch Cinebench R23
2. Run Multi-Core test
3. Note the score

#### 5. Document Results
See `results/hp-zbook-template.md` for the documentation template.

## Directory Structure

```
vtt-hw-benchmarks/
├── docker/               # Containerized benchmarks
│   ├── 7zip/            # CPU compression benchmark
│   ├── stream/          # Memory bandwidth benchmark
│   ├── llama-bench/     # AI inference benchmark
│   ├── build-all.sh     # Build all containers
│   ├── run-all.sh       # Run all (Linux)
│   └── run-all.ps1      # Run all (Windows)
├── results/              # Benchmark results (committed to git)
├── scripts/              # Helper scripts
├── rocket-league/        # Rocket League specific configs/scripts
├── README.md
└── .gitignore
```

## Benchmark Types

### Cross-Platform (Containerized - Linux & Windows)

These run via Docker/Podman and work on any system:

1. **7-Zip** - CPU compression performance
2. **STREAM** - Memory bandwidth
3. **LLaMA Inference** - AI model performance

See `docker/README.md` for details.

**Quick start:**
```bash
cd docker
./build-all.sh
./run-all.sh
```

### Windows-Only Benchmarks

These require Windows and native applications:

1. **Rocket League** - GPU gaming performance (via LTT MarkBench)
2. **Cinebench R23** - CPU rendering performance

See `docs/HP-ZBOOK-SETUP.md` for Windows setup.

## Current Status

**Infrastructure:**
- [x] Git repo initialized
- [x] Containerized benchmarks (7-Zip, STREAM, LLaMA)
- [x] Framework laptop baseline tested
- [ ] Keras OCR deployed on MS-01 (for Rocket League)

**Device Testing:**
- [x] Framework Laptop 13 AMD - Containerized tests complete
- [ ] HP ZBook 01 - Pending
- [ ] HP ZBook 02 - Pending
- [ ] HP ZBook 03 - Pending
- [ ] HP ZBook 04 - Pending

**Results Storage:**
- Currently: Git repository (`results/` directory)
- Future: Supabase database + Streamlit dashboard

## Documentation

- **[docs/](docs/)** - All documentation, setup guides, and planning
  - [ROADMAP.md](docs/ROADMAP.md) - Feature roadmap and next steps
  - [HP-ZBOOK-SETUP.md](docs/HP-ZBOOK-SETUP.md) - Windows setup guide
  - [MS-01-SETUP.md](docs/MS-01-SETUP.md) - Keras OCR deployment
  - [GitHub Issues](docs/github-issues-to-create.md) - Ready to create
- **[docker/README.md](docker/README.md)** - Containerized benchmarks

## Future Expansion

See [ROADMAP.md](docs/ROADMAP.md) for detailed feature plans.

**Immediate Next Steps:**
- Deploy Keras OCR on MS-01
- Test HP ZBook 01-04
- Create performance comparison analysis

**Planned Features:**
- Automated FPS capture (PresentMon)
- Multi-run statistical analysis
- Storage benchmarks (fio)
- Database integration (Supabase)
- Visualization dashboard (Streamlit)

## Resources

- [LTT MarkBench Repository](https://github.com/LTTLabsOSS/markbench-tests)
- [Cinebench R23](https://www.maxon.net/en/cinebench)
- [STREAM Benchmark](https://www.cs.virginia.edu/stream/)
- [llama.cpp](https://github.com/ggerganov/llama.cpp)
