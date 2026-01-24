# Windows VM Testing Plan

**Goal:** Test Windows setup scripts in clean VM without downloading large models

## VM Setup (Quick)

### Option 1: Use Existing HP ZBook
- Already has Windows installed
- Just needs WSL2 and Docker
- No VM needed

### Option 2: Windows VM (If needed for testing)
- Download Windows 11 evaluation ISO from Microsoft
- 8GB RAM minimum
- 60GB disk
- Enable nested virtualization for WSL2

## Test Plan - Minimal Download

### Phase 1: Setup Script Test (No Models)

**Test:** Verify setup script installs WSL2 and Docker correctly

```powershell
# On Windows VM/machine
cd C:\repos\vtt-hw-benchmarks
.\scripts\utils\setup-windows-full.ps1 -SkipTests
```

**This will:**
- ✅ Install WSL2
- ✅ Install Docker in WSL2
- ✅ Configure model directory paths
- ✅ Pull benchmark containers (~500MB from GHCR)
- ❌ Skip running AI model tests (no model downloads)

**Validates:**
- WSL2 installation works
- Docker installation works
- Container pull works
- No large model downloads

### Phase 2: Validation Test (No AI Models)

**Test:** Run validation script without AI tests

```powershell
.\scripts\testing\Test-Windows-Setup.ps1
```

**This checks:**
- ✅ WSL2 installed
- ✅ Docker running
- ✅ Containers available
- ❌ Skips full benchmark run (use flag without `-FullTest`)

**Validates:**
- All components installed
- Ready for real testing
- No model downloads needed

### Phase 3: CPU/Memory Tests Only (No Models)

**Test:** Run non-AI benchmarks only

```bash
# In WSL2
cd /mnt/c/repos/vtt-hw-benchmarks/docker
podman run --rm vtt-benchmark-7zip      # CPU test (~30 sec)
podman run --rm vtt-benchmark-stream    # Memory test (~10 sec)
podman run --rm vtt-benchmark-storage   # Storage test (~30 sec)
```

**Downloads:** None (containers already pulled)
**Time:** ~2 minutes total
**Validates:** Docker/Podman working correctly

### Phase 4: Light Model Test (Optional - Small Download)

**Only if you want to test AI inference:**

Use light mode configuration (smallest models):

```bash
# In WSL2
cd /mnt/c/repos/vtt-hw-benchmarks/docker

# Create light model directory (optional)
mkdir -p /mnt/d/ai-models-test

# Download one small model (~8GB)
# GPT-OSS-20B or Qwen2.5-7B-Instruct-Q8

MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test
```

**Download:** ~8-13GB (one small model)
**Time:** ~5 min download + 2 min test
**Validates:** AI inference working

## Recommended Testing Order

### Minimal Test (No Downloads)
1. Run `setup-windows-full.ps1 -SkipTests`
2. Run `Test-Windows-Setup.ps1` (without -FullTest)
3. Run CPU/Memory/Storage tests manually
4. **Commit setup scripts as working**

### Full Test (With One Small Model)
5. Download one small model manually or via light mode
6. Run quick AI test
7. Commit full validation results

## Expected Downloads

### Minimal Test Path:
- WSL2: ~0 bytes (Windows downloads automatically)
- Docker: ~100MB (downloaded in WSL2)
- Containers: ~500MB (pulled from GHCR)
- **Total: ~600MB**

### Full Test Path (Optional):
- Add small model: ~8-13GB
- **Total: ~9-13GB**

### NOT NEEDED for VM testing:
- ❌ Default 5 models: ~300GB total
- ❌ All models: ~600GB+ total

## VM Test Success Criteria

✅ **Minimal Success (Commit-worthy):**
- WSL2 installs without errors
- Docker installs and starts
- Containers pull successfully
- Validation script passes (without -FullTest)
- CPU/Memory/Storage tests run

✅ **Full Success (Bonus):**
- One small model downloads
- AI inference test completes
- Results save to `results/` directory

## After VM Testing

Once VM test passes, test on actual HP ZBook with full model set.

VM testing just validates the setup scripts work correctly - actual performance testing happens on real hardware.
