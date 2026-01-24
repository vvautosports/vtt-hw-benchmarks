# Run Lite Test in Windows VM
# This script automates the complete setup and lite test process
# Usage: .\Run-Lite-Test-In-VM.ps1

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Windows VM - Automated Setup & Lite Test" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

if (-not (Test-Path "$repoRoot\scripts\utils\Setup-HP-ZBook-Automated.ps1")) {
    Write-Host "ERROR: Must run from vtt-hw-benchmarks repository" -ForegroundColor Red
    Write-Host "Current directory: $repoRoot" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Clone the repo first:" -ForegroundColor Yellow
    Write-Host "  git clone https://github.com/vvautosports/vtt-hw-benchmarks.git" -ForegroundColor Gray
    Write-Host "  cd vtt-hw-benchmarks" -ForegroundColor Gray
    exit 1
}

Set-Location $repoRoot

Write-Host "Repository: $repoRoot" -ForegroundColor Gray
Write-Host ""

# Step 1: Clone repo if needed (should already be done)
Write-Host "Step 1: Checking repository..." -ForegroundColor Yellow
if (-not (Test-Path ".git")) {
    Write-Host "Repository not found. Please clone it first:" -ForegroundColor Yellow
    Write-Host "  git clone https://github.com/vvautosports/vtt-hw-benchmarks.git" -ForegroundColor Gray
    Write-Host "  cd vtt-hw-benchmarks" -ForegroundColor Gray
    exit 1
}
Write-Host "✓ Repository found" -ForegroundColor Green
Write-Host ""

# Step 2: Run automated setup
Write-Host "Step 2: Running automated setup..." -ForegroundColor Yellow
Write-Host "This will install WSL2, Docker, and pull containers (10-20 minutes)" -ForegroundColor Gray
Write-Host ""

$setupScript = "$repoRoot\scripts\utils\Setup-HP-ZBook-Automated.ps1"
if (-not (Test-Path $setupScript)) {
    Write-Host "ERROR: Setup script not found: $setupScript" -ForegroundColor Red
    exit 1
}

try {
    & $setupScript -ModelPath "D:\ai-models" -NonInteractive
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Setup script failed" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
    Write-Host "✓ Setup completed successfully" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "ERROR: Setup failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Run lite test
Write-Host "Step 3: Running lite test..." -ForegroundColor Yellow
Write-Host "This validates setup and runs a quick benchmark (2-3 minutes)" -ForegroundColor Gray
Write-Host ""

$testScript = "$repoRoot\scripts\testing\Test-Windows-Short.ps1"
if (-not (Test-Path $testScript)) {
    Write-Host "ERROR: Test script not found: $testScript" -ForegroundColor Red
    exit 1
}

try {
    & $testScript
    $testExitCode = $LASTEXITCODE
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    if ($testExitCode -eq 0) {
        Write-Host "  ✓ Lite Test PASSED!" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Windows VM is ready for full benchmark testing!" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  Run full default benchmark (30-45 min):" -ForegroundColor White
        Write-Host "    wsl" -ForegroundColor Gray
        Write-Host "    cd /mnt/c/vtt-hw-benchmarks/docker" -ForegroundColor Gray
        Write-Host "    MODEL_CONFIG_MODE=default ./run-ai-models.sh" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ Lite Test FAILED" -ForegroundColor Red
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Please check the error messages above and fix issues." -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "ERROR: Lite test failed: $_" -ForegroundColor Red
    exit 1
}
