# Windows VM Testing Guide - Phase 2

**Status:** VM running and ready  
**Date:** 2026-01-24  
**Purpose:** Validate Windows setup before HP ZBook deployment

## VM Connection

**Connect to VM:**
```bash
virt-viewer windows11-vtt-test
```

Or use `virt-manager` GUI for graphical access.

## Testing Sequence (15-25 minutes total)

### Step 1: Initial Setup in VM (5 minutes)

**In Windows VM (PowerShell as Administrator):**

```powershell
# Check if GitHub CLI is installed
gh --version

# If not installed:
winget install --id GitHub.cli

# Authenticate with GitHub
gh auth login
# Follow prompts:
# - Select GitHub.com
# - Select HTTPS
# - Authenticate via browser
# - Login with your HP Windows account

# Clone repository
gh repo clone vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks

# Verify you're in the right place
ls scripts/setup/hp-zbook/
```

### Step 2: Run Interactive Setup (10-15 minutes)

**Option A: Automatic (Recommended)**

```powershell
# Run interactive setup script
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1

# Select option 5: "Do everything automatically"
# This will:
# - Install WSL2 (if needed)
# - Install Docker Desktop
# - Pull AI model containers
# - Download test models
# - Configure GPU access
```

**Option B: Manual (Step-by-step)**

If you prefer to see each step:
- Option 1: Install GitHub CLI ✓ (already done)
- Option 2: Authenticate ✓ (already done)
- Option 3: Clone repository ✓ (already done)
- Option 4: Run setup script

### Step 3: Run Validation Test (2-3 minutes)

After setup completes:

```powershell
# Run short test
.\scripts\testing\Test-Windows-Short.ps1
```

**What this tests:**
1. Setup validation (WSL2, Docker, containers)
2. Quick benchmark (GLM-4.7-Flash-Q8, 512p/128g)
3. Model access and GPU acceleration

**Expected output:**
```
═══════════════════════════════════════════════════════════════
  Test Summary
═══════════════════════════════════════════════════════════════

✅ All tests passed! (2/2)

Windows setup is validated and ready for HP ZBook testing!
```

## Monitoring VM from Host (Optional)

**In a separate terminal on Linux host:**

```bash
# Monitor VM resource usage
watch -n 1 'virsh -c qemu:///system domstats windows11-vtt-test | grep -E "(cpu\.|balloon\.)"'

# Or use graphical interface
virt-manager
```

## Expected Timeline

| Phase | Duration | What happens |
|-------|----------|--------------|
| Initial setup | 5 min | GitHub auth, clone repo |
| Automated setup | 10-15 min | WSL2, Docker, containers, models |
| Validation test | 2-3 min | Quick benchmark |
| **Total** | **17-23 min** | Complete validation |

## Success Criteria

- ✅ GitHub CLI installed and authenticated
- ✅ Repository cloned
- ✅ WSL2 installed and configured
- ✅ Docker Desktop installed and running
- ✅ AI model containers pulled
- ✅ Quick benchmark completes successfully
- ✅ Results show >500 t/s prompt processing

## Troubleshooting

### GitHub CLI not found
```powershell
# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Try again
gh --version
```

### WSL2 installation requires reboot
```powershell
# If setup script prompts for reboot:
Restart-Computer

# After reboot, continue from Step 2
```

### Docker Desktop not starting
```powershell
# Check Windows features
dism.exe /online /get-features | findstr /i "virtual"

# Ensure virtualization is enabled in BIOS
```

## After VM Testing Succeeds

Once validation passes:

1. **Document results** (copy benchmark output)
2. **Shutdown VM** (from Linux host):
   ```bash
   virsh -c qemu:///system shutdown windows11-vtt-test
   ```
3. **Proceed to HP ZBook** with confidence that setup works

## VM vs HP ZBook Differences

**VM testing proves:**
- ✅ Setup scripts work
- ✅ WSL2 configuration is correct
- ✅ Docker containers run properly
- ✅ Model access and inference works

**HP ZBook testing will add:**
- Native Windows performance (no VM overhead)
- Full GPU acceleration (dedicated iGPU access)
- Silicon lottery comparison across multiple units
- Production-ready deployment validation

## Next Steps

After successful VM test:
1. Save VM state (snapshot recommended)
2. Use same process on HP ZBook
3. Compare VM vs native performance
4. Deploy to remaining HP ZBooks

---

**Current Status:**
- [x] VM created and configured
- [x] VM started (running now)
- [ ] **YOU ARE HERE:** Connect and run tests
- [ ] Validate results
- [ ] Deploy to HP ZBooks
