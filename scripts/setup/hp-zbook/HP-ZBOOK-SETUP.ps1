# VTT Hardware Benchmark Suite - Automated Setup
# Simple entry point for Windows deployment
# Usage: .\HP-ZBOOK-SETUP.ps1

$ErrorActionPreference = "Continue"  # Don't stop on errors, handle them

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmark Suite" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or run:" -ForegroundColor Yellow
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-File', '.\HP-ZBOOK-SETUP.ps1'" -ForegroundColor Gray
    exit 1
}

# Check if git is installed
$gitInstalled = $false
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $gitInstalled = $true
        Write-Host "[OK] Git is installed: $gitVersion" -ForegroundColor Green
    }
} catch {
    $gitInstalled = $false
}

if (-not $gitInstalled) {
    Write-Host "Git is not installed. Installing via winget..." -ForegroundColor Yellow
    try {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Write-Host "[OK] Git installed successfully" -ForegroundColor Green
        Write-Host "Refreshing PATH..." -ForegroundColor Gray
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        # Verify git is now available
        $gitVersion = git --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: Git installed but not in PATH. Please restart PowerShell and try again." -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Host "ERROR: Could not install git automatically" -ForegroundColor Red
        Write-Host "Please install git manually:" -ForegroundColor Yellow
        Write-Host "  winget install --id Git.Git -e --source winget" -ForegroundColor Gray
        Write-Host "Or download from: https://git-scm.com/download/win" -ForegroundColor Gray
        Write-Host "Then run this script again." -ForegroundColor Yellow
        exit 1
    }
}

# Get repo root (script is in scripts/setup/hp-zbook/, so go up 3 levels)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir))

if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Host "ERROR: Not in vtt-hw-benchmarks repository" -ForegroundColor Red
    Write-Host ""
    Write-Host "The repository is private and requires authentication." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Use GitHub CLI (Recommended)" -ForegroundColor Cyan
    Write-Host "  1. Install: winget install --id GitHub.cli" -ForegroundColor Gray
    Write-Host "  2. Authenticate: gh auth login" -ForegroundColor Gray
    Write-Host "  3. Clone: gh repo clone vvautosports/vtt-hw-benchmarks" -ForegroundColor Gray
    Write-Host "  4. Run: cd vtt-hw-benchmarks; .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2: Use Personal Access Token" -ForegroundColor Cyan
    Write-Host "  1. Create token: https://github.com/settings/tokens (scope: repo)" -ForegroundColor Gray
    Write-Host "  2. Clone: git clone https://TOKEN@github.com/vvautosports/vtt-hw-benchmarks.git" -ForegroundColor Gray
    Write-Host "  3. Run: cd vtt-hw-benchmarks; .\HP-ZBOOK-SETUP.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 3: Use SSH" -ForegroundColor Cyan
    Write-Host "  1. Set up SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh" -ForegroundColor Gray
    Write-Host "  2. Clone: git clone git@github.com:vvautosports/vtt-hw-benchmarks.git" -ForegroundColor Gray
    Write-Host "  3. Run: cd vtt-hw-benchmarks; .\HP-ZBOOK-SETUP.ps1" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

$setupScript = Join-Path $repoRoot "scripts\utils\Setup-HP-ZBook-Automated.ps1"

if (-not (Test-Path $setupScript)) {
    Write-Host "ERROR: Setup script not found: $setupScript" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure you're running this from the vtt-hw-benchmarks directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting automated setup..." -ForegroundColor Green
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  [OK] Install WSL2 (if needed, requires restart)" -ForegroundColor Gray
Write-Host "  [OK] Install Docker in WSL2" -ForegroundColor Gray
Write-Host "  [OK] Pull containers from GHCR" -ForegroundColor Gray
Write-Host "  [OK] Download light models" -ForegroundColor Gray
Write-Host "  [OK] Run validation test" -ForegroundColor Gray
Write-Host ""

# Check for D: drive, use C: if not available
$modelPath = "D:\ai-models"
if (-not (Test-Path "D:\")) {
    Write-Host "D: drive not found, using C:\ai-models instead" -ForegroundColor Yellow
    $modelPath = "C:\ai-models"
}

Write-Host "Model path: $modelPath" -ForegroundColor Gray
Write-Host ""

# Run the setup script
try {
    & $setupScript -ModelPath $modelPath -NonInteractive
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host "  Setup Complete!" -ForegroundColor Green
        Write-Host "=================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  Run lite test: .\scripts\testing\Test-Windows-Short.ps1" -ForegroundColor White
        Write-Host "  Or run full benchmark:" -ForegroundColor White
        Write-Host "    wsl" -ForegroundColor Gray
        Write-Host "    cd /mnt/c/repos/vtt-hw-benchmarks/docker" -ForegroundColor Gray
        Write-Host "    MODEL_CONFIG_MODE=default ./run-ai-models.sh" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Setup completed with warnings or requires restart" -ForegroundColor Yellow
        Write-Host "Check the output above for next steps" -ForegroundColor Yellow
    }
} catch {
    Write-Host ""
    Write-Host "ERROR: Setup failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check network connection" -ForegroundColor White
    Write-Host "  2. Ensure Windows is up to date" -ForegroundColor White
    Write-Host "  3. Try running: .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP.ps1" -ForegroundColor Gray
    exit 1
}
