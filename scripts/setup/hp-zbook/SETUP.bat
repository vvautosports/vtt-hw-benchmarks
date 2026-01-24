<# : Batch portion
@echo off & setlocal
REM VTT Hardware Benchmark Setup
REM Self-contained setup script - just run this file as Administrator

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ERROR: This script must be run as Administrator
    echo.
    echo Right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

REM Execute the PowerShell portion of this script
powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "Invoke-Expression (${%~f0} | Out-String)"
pause
exit /b

: End batch portion - PowerShell code follows #>

# VTT Hardware Benchmark Suite - Setup Script
$ErrorActionPreference = "Continue"

function Show-Menu {
    param([string]$Title, [array]$Options)

    Clear-Host
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host "  [$($i + 1)] $($Options[$i])" -ForegroundColor White
    }
    Write-Host "  [0] Exit" -ForegroundColor Gray
    Write-Host ""
}

function Get-MenuChoice {
    param([int]$MaxChoice)

    do {
        $choice = Read-Host "Select an option"
        if ($choice -eq "0") { return 0 }
        if ([int]$choice -ge 1 -and [int]$choice -le $MaxChoice) {
            return [int]$choice
        }
        Write-Host "Invalid choice. Please enter 1-$MaxChoice or 0 to exit." -ForegroundColor Red
    } while ($true)
}

# Detect repository root
function Find-RepoRoot {
    $currentPath = Get-Location
    $checkPath = $currentPath

    for ($i = 0; $i -lt 10; $i++) {
        if (Test-Path (Join-Path $checkPath ".git")) {
            return $checkPath
        }
        $parent = Split-Path -Parent $checkPath
        if ($parent -eq $checkPath) {
            break
        }
        $checkPath = $parent
    }
    return $null
}

# ============================================================================
# Prerequisite Checks
# ============================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmark Suite" -ForegroundColor Cyan
Write-Host "  Checking Prerequisites..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

$ghInstalled = $false
$ghAuthenticated = $false
$dockerDesktopInstalled = $false
$repoCloned = $false
$repoPath = Find-RepoRoot

# Check 1: GitHub CLI
Write-Host "Checking GitHub CLI..." -ForegroundColor Yellow -NoNewline
try {
    $ghVersion = gh --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " [OK] Installed" -ForegroundColor Green
        $ghInstalled = $true
    } else {
        throw "Not installed"
    }
} catch {
    Write-Host " [X] Not installed" -ForegroundColor Red
    Write-Host "Installing GitHub CLI..." -ForegroundColor Yellow
    try {
        winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 2
        $ghVersion = gh --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] GitHub CLI installed successfully" -ForegroundColor Green
            $ghInstalled = $true
        } else {
            Write-Host "[X] Installation failed - please restart PowerShell and try again" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[X] Failed to install GitHub CLI" -ForegroundColor Red
        exit 1
    }
}

# Check 2: GitHub Authentication
Write-Host "Checking GitHub authentication..." -ForegroundColor Yellow -NoNewline
if ($ghInstalled) {
    try {
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host " [OK] Authenticated" -ForegroundColor Green
            $ghAuthenticated = $true
        } else {
            throw "Not authenticated"
        }
    } catch {
        Write-Host " [X] Not authenticated" -ForegroundColor Red
        Write-Host "Starting authentication..." -ForegroundColor Yellow
        Write-Host "This will open your browser." -ForegroundColor Gray
        gh auth login
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Authentication successful" -ForegroundColor Green
            $ghAuthenticated = $true
        } else {
            Write-Host "[X] Authentication failed" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host " [SKIP] GitHub CLI not available" -ForegroundColor Yellow
}

# Check 3: Repository
Write-Host "Checking repository..." -ForegroundColor Yellow -NoNewline
if ($repoPath) {
    Write-Host " [OK] Found at $repoPath" -ForegroundColor Green
    $repoCloned = $true
    Set-Location $repoPath
} elseif ($ghAuthenticated) {
    $defaultRepoPath = "C:\vtt-hw-benchmarks"
    if (Test-Path $defaultRepoPath) {
        if (Test-Path (Join-Path $defaultRepoPath ".git")) {
            Write-Host " [OK] Found at $defaultRepoPath" -ForegroundColor Green
            $repoPath = $defaultRepoPath
            $repoCloned = $true
            Set-Location $repoPath
        } else {
            Write-Host " [WARN] Directory exists but not a git repo" -ForegroundColor Yellow
            $response = Read-Host "Remove and re-clone? (y/n)"
            if ($response -eq 'y') {
                Remove-Item -Path $defaultRepoPath -Recurse -Force
                Write-Host "Cloning repository..." -ForegroundColor Yellow
                gh repo clone vvautosports/vtt-hw-benchmarks $defaultRepoPath
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[OK] Repository cloned" -ForegroundColor Green
                    $repoPath = $defaultRepoPath
                    $repoCloned = $true
                    Set-Location $repoPath
                } else {
                    Write-Host "[X] Clone failed" -ForegroundColor Red
                    exit 1
                }
            } else {
                Write-Host "[X] Cannot proceed without valid repository" -ForegroundColor Red
                exit 1
            }
        }
    } else {
        Write-Host " [X] Not found" -ForegroundColor Red
        Write-Host "Cloning repository to $defaultRepoPath..." -ForegroundColor Yellow
        gh repo clone vvautosports/vtt-hw-benchmarks $defaultRepoPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Repository cloned" -ForegroundColor Green
            $repoPath = $defaultRepoPath
            $repoCloned = $true
            Set-Location $repoPath
        } else {
            Write-Host "[X] Clone failed" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host " [SKIP] Authentication required" -ForegroundColor Yellow
}

# Check 4: Docker Desktop
Write-Host "Checking Docker Desktop..." -ForegroundColor Yellow -NoNewline
try {
    $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Host " [OK] Installed" -ForegroundColor Green
        $dockerDesktopInstalled = $true
    } else {
        throw "Not installed"
    }
} catch {
    Write-Host " [X] Not installed" -ForegroundColor Red
    Write-Host "Installing Docker Desktop..." -ForegroundColor Yellow
    Write-Host "This will take several minutes and may require a reboot." -ForegroundColor Gray
    try {
        winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Docker Desktop installed" -ForegroundColor Green
            Write-Host ""
            Write-Host "=================================================================" -ForegroundColor Yellow
            Write-Host "  IMPORTANT: System reboot required!" -ForegroundColor Yellow
            Write-Host "=================================================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "After reboot:" -ForegroundColor Cyan
            Write-Host "  1. Docker Desktop will auto-start (look for whale icon in system tray)" -ForegroundColor White
            Write-Host "  2. First startup takes 2-5 minutes - wait for whale icon to stop animating" -ForegroundColor White
            Write-Host "  3. Run this script again: SETUP.bat" -ForegroundColor White
            Write-Host ""
            $reboot = Read-Host "Reboot now? (y/n)"
            if ($reboot -eq 'y') {
                Write-Host "Rebooting system..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                Restart-Computer -Force
            } else {
                Write-Host "Please reboot manually before continuing setup." -ForegroundColor Yellow
            }
            exit 0
        } else {
            Write-Host "[WARN] Installation may require manual intervention" -ForegroundColor Yellow
            Write-Host "Check if Docker Desktop is installing in the background" -ForegroundColor Gray
        }
    } catch {
        Write-Host "[X] Failed to install Docker Desktop" -ForegroundColor Red
        Write-Host "Please install manually from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
        exit 1
    }
}

# Verify prerequisites
if (-not ($ghInstalled -and $ghAuthenticated -and $repoCloned -and $dockerDesktopInstalled)) {
    Write-Host ""
    Write-Host "[X] Prerequisites not met. Cannot continue." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] All prerequisites met!" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 1

# ============================================================================
# Main Menu
# ============================================================================

function Test-DockerRunning {
    try {
        $dockerCheck = docker ps 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

$mainMenu = @(
    "Pull benchmark containers",
    "Run validation test",
    "Run quick benchmark"
)

while ($true) {
    Show-Menu -Title "VTT Hardware Benchmark Suite" -Options $mainMenu

    Write-Host "Prerequisites:" -ForegroundColor Cyan
    Write-Host "  GitHub CLI: [OK] Installed" -ForegroundColor Green
    Write-Host "  GitHub Auth: [OK] Authenticated" -ForegroundColor Green
    Write-Host "  Repository: [OK] Cloned" -ForegroundColor Green
    Write-Host "  Docker Desktop: [OK] Installed" -ForegroundColor Green
    Write-Host ""

    Write-Host "Docker Status:" -ForegroundColor Cyan
    $dockerRunning = Test-DockerRunning
    if ($dockerRunning) {
        Write-Host "  Docker: [OK] Running" -ForegroundColor Green
    } else {
        Write-Host "  Docker: [X] Not running" -ForegroundColor Red
        Write-Host "  Start Docker Desktop and wait for it to be ready" -ForegroundColor Yellow
    }
    Write-Host ""

    if (-not $dockerRunning) {
        Write-Host "WARNING: Docker is not running!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To start Docker Desktop:" -ForegroundColor Cyan
        Write-Host "  1. Press Windows key, type 'Docker Desktop', press Enter" -ForegroundColor White
        Write-Host "  2. Wait for whale icon in system tray (bottom-right)" -ForegroundColor White
        Write-Host "  3. First startup takes 2-5 minutes - icon will stop animating when ready" -ForegroundColor White
        Write-Host "  4. Return to this menu and try again" -ForegroundColor White
        Write-Host ""
    }

    $choice = Get-MenuChoice -MaxChoice $mainMenu.Length

    switch ($choice) {
        0 {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        1 {
            Write-Host ""
            if (-not $dockerRunning) {
                Write-Host "Docker is not running!" -ForegroundColor Red
                Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Press any key to return to menu..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            Write-Host "Pulling benchmark containers from GHCR..." -ForegroundColor Cyan
            Write-Host ""
            Set-Location $repoPath

            # Convert Windows path to WSL path
            $wslPath = $repoPath -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/' | ForEach-Object { $_.ToLower() }

            Write-Host "Entering WSL..." -ForegroundColor Gray
            wsl bash -c "cd '$wslPath' && ./scripts/ci-cd/pull-from-ghcr.sh"
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        2 {
            Write-Host ""
            if (-not $dockerRunning) {
                Write-Host "Docker is not running!" -ForegroundColor Red
                Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Press any key to return to menu..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            Write-Host "Running validation test..." -ForegroundColor Cyan
            Write-Host ""
            Set-Location $repoPath
            & .\scripts\testing\Test-Windows-Short.ps1
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        3 {
            Write-Host ""
            if (-not $dockerRunning) {
                Write-Host "Docker is not running!" -ForegroundColor Red
                Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Press any key to return to menu..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }

            Write-Host "Running quick benchmark..." -ForegroundColor Cyan
            Write-Host ""
            Set-Location $repoPath

            # Convert Windows path to WSL path (C:\path -> /mnt/c/path)
            $wslPath = $repoPath -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/' | ForEach-Object { $_.ToLower() }
            $dockerPath = "$wslPath/docker"

            Write-Host "Entering WSL..." -ForegroundColor Gray
            Write-Host "Repository: $dockerPath" -ForegroundColor Gray
            wsl bash -c "cd '$dockerPath' && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test"
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}
