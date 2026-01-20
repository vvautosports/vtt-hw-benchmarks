# HP ZBook Setup Guide - Tonight's Testing

Complete setup guide for testing HP ZBook laptops with MarkBench.

## System Information

**HP ZBook Models:**
- HP ZBook Ultra G1a (4 units)
- CPU: AMD Ryzen AI Max+ 395
- GPU: Integrated AMD Radeon
- RAM: Check via Windows System settings

## Software Installation (30 minutes)

### 1. Python 3.11

**Option A: Using winget (recommended)**
```powershell
winget install Python.Python.3.11
```

**Option B: Manual download**
1. Download from https://www.python.org/downloads/
2. Run installer
3. Check "Add Python to PATH"
4. Verify: `python --version`

### 2. Poetry (Python package manager)

```powershell
pip install poetry
```

Verify: `poetry --version`

### 3. Epic Games Launcher

1. Download from https://www.epicgames.com/store/en-US/download
2. Install and sign in
3. Search for "Rocket League" (free to play)
4. Download and install Rocket League (~20GB)

### 4. LTT MarkBench

```powershell
# Create benchmarks directory
mkdir C:\benchmarks
cd C:\benchmarks

# Clone repository
git clone https://github.com/LTTLabsOSS/markbench-tests.git markbench
cd markbench

# Install dependencies with Poetry
poetry install
```

This will create a virtual environment and install all Python dependencies.

### 5. Cinebench R23

1. Download from https://www.maxon.net/en/cinebench
2. Install to default location
3. Launch once to accept license

## Rocket League Configuration (10 minutes)

### Initial Launch

1. Open Epic Games Launcher
2. Click "Launch" on Rocket League
3. Wait for initial setup and shader compilation
4. Skip tutorials if prompted

### Graphics Settings

1. In Rocket League main menu: Settings → Video
2. Configure:
   - **Resolution:** 1920 x 1080
   - **Display Mode:** Fullscreen
   - **Vertical Sync:** Off
   - **Render Quality:** High Quality
   - **Render Detail:** High Quality
   - **Anti-Aliasing:** FXAA High (optional)
   - **FPS:** Uncapped

3. **IMPORTANT:** Exit properly using the menu (Settings → Exit to Desktop)
   - DO NOT use Alt+F4
   - DO NOT use Windows close button
   - Improper exit may corrupt settings

### Verify Configuration

Settings are stored in:
```
%USERPROFILE%\Documents\My Games\Rocket League\TAGame\Config\
```

The MarkBench script expects the game to be properly configured before running.

## Network Configuration

### Verify MS-01 Connectivity

The HP ZBook must be able to reach MS-01 where Keras OCR is running.

**Check connectivity:**
```powershell
# Replace X with actual MS-01 IP address
curl http://192.168.4.X:8080/health
```

Expected response: `{"status": "healthy"}` or similar

**Troubleshooting:**
- Ensure both machines are on same network (Headscale VPN or local network)
- Check Windows Firewall isn't blocking outbound connections
- Ping MS-01: `ping 192.168.4.X`

## Running Benchmarks

### Rocket League Benchmark

```powershell
cd C:\benchmarks\markbench

# Activate Poetry environment
poetry shell

# Run benchmark (replace X with MS-01 IP)
cd rocket_league
python rocket_league.py --kerasHost 192.168.4.X --kerasPort 8080
```

**What to expect:**
- Script will launch Rocket League automatically
- Navigate menus to start replay
- Play RLCS Season 9 replay (~6 minutes)
- Script may capture FPS automatically or you may need to observe manually

**Manual FPS observation:**
- Look for FPS counter in top-right corner (if enabled)
- Or use Alt+Tab to check desktop overlay tools
- Note average FPS during replay

**Common issues:**
- "Failed to launch game" - Check Epic Games Launcher is running
- "Keras OCR not responding" - Verify MS-01 service with curl command
- Game doesn't start replay - Replay file may be missing, check MarkBench docs

### Cinebench R23

```powershell
# Launch Cinebench from Start Menu or:
"C:\Program Files\Maxon Cinebench\Cinebench.exe"
```

1. Click "Run" button for Multi-Core test
2. Wait ~10 minutes for completion
3. Note the score (pts)
4. Optionally run Single-Core test

## Recording Results

### Create Result File

Navigate to the `vtt-hw-benchmarks/results/` directory (on Linux machine or shared drive).

Create file: `hp-zbook-0X-YYYYMMDD.md` (replace X with unit number, YYYYMMDD with date)

Use template from `results/hp-zbook-template.md`

### Information to Capture

**System Info:**
```powershell
# Get system information
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" /C:"System Type"
wmic cpu get name
wmic path win32_VideoController get name
wmic memorychip get capacity
```

**Benchmark Results:**
- Rocket League: Average FPS, Min FPS, Max FPS (if available)
- Cinebench R23: Multi-Core score, Single-Core score
- Notes: Any issues, thermal throttling, fan noise, etc.

## Next Steps

After testing HP ZBook 01:
1. Repeat process for HP ZBook 02, 03, 04
2. Compare results to identify best performer
3. Document any variance (silicon lottery)
4. Prepare for expanded benchmark suite

## Troubleshooting

### Python/Poetry Issues

```powershell
# Verify Python
python --version  # Should be 3.11.x

# Verify Poetry
poetry --version

# Recreate Poetry environment
cd C:\benchmarks\markbench
poetry env remove python
poetry install
```

### Rocket League Issues

```powershell
# Verify game installation
ls "C:\Program Files\Epic Games\rocketleague"

# Check settings file exists
ls "$env:USERPROFILE\Documents\My Games\Rocket League\TAGame\Config\TASystemSettings.ini"
```

### Firewall Issues

```powershell
# Test MS-01 connectivity
Test-NetConnection -ComputerName 192.168.4.X -Port 8080
```

## Quick Reference

**MarkBench Location:** `C:\benchmarks\markbench`

**Activate Poetry Environment:**
```powershell
cd C:\benchmarks\markbench
poetry shell
```

**Run Rocket League Benchmark:**
```powershell
cd rocket_league
python rocket_league.py --kerasHost 192.168.4.X --kerasPort 8080
```

**MS-01 Keras OCR Health Check:**
```powershell
curl http://192.168.4.X:8080/health
```
