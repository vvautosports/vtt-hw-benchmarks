# HP ZBook Setup Guide

Complete setup guide for HP ZBook laptops running Windows 11.

## Quick Start

**The repository is private - authentication is required first.**

### Getting Setup Instructions Without Full Access

If you need setup instructions before authenticating, you can fetch them:

**Option 1: Use the fetch script (requires GitHub CLI or token)**
```powershell
# Download and run the fetch script
powershell -ExecutionPolicy Bypass -File .\scripts\utils\Fetch-Setup-Instructions.ps1
# Instructions will be saved to setup-instructions.md
```

**Option 2: View in browser**
- README: https://github.com/vvautosports/vtt-hw-benchmarks/blob/master/README.md
- Setup Guide: https://github.com/vvautosports/vtt-hw-benchmarks/blob/master/docs/guides/HP-ZBOOK-SETUP.md

**Option 3: Quick start script**
```powershell
# Download GET-STARTED.ps1 from the repository and run:
powershell -ExecutionPolicy Bypass -File .\GET-STARTED.ps1
```

### PowerShell Execution Policy

Windows PowerShell has a security feature that blocks unsigned scripts by default. If you encounter an execution policy error, use one of these methods:

**Option 1: Run SETUP.bat (Recommended)**
Right-click `scripts\setup\hp-zbook\SETUP.bat` → Run as Administrator

**Option 2: Set execution policy (requires Administrator)**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
This allows locally created scripts to run. After setting this, you can run scripts normally.

**Note:** The `-ExecutionPolicy Bypass` flag is safe for one-time script execution and doesn't change system settings.

### Simplest Path: Clone and Run Interactive Menu

```powershell
# PowerShell as Administrator

# Step 1: Install Git for Windows (required)
winget install --id Git.Git --source winget

# Step 2: Install GitHub CLI
winget install --id GitHub.cli --source winget

# ⚠️ IMPORTANT: Open a NEW PowerShell window/tab after installations

# Step 3: In the new PowerShell window, authenticate (opens browser)
gh auth login

# Step 4: Clone and run setup
gh repo clone vvautosports/vtt-hw-benchmarks; cd vtt-hw-benchmarks
```

# Step 5: Run Setup

Right-click `scripts\setup\hp-zbook\SETUP.bat` → Run as Administrator

The interactive menu will guide you through the rest!

### Step-by-Step Breakdown

**1. Install Git for Windows** (required for `gh repo clone`)
```powershell
winget install --id Git.Git --source winget
```

**2. Install GitHub CLI**
```powershell
winget install --id GitHub.cli --source winget
```

**⚠️ After installations: Open a NEW PowerShell window/tab** (PATH needs to refresh)

**3. Authenticate with GitHub** (in the new PowerShell window)
```powershell
gh auth login
# Follow the browser prompts
```

**4. Clone the Repository**
```powershell
gh repo clone vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks
```

**4. Run Setup**

Right-click `scripts\setup\hp-zbook\SETUP.bat` → Run as Administrator

**Alternative: WSL2 Direct Setup**
If you prefer WSL2 direct setup (without Docker Desktop):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\utils\setup-windows-full.ps1
```

**Note:** If you've already set the execution policy (see above), you can omit the `-ExecutionPolicy Bypass` flag.

That's it! The script will:
- ✅ Install git automatically (if needed)
- ✅ Install WSL2 (if needed, may require restart)
- ✅ Install Docker in WSL2
- ✅ Pull containers from GHCR
- ✅ Download light models
- ✅ Run validation test

**Total time:** 15-25 minutes (plus restart if WSL2 needed)

---

## If Git is Not Installed

If the command fails because git isn't installed, run this first:

```powershell
winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
```

Then run the setup command above.

---

## After Setup

### Run Lite Test (2-3 minutes)
```powershell
.\scripts\testing\Test-Windows-Short.ps1
```

### Run Full Benchmark (30-45 minutes)
```bash
# In WSL2
cd /mnt/c/vtt-hw-benchmarks/docker
MODEL_CONFIG_MODE=default ./run-ai-models.sh
```

---

## If WSL2 Installation Requires Restart

1. Restart when prompted
2. After restart, run:
```powershell
cd C:\vtt-hw-benchmarks
Right-click `scripts\setup\hp-zbook\SETUP.bat` → Run as Administrator
```

---

---

## Git Authentication

### For Cloning (Required)
- **Authentication required** - repository is private
- Use one of the methods above (GitHub CLI, PAT, or SSH)

### For Pushing Results
If you want to push benchmark results back to the repository:

1. **Set up git credentials:**
   ```powershell
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **Authenticate with GitHub:**
   - Use GitHub CLI: `gh auth login`
   - Or use Personal Access Token: `git remote set-url origin https://TOKEN@github.com/vvautosports/vtt-hw-benchmarks.git`
   - Or use SSH keys (recommended for frequent use)

3. **Push results:**
   ```bash
   # In WSL2
   cd /mnt/c/vtt-hw-benchmarks
   git add results/
   git commit -m "results: HP ZBook benchmark results"
   git push
   ```

**Note:** Pushing results is optional. You can save results locally without pushing.

---

**That's it!** One command, fully automated.
