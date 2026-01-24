# VTT Hardware Benchmarks - Automated HP ZBook Setup
# Complete automated setup for HP ZBook laptops with light models
# Usage: .\Setup-HP-ZBook-Automated.ps1 [-ModelPath "D:\ai-models"] [-NonInteractive] [-SkipModels] [-SkipTests]

param(
    [string]$ModelPath = "D:\ai-models",
    [switch]$NonInteractive,
    [switch]$SkipModels,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmarks - HP ZBook Automated Setup" -ForegroundColor Cyan
Write-Host "  Light Mode Configuration (GPT-OSS-20B + Qwen3-8B)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

$StartTime = Get-Date
$LogFile = ".\setup-hp-zbook-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param($Message, $Color = "White")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    $LogMessage | Out-File -FilePath $LogFile -Append
}

function Test-WSL2 {
    try {
        $wslVersion = wsl --status 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-DockerInWSL {
    try {
        $dockerCheck = wsl bash -c "docker --version" 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log "  Phase 1: System Validation" "Cyan"
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log ""

# Check Windows version
$OSInfo = Get-CimInstance Win32_OperatingSystem
Write-Log "Operating System: $($OSInfo.Caption)" "Gray"
Write-Log "Version: $($OSInfo.Version)" "Gray"
Write-Log "Build: $($OSInfo.BuildNumber)" "Gray"
Write-Log ""

# Check disk space
$TargetDrive = Split-Path -Qualifier $ModelPath
$Drive = Get-PSDrive -Name $TargetDrive.TrimEnd(':')
$FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)
Write-Log "Available Disk Space: ${FreeSpaceGB}GB" $(if ($FreeSpaceGB -gt 30) { "Green" } else { "Yellow" })

if ($FreeSpaceGB -lt 30) {
    Write-Log "WARNING: Low disk space. Recommended: 30GB+" "Yellow"
    if (-not $NonInteractive) {
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y') {
            Write-Log "Setup cancelled." "Red"
            exit 1
        }
    }
}

Write-Log ""

# Check network connectivity
Write-Log "Testing network connectivity..." "Yellow"
try {
    $ping = Test-Connection -ComputerName github.com -Count 1 -Quiet
    if ($ping) {
        Write-Log "✓ Network connectivity OK" "Green"
    } else {
        Write-Log "WARNING: Cannot reach github.com" "Yellow"
    }
} catch {
    Write-Log "WARNING: Network test failed: $_" "Yellow"
}

Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log "  Phase 2: WSL2 Installation" "Cyan"
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log ""

$hasWSL = Test-WSL2

if (-not $hasWSL) {
    Write-Log "Installing WSL2..." "Yellow"
    Write-Log "This will require a system restart." "Yellow"
    Write-Log ""

    if (-not $NonInteractive) {
        $response = Read-Host "Continue with WSL2 installation? (y/n)"
        if ($response -ne 'y') {
            Write-Log "Installation cancelled." "Red"
            exit 1
        }
    }

    try {
        wsl --install
        Write-Log ""
        Write-Log "WSL2 installation initiated." "Green"
        Write-Log "IMPORTANT: System restart required!" "Red"
        Write-Log "After restart, run this script again to continue setup." "Yellow"
        Write-Log ""
        Write-Log "Command to run after restart:" "Cyan"
        Write-Log "  .\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath `"$ModelPath`" -NonInteractive" "White"
        Write-Log ""

        if (-not $NonInteractive) {
            $restart = Read-Host "Restart now? (y/n)"
            if ($restart -eq 'y') {
                Restart-Computer -Force
            }
        } else {
            Write-Log "Non-interactive mode: Please restart manually and re-run script" "Yellow"
        }
        exit 0
    } catch {
        Write-Log "ERROR: WSL2 installation failed: $_" "Red"
        exit 1
    }
} else {
    Write-Log "✓ WSL2 already installed" "Green"
}

Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log "  Phase 3: Docker Installation" "Cyan"
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log ""

$hasDocker = Test-DockerInWSL

if (-not $hasDocker) {
    Write-Log "Installing Docker in WSL2..." "Yellow"

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
        Write-Log "Executing Docker installation in WSL2..." "Yellow"
        $dockerInstallScript | wsl bash
        Write-Log ""
        Write-Log "✓ Docker installed in WSL2" "Green"
        Write-Log "Restarting WSL2 for group membership to take effect..." "Yellow"
        wsl --shutdown
        Start-Sleep -Seconds 3
        Write-Log "✓ WSL2 restarted" "Green"
    } catch {
        Write-Log "ERROR: Docker installation failed: $_" "Red"
        Write-Log "Manual installation commands:" "Yellow"
        Write-Log "  wsl" "Cyan"
        Write-Log "  curl -fsSL https://get.docker.com | sudo sh" "Cyan"
        Write-Log "  sudo usermod -aG docker `$USER" "Cyan"
        Write-Log "  sudo service docker start" "Cyan"
        exit 1
    }
} else {
    Write-Log "✓ Docker already installed" "Green"
    
    # Ensure Docker is running
    Write-Log "Ensuring Docker service is running..." "Yellow"
    try {
        wsl bash -c "sudo service docker start 2>/dev/null || true"
        Write-Log "✓ Docker service started" "Green"
    } catch {
        Write-Log "WARNING: Could not start Docker service" "Yellow"
    }
}

Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log "  Phase 4: Model Configuration" "Cyan"
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log ""

# Convert Windows path to WSL path
$wslModelPath = $ModelPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }

Write-Log "Windows path: $ModelPath" "Cyan"
Write-Log "WSL2 path: $wslModelPath" "Cyan"
Write-Log ""

# Configure MODEL_DIR in WSL2
$bashrcConfig = "export MODEL_DIR='$wslModelPath'"
try {
    wsl bash -c "grep -q 'MODEL_DIR' ~/.bashrc || echo '$bashrcConfig' >> ~/.bashrc"
    Write-Log "✓ Model directory configured in WSL2" "Green"
} catch {
    Write-Log "WARNING: Could not configure bashrc automatically" "Yellow"
    Write-Log "Add this line to ~/.bashrc in WSL2: $bashrcConfig" "Yellow"
}

Write-Log ""

if (-not $SkipModels) {
    Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-Log "  Phase 5: Model Download" "Cyan"
    Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-Log ""

    $DownloadScript = Join-Path (Get-Location) "scripts\utils\Download-Light-Models.ps1"
    
    if (Test-Path $DownloadScript) {
        Write-Log "Downloading light models..." "Yellow"
        try {
            & $DownloadScript -ModelPath $ModelPath
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ Models downloaded successfully" "Green"
            } else {
                Write-Log "WARNING: Model download had issues" "Yellow"
            }
        } catch {
            Write-Log "ERROR: Model download failed: $_" "Red"
            Write-Log "You can download models manually later" "Yellow"
        }
    } else {
        Write-Log "WARNING: Download script not found at $DownloadScript" "Yellow"
        Write-Log "Skipping model download. Download manually from HuggingFace:" "Yellow"
        Write-Log "  - unsloth/gpt-oss-20b-F16-GGUF" "Gray"
        Write-Log "  - unsloth/Qwen3-8B-128K-GGUF" "Gray"
    }
} else {
    Write-Log "Phase 5: Model Download - SKIPPED" "Yellow"
}

Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log "  Phase 6: Container Setup" "Cyan"
Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
Write-Log ""

$repoPath = (Get-Location).Path
$wslRepoPath = $repoPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }

Write-Log "Pulling benchmark containers from GHCR..." "Yellow"
Write-Log "Repository path: $wslRepoPath" "Gray"
Write-Log ""

try {
    $pullOutput = wsl bash -c "cd '$wslRepoPath' && ./scripts/ci-cd/pull-from-ghcr.sh" 2>&1
    Write-Log $pullOutput "Gray"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log ""
        Write-Log "✓ Containers pulled successfully from GHCR" "Green"
        
        # Verify containers
        Write-Log "Verifying containers..." "Yellow"
        $containers = wsl bash -c "docker images | grep vtt-benchmark" 2>&1
        Write-Log $containers "Gray"
    } else {
        Write-Log "WARNING: Container pull had issues" "Yellow"
        Write-Log "Output: $pullOutput" "Gray"
    }
} catch {
    Write-Log "ERROR: Failed to pull containers: $_" "Red"
    Write-Log "You can pull containers manually:" "Yellow"
    Write-Log "  wsl bash -c 'cd $wslRepoPath && ./scripts/ci-cd/pull-from-ghcr.sh'" "Cyan"
}

Write-Log ""

if (-not $SkipTests) {
    Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-Log "  Phase 7: Validation Test" "Cyan"
    Write-Log "═══════════════════════════════════════════════════════════════" "Cyan"
    Write-Log ""

    Write-Log "Running quick validation test (2-3 minutes)..." "Yellow"
    Write-Log "This tests one light model to verify the complete setup" "Gray"
    Write-Log ""

    try {
        $testOutput = wsl bash -c "cd '$wslRepoPath/docker' && MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test" 2>&1
        Write-Log $testOutput "Gray"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log ""
            Write-Log "✓ Validation test PASSED" "Green"
        } else {
            Write-Log ""
            Write-Log "✗ Validation test FAILED" "Red"
            Write-Log "Check the output above for errors" "Yellow"
        }
    } catch {
        Write-Log "ERROR: Validation test failed: $_" "Red"
    }
} else {
    Write-Log "Phase 7: Validation Test - SKIPPED" "Yellow"
}

Write-Log ""
Write-Log "═══════════════════════════════════════════════════════════════" "Green"
Write-Log "  Setup Complete!" "Green"
Write-Log "═══════════════════════════════════════════════════════════════" "Green"
Write-Log ""

$EndTime = Get-Date
$Duration = $EndTime - $StartTime
Write-Log "Total setup time: $([math]::Round($Duration.TotalMinutes, 1)) minutes" "Cyan"
Write-Log "Log file: $LogFile" "Cyan"
Write-Log ""

Write-Log "Next steps:" "Cyan"
Write-Log "  1. Open WSL2 terminal:" "White"
Write-Log "     wsl" "Gray"
Write-Log ""
Write-Log "  2. Navigate to repository:" "White"
Write-Log "     cd $wslRepoPath" "Gray"
Write-Log ""
Write-Log "  3. Run light mode benchmarks:" "White"
Write-Log "     cd docker" "Gray"
Write-Log "     MODEL_CONFIG_MODE=light ./run-ai-models.sh" "Gray"
Write-Log ""
Write-Log "  4. Run full light mode test:" "White"
Write-Log "     MODEL_CONFIG_MODE=light ./run-ai-models.sh  # Both models" "Gray"
Write-Log ""
Write-Log "Documentation: docs/guides/HP-ZBOOK-DEPLOYMENT.md" "Cyan"
Write-Log ""
