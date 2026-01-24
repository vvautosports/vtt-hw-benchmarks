# HP ZBook Setup Guide

Complete setup guide for HP ZBook laptops running Windows 11.

## Quick Start

**The repository is private - authentication is required first.**

### Simplest Path: Clone and Run Interactive Menu

```powershell
# PowerShell as Administrator

# Step 1: Install GitHub CLI (if needed)
winget install --id GitHub.cli

# Step 2: Authenticate (opens browser)
gh auth login

# Step 3: Clone and run interactive menu
gh repo clone vvautosports/vtt-hw-benchmarks; cd vtt-hw-benchmarks; .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1
```

The interactive menu will guide you through the rest!

### Alternative: One-Command Automatic

If you prefer fully automatic setup:

```powershell
# After installing gh CLI and authenticating:
gh repo clone vvautosports/vtt-hw-benchmarks; cd vtt-hw-benchmarks; .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-ONE-COMMAND.ps1
```

This does everything automatically without the menu.

### Step-by-Step Breakdown

**1. Install GitHub CLI**
```powershell
winget install --id GitHub.cli
```

**2. Authenticate with GitHub**
```powershell
gh auth login
# Follow the browser prompts
```

**3. Clone the Repository**
```powershell
gh repo clone vvautosports/vtt-hw-benchmarks
cd vtt-hw-benchmarks
```

**4. Run Setup (Choose One)**

**Interactive Menu (Recommended):**
```powershell
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1
```
Shows a menu with status indicators - you can do steps individually or choose "do everything automatically"

**One-Command Automatic:**
```powershell
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-ONE-COMMAND.ps1
```
Runs everything automatically without prompts

**Basic Setup:**
```powershell
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP.ps1
```
Assumes repo is already cloned, just runs the setup

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
.\scripts\setup\hp-zbook\HP-ZBOOK-SETUP.ps1
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
