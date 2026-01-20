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
├── results/              # Benchmark results (ignored by git)
├── scripts/              # Helper scripts
├── rocket-league/        # Rocket League specific configs/scripts
├── README.md
└── .gitignore
```

## Current Status

- [x] Git repo initialized
- [ ] Keras OCR deployed on MS-01
- [ ] HP ZBook 01 tested
- [ ] HP ZBook 02 tested
- [ ] HP ZBook 03 tested
- [ ] HP ZBook 04 tested

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
