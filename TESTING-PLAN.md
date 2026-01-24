# Testing Plan - Quick Reference

**Priority:** Windows First → Linux → MS-01 Setup

## Phase 1: Local Testing (Current)

### Step 1: HP ZBook #1 (Windows)

**On HP ZBook, PowerShell as Administrator:**
```powershell
cd C:\repos\vtt-hw-benchmarks
.\scripts\utils\setup-windows-full.ps1
```

**Validate:**
```powershell
.\scripts\testing\Test-Windows-Setup.ps1 -FullTest
```

**Run benchmarks:**
```bash
# In WSL2
cd /mnt/c/repos/vtt-hw-benchmarks/docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

**Results:** `results/windows/hp-zbook-01/`

### Step 2: Framework Desktop (Linux)

**After Windows succeeds:**
```bash
cd docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

**Results:** `results/linux/framework-desktop/`

### Step 3: Commit Results

```bash
git add results/
git commit -m "results: HP ZBook #1 and Framework initial tests"
git push
```

## Phase 2: MS-01 MLflow (After Phase 1)

1. Deploy MLflow to MS-01
2. Test HP ZBooks #2-4 with central tracking
3. Compare all machines in dashboard

## Phase 3: Gaming (Deferred)

- Keras OCR for Rocket League
- Cinebench
- LTT MarkBench tests

**See:** `docs/NEXT-PHASE.md` for complete details

## Key Files

- [`READINESS-REPORT.md`](READINESS-REPORT.md) - Detailed status
- [`docs/NEXT-PHASE.md`](docs/NEXT-PHASE.md) - Future phases
- [`scripts/utils/setup-windows-full.ps1`](scripts/utils/setup-windows-full.ps1) - Windows setup
- [`scripts/testing/Test-Windows-Setup.ps1`](scripts/testing/Test-Windows-Setup.ps1) - Validation
- [`results/`](results/) - All test results

## Current Status

- ✅ Documentation updated
- ✅ Scripts ready
- ⏳ Ready to start Phase 1: Windows testing
