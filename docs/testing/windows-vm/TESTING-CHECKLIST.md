# Windows VM Testing Checklist

Quick reference checklist for testing in Windows VM.

## Pre-Test Verification

- [ ] VM has Windows 11 installed
- [ ] Repository cloned: `C:\vtt-hw-benchmarks`
- [ ] GitHub CLI authenticated: `gh auth status`

## Setup Testing

### Option A: Docker Desktop Approach

1. [ ] Run `SETUP.bat` as Administrator
2. [ ] Verify prerequisites check passes
3. [ ] Verify Docker Desktop installs (if needed)
4. [ ] Verify containers pull successfully
5. [ ] Run validation test from menu

### Option B: WSL2 Direct Approach

1. [ ] Run `setup-windows-full.ps1` as Administrator
2. [ ] Verify WSL2 installs (restart if needed)
3. [ ] Verify Docker installs in WSL2
4. [ ] Verify containers pull/build successfully

## Model Download Testing

1. [ ] Run `Download-Light-Models.ps1 -ModelPath "D:\ai-models"`
2. [ ] Verify GPT-OSS-20B downloads (13GB)
3. [ ] Verify Qwen3-8B-128K-Q8 downloads (9GB)
4. [ ] Verify models accessible in WSL2: `ls /mnt/d/ai-models`

## AI Testing Validation

**Using SETUP.bat (Recommended):**

1. [ ] Run `SETUP.bat` as Administrator
2. [ ] Select option 2: "Run validation test"
3. [ ] Verify validation passes
4. [ ] Select option 3: "Run quick benchmark" (optional, 5-10 min in VM)
5. [ ] Verify benchmark completes successfully
6. [ ] Verify results saved to `results/` directory

**Manual Testing (Alternative):**

1. [ ] Run `Test-Windows-Short.ps1`
2. [ ] Verify all checks pass
3. [ ] Verify benchmark completes successfully

## Manual AI Test

```powershell
# In PowerShell
wsl

# In WSL2
cd /mnt/c/vtt-hw-benchmarks/docker
MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test
```

**Expected:**
- Test completes (5-10 minutes in VM, CPU-only)
- Results saved to `results/` directory
- Performance much slower than native (expected)

## Issues to Document

If you encounter any issues, document:
- Error messages
- Which step failed
- Workarounds found
- Update guide with solutions

## Success Criteria

- [ ] All setup scripts work
- [ ] Models download successfully
- [ ] Containers accessible
- [ ] AI benchmark runs (even if slow)
- [ ] Results saved correctly
- [ ] Ready for physical HP ZBook deployment

---

**After successful VM testing:**
1. Commit and push all changes
2. Proceed with physical HP ZBook deployment
3. Run Linux baseline on Framework desktop
