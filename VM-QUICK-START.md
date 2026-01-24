# Windows VM Testing - Quick Reference

**VM Status:** ✅ Running  
**IP Address:** 192.168.122.234  
**Connection:** `virt-viewer windows11-vtt-test`

## Connect to VM

**Option 1: VNC (Recommended)**
```bash
# VNC is running on localhost:5900 (display :0)
vncviewer localhost:5900

# Or use any VNC client:
# - Remmina (GUI)
# - TigerVNC
# - RealVNC
# Connect to: localhost:5900
```

**Option 2: virt-viewer (if it works)**
```bash
virt-viewer windows11-vtt-test
```

## In Windows VM (PowerShell as Admin)

```powershell
# 1. Install Git and GitHub CLI (can install both at once)
winget install --id Git.Git --id GitHub.cli --source winget

# OR install sequentially (also works fine):
# winget install --id Git.Git --source winget
# winget install --id GitHub.cli --source winget

# IMPORTANT: Open a NEW PowerShell window/tab after installations
# (PATH needs to refresh for 'git' and 'gh' commands to be available)

# 3. In the new PowerShell window, authenticate
gh auth login

# 4. Clone and setup
gh repo clone vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1

# Select option 5: "Do everything automatically"

# 5. Run validation test (after setup)
.\scripts\testing\Test-Windows-Short.ps1
```

## Monitor from Host (Optional)

```bash
# Dedicated monitoring script (recommended)
./scripts/vm/monitor-vm.sh

# Or simple watch command
watch -n 1 'virsh -c qemu:///system domstats windows11-vtt-test | grep -E "(cpu\.|balloon\.)"'
```

## Expected Timeline

- Model download: 10-15 minutes (22GB from HuggingFace)
- WSL2/Docker setup: 5-10 minutes
- Validation test: 2-3 minutes
- **Total: 17-28 minutes**

**Note:** Downloads light models (GPT-OSS-20B + Qwen3-8B) to test actual HP deployment process.

## Success = Ready for HP ZBooks

✅ Validation test passes  
✅ Benchmark shows >500 t/s  
✅ Setup scripts proven to work

---

**Full guide:** `docs/testing/windows-vm/VM-TESTING-GUIDE.md`
