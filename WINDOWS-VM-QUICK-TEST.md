# Windows VM Quick Test - Minimal Downloads

**Test setup scripts without downloading large AI models**

## Quick Test Commands

### 1. Setup Only (No Tests, No Large Downloads)

```powershell
# Run as Administrator
cd C:\repos\vtt-hw-benchmarks
.\scripts\utils\setup-windows-full.ps1 -SkipTests -SkipContainers
```

**Downloads:** ~100MB (Docker only)
**Time:** 5-10 minutes
**Installs:**
- WSL2 (may require restart)
- Docker in WSL2
- Model directory configuration

### 2. Validate Setup

```powershell
.\scripts\testing\Test-Windows-Setup.ps1
```

**Downloads:** 0 bytes
**Time:** <1 minute
**Checks:**
- WSL2 working
- Docker running
- Environment configured

### 3. Pull Containers (Optional)

```bash
# In WSL2
cd /mnt/c/repos/vtt-hw-benchmarks
./scripts/ci-cd/pull-from-ghcr.sh
```

**Downloads:** ~500MB (4 containers)
**Time:** 2-5 minutes

### 4. Test Containers (No Models)

```bash
# In WSL2
cd /mnt/c/repos/vtt-hw-benchmarks/docker
docker run --rm vtt-benchmark-7zip
docker run --rm vtt-benchmark-stream
docker run --rm vtt-benchmark-storage
```

**Downloads:** 0 bytes (containers already pulled)
**Time:** 2 minutes total

## Success Criteria

✅ **Setup script completes without errors**
✅ **WSL2 installed and working**
✅ **Docker installed and running**
✅ **Validation script passes**
✅ **Non-AI containers run successfully**

## Then Test on Real Hardware

After VM validation passes:
1. Commit setup scripts
2. Test on actual HP ZBook with models
3. Run full benchmark suite

**VM testing = validate setup process**
**Real hardware = validate performance**
