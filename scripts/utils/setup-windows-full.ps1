# VTT Hardware Benchmarks - Complete Windows Setup & Test Runner
# Full interactive setup from fresh Windows install to running all benchmarks
# Usage: .\setup-windows-full.ps1 [-ModelPath "D:\ai-models"] [-SkipTests] [-SkipContainers]

param(
    [string]$ModelPath = "D:\ai-models",
    [switch]$SkipTests,
    [switch]$SkipContainers,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmarks - Complete Windows Setup" -ForegroundColor Cyan
Write-Host "  Full Interactive Setup from Fresh Windows Install" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
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

# Function to check if containers are available
function Test-Containers {
    try {
        $containers = wsl bash -c "docker images --format '{{.Repository}}:{{.Tag}}' | grep vtt-benchmark" 2>&1
        if ($containers -and $LASTEXITCODE -eq 0) {
            $count = ($containers -split "`n" | Where-Object { $_ -match "vtt-benchmark" }).Count
            Write-Host "[OK] $count benchmark container(s) available" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "[NOT FOUND] Benchmark containers not built/pulled" -ForegroundColor Yellow
    return $false
}

# Check current status
Write-Host "Step 1: Checking system status..." -ForegroundColor Cyan
Write-Host ""

$hasWSL = Test-WSL2
$hasDocker = Test-DockerInWSL
$hasModels = Test-ModelDirectory
$hasContainers = Test-Containers

Write-Host ""

if ($CheckOnly) {
    Write-Host "Status check complete. Use without -CheckOnly to install missing components." -ForegroundColor Cyan
    exit 0
}

# Step 2: Install WSL2 if needed
if (-not $hasWSL) {
    Write-Host "Step 2: Installing WSL2..." -ForegroundColor Yellow
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
} else {
    Write-Host "Step 2: WSL2 already installed, skipping..." -ForegroundColor Green
    Write-Host ""
}

# Step 3: Install Docker in WSL2 if needed
if (-not $hasDocker) {
    Write-Host "Step 3: Installing Docker in WSL2..." -ForegroundColor Yellow
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
        exit 1
    }
} else {
    Write-Host "Step 3: Docker already installed, skipping..." -ForegroundColor Green
    Write-Host ""
}

# Step 4: Configure model path
Write-Host "Step 4: Configuring model directory..." -ForegroundColor Cyan

if (-not $hasModels) {
    Write-Host ""
    Write-Host "WARNING: Model directory not found at: $ModelPath" -ForegroundColor Yellow
    Write-Host "Please ensure GGUF model files are placed in this directory." -ForegroundColor Yellow
    Write-Host "You can continue without models to run non-AI benchmarks." -ForegroundColor Yellow
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

# Step 5: Test Docker
Write-Host ""
Write-Host "Step 5: Testing Docker installation..." -ForegroundColor Cyan
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

# Step 6: Build or pull containers
Write-Host ""
Write-Host "Step 6: Setting up benchmark containers..." -ForegroundColor Cyan

if ($SkipContainers) {
    Write-Host "Skipping container setup (--SkipContainers specified)" -ForegroundColor Yellow
    Write-Host "You can pull containers later with:" -ForegroundColor Yellow
    Write-Host "  wsl bash -c 'cd /mnt/c/vtt-hw-benchmarks && ./scripts/ci-cd/pull-from-ghcr.sh'" -ForegroundColor Cyan
} elseif (-not $hasContainers) {
    Write-Host "Containers not found. Options:" -ForegroundColor Yellow
    Write-Host "  1. Pull from GitHub Container Registry (fast, ~500MB download)" -ForegroundColor White
    Write-Host "  2. Build locally from source (slower, requires git repo)" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Choose option (1 or 2, default: 1)"
    if ($choice -eq "" -or $choice -eq "1") {
        Write-Host "Pulling containers from GHCR..." -ForegroundColor Yellow
        try {
            $repoPath = (Get-Location).Path
            $wslRepoPath = $repoPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }
            
            wsl bash -c "cd '$wslRepoPath' && ./scripts/ci-cd/pull-from-ghcr.sh"
            Write-Host "[OK] Containers pulled successfully" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to pull containers: $_" -ForegroundColor Red
            Write-Host "You can manually pull with:" -ForegroundColor Yellow
            Write-Host "  wsl bash -c 'cd $wslRepoPath && ./scripts/ci-cd/pull-from-ghcr.sh'" -ForegroundColor Cyan
        }
    } else {
        Write-Host "Building containers locally..." -ForegroundColor Yellow
        try {
            $repoPath = (Get-Location).Path
            $wslRepoPath = $repoPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }
            
            wsl bash -c "cd '$wslRepoPath/docker' && ./build-all.sh"
            Write-Host "[OK] Containers built successfully" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: Failed to build containers: $_" -ForegroundColor Red
            Write-Host "You can manually build with:" -ForegroundColor Yellow
            Write-Host "  wsl bash -c 'cd $wslRepoPath/docker && ./build-all.sh'" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "[OK] Containers already available, skipping..." -ForegroundColor Green
}

Write-Host ""

# Step 7: Run tests (if not skipped)
if (-not $SkipTests) {
    Write-Host "Step 7: Running benchmark suite..." -ForegroundColor Cyan
    Write-Host ""
    
    $runTests = Read-Host "Run full benchmark suite now? (y/n, default: y)"
    if ($runTests -eq "" -or $runTests -eq "y") {
        Write-Host ""
        Write-Host "Starting benchmark suite..." -ForegroundColor Green
        Write-Host ""
        
        $repoPath = (Get-Location).Path
        $wslRepoPath = $repoPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }
        
        # Run all benchmarks
        Write-Host "Running all benchmarks (7-Zip, STREAM, Storage)..." -ForegroundColor Yellow
        wsl bash -c "cd '$wslRepoPath/docker' && ./run-all.sh"
        
        Write-Host ""
        Write-Host "Running AI model benchmarks (if models available)..." -ForegroundColor Yellow
        wsl bash -c "cd '$wslRepoPath/docker' && MODEL_CONFIG_MODE=default ./run-ai-models.sh"
        
        Write-Host ""
        Write-Host "[OK] All benchmarks complete!" -ForegroundColor Green
        Write-Host "Results saved to: $repoPath\results\" -ForegroundColor Cyan
    } else {
        Write-Host "Skipping test execution." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To run tests later:" -ForegroundColor Cyan
        Write-Host "  wsl" -ForegroundColor White
        Write-Host "  cd /mnt/c/repos/vtt-hw-benchmarks/docker" -ForegroundColor White
        Write-Host "  ./run-all.sh" -ForegroundColor White
        Write-Host "  MODEL_CONFIG_MODE=default ./run-ai-models.sh" -ForegroundColor White
    }
} else {
    Write-Host "Step 7: Skipping test execution (--SkipTests specified)" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Open WSL2 terminal: wsl" -ForegroundColor White
Write-Host "2. Navigate to repository: cd /mnt/c/repos/vtt-hw-benchmarks" -ForegroundColor White
Write-Host "3. Run benchmarks:" -ForegroundColor White
Write-Host "   cd docker" -ForegroundColor Gray
Write-Host "   ./run-all.sh                                    # All non-AI benchmarks" -ForegroundColor Gray
Write-Host "   MODEL_CONFIG_MODE=default ./run-ai-models.sh   # AI model benchmarks" -ForegroundColor Gray
Write-Host ""
Write-Host "Full documentation: docs/guides/WINDOWS-SETUP.md" -ForegroundColor Cyan
Write-Host ""
