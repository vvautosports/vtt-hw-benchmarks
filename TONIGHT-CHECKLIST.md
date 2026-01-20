# Tonight's Testing Checklist - HP ZBook 01

Quick reference for getting first benchmark results tonight.

## Pre-Test Setup

### On MS-01
- [ ] Deploy Keras OCR service
  ```bash
  cd /home/kalman9/repos/virtual-velocity-collective/vvautosports/vtt-hw-benchmarks
  ./scripts/deploy-keras-ocr.sh
  ```
- [ ] Note MS-01 IP address: `_________________`
- [ ] Verify service: `curl http://localhost:8080/health`

### On HP ZBook (Windows)
- [ ] Install Python 3.11: `winget install Python.Python.3.11`
- [ ] Install Poetry: `pip install poetry`
- [ ] Install Epic Games Launcher
- [ ] Install Rocket League (free via Epic)
- [ ] Clone MarkBench: `git clone https://github.com/LTTLabsOSS/markbench-tests C:\benchmarks\markbench`
- [ ] Install dependencies: `cd C:\benchmarks\markbench && poetry install`
- [ ] Download Cinebench R23
- [ ] Gather system info: `.\scripts\hp-zbook-sysinfo.ps1`

---

## Rocket League Setup

- [ ] Launch Rocket League once
- [ ] Settings → Video:
  - [ ] Resolution: 1920x1080
  - [ ] Display Mode: Fullscreen
  - [ ] Render Quality: High Quality
  - [ ] FPS: Uncapped
  - [ ] Vertical Sync: Off
- [ ] Exit properly (Menu → Exit, NOT Alt+F4)
- [ ] Verify MS-01 connectivity: `curl http://[MS-01-IP]:8080/health`

---

## Run Benchmarks

### Rocket League
```powershell
cd C:\benchmarks\markbench
poetry shell
cd rocket_league
python rocket_league.py --kerasHost [MS-01-IP] --kerasPort 8080
```

**During test:**
- [ ] Observe FPS (note average)
- [ ] Watch for stuttering
- [ ] Listen for fan noise
- [ ] Note any thermal throttling

**Results to record:**
- Average FPS: `_________________`
- Min FPS: `_________________`
- Max FPS: `_________________`
- Issues: `_________________`

### Cinebench R23

- [ ] Launch Cinebench R23
- [ ] Click "Run" for Multi-Core test
- [ ] Wait ~10 minutes
- [ ] Record score: `_________________`
- [ ] Optional: Run Single-Core test
- [ ] Single-Core score: `_________________`

---

## Document Results

- [ ] Copy template: `cp results/hp-zbook-template.md results/hp-zbook-01-20260119.md`
- [ ] Fill in system specifications
- [ ] Add benchmark results
- [ ] Add observations and notes
- [ ] Save file

---

## Validation

- [ ] Git repo has commits
- [ ] Keras OCR is running and accessible
- [ ] Rocket League benchmark completed
- [ ] Cinebench score captured
- [ ] Results file created and filled out
- [ ] At least one HP ZBook fully tested

---

## Time Estimates

- MS-01 setup: 10 min
- HP ZBook software install: 30 min
- Rocket League config: 10 min
- Running benchmarks: 20 min
- Documentation: 10 min

**Total: ~90 minutes**

---

## Troubleshooting Quick Reference

**Keras OCR not accessible:**
```bash
# On MS-01
docker ps | grep keras-ocr
docker logs keras-ocr

# Check firewall
sudo firewall-cmd --list-ports
```

**Rocket League won't launch:**
- Verify Epic Games Launcher is running
- Check game installation path exists
- Try launching manually first

**Python/Poetry issues:**
```powershell
python --version  # Should be 3.11.x
poetry --version
cd C:\benchmarks\markbench
poetry install
```

**Network connectivity:**
```powershell
Test-NetConnection -ComputerName [MS-01-IP] -Port 8080
ping [MS-01-IP]
```

---

## Next Steps After Tonight

- [ ] Test remaining HP ZBooks (02, 03, 04)
- [ ] Compare results
- [ ] Identify best performer
- [ ] Expand benchmark suite
- [ ] Add automation scripts
- [ ] Set up database (Supabase)

---

## Notes / Issues

```
[Space for your notes during testing]









```
