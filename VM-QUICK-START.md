# Windows VM Testing - Quick Reference

**VM Status:** ✅ Running  
**IP Address:** 192.168.122.234  
**Connection:** `virt-viewer windows11-vtt-test`

## Connect to VM

```bash
virt-viewer windows11-vtt-test
```

## In Windows VM (PowerShell as Admin)

```powershell
# 1. Install GitHub CLI (if needed)
winget install --id GitHub.cli

# 2. Authenticate
gh auth login

# 3. Clone and setup
gh repo clone vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1

# Select option 5: "Do everything automatically"

# 4. Run validation test (after setup)
.\scripts\testing\Test-Windows-Short.ps1
```

## Monitor from Host

```bash
# Watch VM stats
watch -n 1 'virsh -c qemu:///system domstats windows11-vtt-test | grep -E "(cpu\.|balloon\.)"'
```

## Expected Timeline

- Setup: 10-15 minutes
- Validation: 2-3 minutes
- **Total: 12-18 minutes**

## Success = Ready for HP ZBooks

✅ Validation test passes  
✅ Benchmark shows >500 t/s  
✅ Setup scripts proven to work

---

**Full guide:** `docs/testing/windows-vm/VM-TESTING-GUIDE.md`
