# VTT Hardware Benchmarks - Readiness Report
**Generated:** 2026-01-23
**Testing Order:** Windows First → Linux → MS-01 Setup

## Testing Phase Plan

**Phase 1: Local Testing (Current Priority)**
1. HP ZBook #1 - Windows local AI benchmarks
2. Framework Desktop - Linux validation

**Phase 2: MS-01 Central Tracking (After Phase 1 Complete)**
3. Deploy MLflow stack to MS-01
4. HP ZBooks #2-4 with central results tracking

**Phase 3: Gaming Benchmarks (Deferred)**
5. Keras OCR deployment
6. Rocket League, Cinebench, LTT tests

---

## 🪟 Windows HP ZBook Setup (TEST FIRST)

### Environment Validation: **PASSED** ✓

- **Container Runtime:** Podman 5.7.1 ✓
- **Model Directory:** `/mnt/ai-models` exists ✓
- **GPU Access:** `/dev/dri` and `/dev/kfd` available ✓
- **Disk Space:** 395GB available ✓
- **Configuration:** `model-config.yaml` valid ✓
- **Config Parser:** Available and functional ✓

### Model Availability: **READY** ✓

**Total GGUF Files:** 33 models available

**Default 5 Models Status:**
1. ✅ **DeepSeek-R1-Distill-Llama-70B** - 2 parts (47GB + 30GB = 77GB total)
2. ✅ **GLM-4.7-Flash-Q8** - 1 part (33GB)
3. ✅ **MiniMax-M2.1** - 2 parts (47GB + 34GB = 81GB total)
4. ✅ **Qwen3-235B-A22B-Instruct** - 3 parts (47GB + 47GB + 4.2GB = 98GB total)
5. ✅ **GPT-OSS-20B** - 1 part (13GB)

All configured models are present and ready for testing.

### Container Images: **BUILT** ✓

Available containers:
- ✅ `vtt-benchmark-7zip:latest` (local)
- ✅ `vtt-benchmark-stream:latest` (local)
- ✅ `vtt-benchmark-storage:latest` (local)
- ✅ `vtt-benchmark-llama:latest` (local)
- ✅ `ghcr.io/vvautosports/vtt-hw-benchmarks/vtt-benchmark-7zip:latest` (GHCR)

**Note:** All required containers are built locally. Additional images can be pulled from GHCR if needed.

### Run After Windows Test Succeeds

**Quick validation (2-3 min):**
```bash
cd docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test
```

**Full default test (30-45 min):**
```bash
cd docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

Results save to `results/linux/framework-desktop/`

**All models test (2-3 hours):**
```bash
cd docker
MODEL_CONFIG_MODE=all ./run-ai-models.sh
```

---

## 🪟 Windows HP ZBook Setup Readiness

### Prerequisites Checklist

#### 1. WSL2 Installation
- [ ] **Status:** Needs verification on Windows machine
- [ ] **Action:** Run `wsl --status` to check
- [ ] **If missing:** Run `wsl --install` (requires restart)
- [ ] **Automated setup:** `scripts/utils/setup-windows.ps1 -CheckOnly` to verify

#### 2. Docker in WSL2
- [ ] **Status:** Needs installation on Windows machine
- [ ] **Action:** Run `wsl bash -c "docker --version"` to check
- [ ] **If missing:** Run `scripts/utils/setup-windows.ps1` (PowerShell as Admin)
- [ ] **Manual install:** `curl -fsSL https://get.docker.com | sudo sh` in WSL2

#### 3. Model Directory Access
- [ ] **Status:** Needs configuration
- [ ] **Windows path:** `D:\ai-models` (or wherever models are stored)
- [ ] **WSL2 path:** `/mnt/d/ai-models` (auto-mounted)
- [ ] **Action:** Verify models accessible: `wsl ls /mnt/d/ai-models`
- [ ] **Configure:** Set `MODEL_DIR=/mnt/d/ai-models` in WSL2 `.bashrc`

#### 4. GPU Access (AMD Strix Halo)
- [ ] **Status:** Needs verification
- [ ] **Requirements:**
  - Windows 11 or Windows 10 21H2+
  - Latest AMD drivers installed
  - GPU-P (GPU Paravirtualization) enabled
- [ ] **Verify:** `wsl ls -l /dev/dri /dev/kfd`
- [ ] **Note:** GPU passthrough may require additional Windows configuration

### Windows Setup Script

**Automated setup available:**
```powershell
# Run as Administrator
cd C:\repos\vtt-hw-benchmarks
.\scripts\utils\setup-windows.ps1
```

**Check status only:**
```powershell
.\scripts\utils\setup-windows.ps1 -CheckOnly
```

### Windows Test Commands

Once WSL2 and Docker are set up:

```bash
# In WSL2 terminal
cd /mnt/c/repos/vtt-hw-benchmarks/docker
export MODEL_DIR=/mnt/d/ai-models  # Adjust if models on different drive
MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test
```

### Documentation References

- **Windows Setup Guide:** `docs/guides/WINDOWS-SETUP.md`
- **Quick Start:** `docs/guides/QUICK-START.md`
- **Configuration:** `docs/guides/CONFIGURATION.md`

---

---

## 📊 Summary & Testing Order

### Phase 1: Local Testing (No MS-01 Dependency)

#### 1. Windows HP ZBook #1 - **TEST FIRST**
- ✅ Setup scripts ready (`setup-windows-full.ps1`)
- ✅ Validation script ready (`Test-Windows-Setup.ps1`)
- ⚠️ Needs execution on Windows machine
- **Action:** Run on HP ZBook: `.\scripts\utils\setup-windows-full.ps1`
- Results save to: `results/windows/hp-zbook-01/`

#### 2. Linux Framework Desktop - **TEST SECOND**
- ✅ Environment validated and passing
- ✅ All 5 default models present
- ✅ Containers built and ready
- **Action:** After Windows succeeds, run: `MODEL_CONFIG_MODE=default ./run-ai-models.sh`
- Results save to: `results/linux/framework-desktop/`

### Phase 2: MS-01 Setup (After Phase 1)

**Deploy MLflow after both Windows and Linux working:**
- MS-01 MLflow stack deployment
- Central results tracking
- HP ZBooks #2-4 testing with central tracking

**See:** `docs/NEXT-PHASE.md` for Phase 2 & 3 details

### 🎯 Immediate Next Steps

1. **HP ZBook #1: Run Windows setup**
   ```powershell
   # On HP ZBook, as Administrator
   cd C:\repos\vtt-hw-benchmarks
   .\scripts\utils\setup-windows-full.ps1
   ```

2. **Validate Windows setup**
   ```powershell
   .\scripts\testing\Test-Windows-Setup.ps1 -FullTest
   ```

3. **After Windows working: Test Framework Desktop**
   ```bash
   # On Framework
   cd docker
   MODEL_CONFIG_MODE=default ./run-ai-models.sh
   ```

4. **Commit results from both machines**
   ```bash
   git add results/
   git commit -m "results: HP ZBook #1 and Framework initial tests"
   ```

5. **Then proceed to Phase 2: MS-01 MLflow setup**

---

## 🔍 Additional Notes

- **Model count:** 33 GGUF files total (more than the 5 default models)
- **Multi-part models:** Scripts handle multi-part models correctly
- **Container registry:** Images available on GHCR for pulling on Windows
- **Validation script:** `scripts/utils/validate-environment.sh` can be run on Windows via WSL2

---

**Last Updated:** 2026-01-23  
**Current Phase:** Phase 1 - Local Testing (Windows First)  
**Next Steps:** Run `setup-windows-full.ps1` on HP ZBook #1
