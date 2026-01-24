# VTT Hardware Benchmarks - Windows Setup Script
# Automates WSL2 and Docker installation for Windows users

param(
    [switch]$CheckOnly,
    [string]$ModelPath = "D:\ai-models"
)

$ErrorActionPreference = "Stop"

Write-Host "=== VTT Hardware Benchmarks - Windows Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Function to check WSL2 status
function Test-WSL2 {
    try {
        $wslVersion = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] WSL2 is installed" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "[NOT INSTALLED] WSL2" -ForegroundColor Yellow
    return $false
}

# Function to check Docker in WSL2
function Test-DockerInWSL {
    try {
        $dockerCheck = wsl bash -c "docker --version" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Docker installed in WSL2: $dockerCheck" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "[NOT INSTALLED] Docker in WSL2" -ForegroundColor Yellow
    return $false
}

# Function to check model directory
function Test-ModelDirectory {
    if (Test-Path $ModelPath) {
        $modelCount = (Get-ChildItem -Path $ModelPath -Filter "*.gguf" -Recurse -ErrorAction SilentlyContinue).Count
        Write-Host "[OK] Model directory exists: $ModelPath ($modelCount GGUF files)" -ForegroundColor Green
        return $true
    }
    Write-Host "[NOT FOUND] Model directory: $ModelPath" -ForegroundColor Yellow
    return $false
}

# Check current status
Write-Host "Checking system status..." -ForegroundColor Cyan
Write-Host ""

$hasWSL = Test-WSL2
$hasDocker = Test-DockerInWSL
$hasModels = Test-ModelDirectory

Write-Host ""

if ($CheckOnly) {
    Write-Host "Status check complete. Use without -CheckOnly to install missing components." -ForegroundColor Cyan
    exit 0
}

# Install WSL2 if needed
if (-not $hasWSL) {
    Write-Host "Installing WSL2..." -ForegroundColor Yellow
    Write-Host "This will require a system restart." -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "Continue with WSL2 installation? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Red
        exit 1
    }

    try {
        wsl --install
        Write-Host ""
        Write-Host "WSL2 installation initiated." -ForegroundColor Green
        Write-Host "IMPORTANT: System restart required!" -ForegroundColor Red
        Write-Host "After restart, run this script again to continue setup." -ForegroundColor Yellow
        Write-Host ""

        $restart = Read-Host "Restart now? (y/n)"
        if ($restart -eq 'y') {
            Restart-Computer -Force
        }
        exit 0
    } catch {
        Write-Host "ERROR: WSL2 installation failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Install Docker in WSL2 if needed
if (-not $hasDocker) {
    Write-Host "Installing Docker in WSL2..." -ForegroundColor Yellow
    Write-Host ""

    $dockerInstallScript = @"
#!/bin/bash
set -e
echo 'Installing Docker...'
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker `$USER
echo 'Starting Docker service...'
sudo service docker start
echo 'Docker installation complete!'
"@

    try {
        Write-Host "Executing Docker installation in WSL2..." -ForegroundColor Yellow
        $dockerInstallScript | wsl bash
        Write-Host ""
        Write-Host "[OK] Docker installed in WSL2" -ForegroundColor Green
        Write-Host "Restarting WSL2 for group membership to take effect..." -ForegroundColor Yellow
        wsl --shutdown
        Start-Sleep -Seconds 3
        Write-Host "[OK] WSL2 restarted" -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "ERROR: Docker installation failed: $_" -ForegroundColor Red
        Write-Host "You can manually install Docker by running in WSL2:" -ForegroundColor Yellow
        Write-Host "  curl -fsSL https://get.docker.com | sudo sh" -ForegroundColor Cyan
        Write-Host "  sudo usermod -aG docker `$USER" -ForegroundColor Cyan
        Write-Host "  sudo service docker start" -ForegroundColor Cyan
    }
}

# Configure model path
Write-Host "Configuring model directory..." -ForegroundColor Cyan

if (-not $hasModels) {
    Write-Host ""
    Write-Host "WARNING: Model directory not found at: $ModelPath" -ForegroundColor Yellow
    Write-Host "Please ensure GGUF model files are placed in this directory." -ForegroundColor Yellow
    Write-Host ""
}

# Convert Windows path to WSL path
$wslModelPath = $ModelPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }

Write-Host "Windows path: $ModelPath" -ForegroundColor Cyan
Write-Host "WSL2 path: $wslModelPath" -ForegroundColor Cyan
Write-Host ""

# Add environment variable to WSL2 bashrc
$bashrcConfig = "export MODEL_DIR='$wslModelPath'"
try {
    wsl bash -c "grep -q 'MODEL_DIR' ~/.bashrc || echo '$bashrcConfig' >> ~/.bashrc"
    Write-Host "[OK] Model directory configured in WSL2" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Could not configure bashrc automatically" -ForegroundColor Yellow
    Write-Host "Add this line to ~/.bashrc in WSL2:" -ForegroundColor Yellow
    Write-Host "  $bashrcConfig" -ForegroundColor Cyan
}

# Test Docker
Write-Host ""
Write-Host "Testing Docker installation..." -ForegroundColor Cyan
try {
    $dockerTest = wsl bash -c "docker run --rm hello-world" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Docker is working correctly" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Docker test failed" -ForegroundColor Yellow
        Write-Host "You may need to start Docker service:" -ForegroundColor Yellow
        Write-Host "  wsl sudo service docker start" -ForegroundColor Cyan
    }
} catch {
    Write-Host "[WARNING] Could not test Docker" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Open WSL2 terminal: wsl" -ForegroundColor White
Write-Host "2. Navigate to repository: cd /mnt/c/repos/vtt-hw-benchmarks" -ForegroundColor White
Write-Host "3. Run quick test: cd docker && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test" -ForegroundColor White
Write-Host ""
Write-Host "Full documentation: docs/guides/WINDOWS-SETUP.md" -ForegroundColor Cyan
Write-Host ""
