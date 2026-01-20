# VTT Hardware Benchmarks

Virtual Velocity Collective hardware benchmarking project for HP ZBook laptops and Framework laptops.

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

See `HP-ZBOOK-SETUP.md` for Windows setup.

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

## Future Expansion

**More Benchmarks:**
- 7-Zip, Blender, STREAM, Storage (fio)
- AI models via llama-bench
- Flux.2 image generation

**Infrastructure:**
- Automated FPS capture with PresentMon
- Supabase database for results
- Streamlit dashboard
- Multi-run automation

## Resources

- [LTT MarkBench Repository](https://github.com/LTTLabsOSS/markbench-tests)
- [Cinebench R23](https://www.maxon.net/en/cinebench)
