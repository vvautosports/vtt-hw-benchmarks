# VTT Hardware Benchmark Suite - Interactive Setup
# Simple menu-driven setup process
# Usage: .\HP-ZBOOK-SETUP-INTERACTIVE.ps1

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

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# ============================================================================
# Prerequisite Checks (Automatic)
# ============================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmark Suite" -ForegroundColor Cyan
Write-Host "  Checking Prerequisites..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

$ghInstalled = $false
$ghAuthenticated = $false
$repoCloned = $false

# Detect if we're already running from within the repository
function Find-RepoRoot {
    $currentPath = Get-Location
    $checkPath = $currentPath
    
    # Check current directory and parent directories for .git
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
    # Already running from within the repository
    Write-Host " [OK] Found at $repoPath" -ForegroundColor Green
    $repoCloned = $true
    Set-Location $repoPath
} elseif ($ghAuthenticated) {
    # Not in repo, check default location
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

# Verify all prerequisites met
if (-not ($ghInstalled -and $ghAuthenticated -and $repoCloned)) {
    Write-Host ""
    Write-Host "[X] Prerequisites not met. Cannot continue." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] All prerequisites met!" -ForegroundColor Green
Write-Host ""
Start-Sleep -Seconds 1

# ============================================================================
# Main Menu (Benchmark/Setup Options)
# ============================================================================

# Function to check if Ubuntu is currently installing
function Test-UbuntuInstalling {
    # Check if Microsoft Store is installing Ubuntu
    try {
        $storeProcess = Get-Process -Name "Microsoft.Store" -ErrorAction SilentlyContinue
        if ($storeProcess) {
            return $true
        }
    } catch {}
    
    # Check if WSL installation process is running
    try {
        $wslProcess = Get-Process -Name "wsl" -ErrorAction SilentlyContinue
        if ($wslProcess) {
            return $true
        }
    } catch {}
    
    # Check if Ubuntu installer is running
    try {
        $ubuntuProcess = Get-Process | Where-Object { $_.ProcessName -like "*ubuntu*" -or $_.ProcessName -like "*canonical*" }
        if ($ubuntuProcess) {
            return $true
        }
    } catch {}
    
    return $false
}

# Function to check setup status with definitive installation state
function Test-SetupStatus {
    $wslInstalled = $false
    $dockerInstalled = $false
    $wslDistributionReady = $false
    $wslDistributionInstalling = $false
    
    # Check if WSL2 is installed
    try {
        $wslStatus = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $wslInstalled = $true
        }
    } catch {
        $wslInstalled = $false
    }
    
    # Check if a WSL distribution is installed and ready
    if ($wslInstalled) {
        try {
            $distros = wsl --list --quiet 2>&1
            if ($LASTEXITCODE -eq 0 -and $distros) {
                # Check if any distribution is installed
                $installed = $distros | Where-Object { 
                    $_ -and 
                    $_.Trim() -ne '' -and 
                    $_ -notmatch '^NAME' -and
                    $_ -notmatch '^Windows' -and
                    $_ -notmatch '^The following'
                }
                $wslDistributionReady = ($installed.Count -gt 0)
            } else {
                # Try verbose list as fallback
                $verboseList = wsl --list --verbose 2>&1
                if ($LASTEXITCODE -eq 0 -and $verboseList) {
                    $installed = $verboseList | Where-Object { 
                        $_ -match '^\s*\w' -and 
                        $_ -notmatch '^NAME' -and
                        $_ -notmatch '^\s*$'
                    }
                    $wslDistributionReady = ($installed.Count -gt 0)
                }
            }
            
            # If no distribution is ready, check if one is installing
            if (-not $wslDistributionReady) {
                $wslDistributionInstalling = Test-UbuntuInstalling
            }
        } catch {
            $wslDistributionReady = $false
            $wslDistributionInstalling = Test-UbuntuInstalling
        }
        
        # Only check Docker if WSL distribution is ready
        if ($wslDistributionReady) {
            try {
                # Try to run a simple command first to ensure WSL is responsive
                $testCmd = wsl bash -c "echo 'test'" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    # Now check for Docker
                    $dockerVersion = wsl bash -c "docker --version" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $dockerInstalled = $true
                    }
                }
            } catch {
                $dockerInstalled = $false
            }
        }
    }
    
    return @{
        WSL2 = $wslInstalled
        WSLDistributionReady = $wslDistributionReady
        WSLDistributionInstalling = $wslDistributionInstalling
        Docker = $dockerInstalled
    }
}


# Main menu - only benchmark/setup options
$mainMenu = @(
    "Run full setup (WSL2, Docker, models, validation)",
    "Run validation test only",
    "Run quick benchmark"
)

while ($true) {
    Show-Menu -Title "VTT Hardware Benchmark Suite" -Options $mainMenu
    
    # Show prerequisite status (read-only)
    Write-Host "Prerequisites:" -ForegroundColor Cyan
    Write-Host "  GitHub CLI: [OK] Installed" -ForegroundColor Green
    Write-Host "  GitHub Auth: [OK] Authenticated" -ForegroundColor Green
    Write-Host "  Repository: [OK] Cloned" -ForegroundColor Green
    Write-Host ""
    
    # Check setup status
    $setupStatus = Test-SetupStatus
    Write-Host "Setup Status:" -ForegroundColor Cyan
    if ($setupStatus.WSL2) {
        Write-Host "  WSL2: [OK] Installed" -ForegroundColor Green
        if ($setupStatus.WSLDistributionReady) {
            Write-Host "  WSL Distribution: [OK] Ready" -ForegroundColor Green
        } elseif ($setupStatus.WSLDistributionInstalling) {
            Write-Host "  WSL Distribution: [INSTALLING] Installing Ubuntu..." -ForegroundColor Yellow
            Write-Host "    Installation in progress, wait for completion" -ForegroundColor Gray
        } else {
            Write-Host "  WSL Distribution: [X] Not installed" -ForegroundColor Red
        }
    } else {
        Write-Host "  WSL2: [X] Not installed" -ForegroundColor Red
    }
    if ($setupStatus.Docker) {
        Write-Host "  Docker: [OK] Installed" -ForegroundColor Green
    } else {
        if ($setupStatus.WSL2 -and $setupStatus.WSLDistributionReady) {
            Write-Host "  Docker: [X] Not installed" -ForegroundColor Red
        } else {
            Write-Host "  Docker: [SKIP] WSL not ready" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    
    if (-not ($setupStatus.WSL2 -and $setupStatus.WSLDistributionReady -and $setupStatus.Docker)) {
        Write-Host "WARNING: Setup is incomplete!" -ForegroundColor Yellow
        if ($setupStatus.WSLDistributionInstalling) {
            Write-Host "   Ubuntu is currently installing. Use option 4 to monitor progress." -ForegroundColor Yellow
        } elseif (-not $setupStatus.WSLDistributionReady -and $setupStatus.WSL2) {
            Write-Host "   WSL distribution is not installed. Run option 1 to install Ubuntu." -ForegroundColor Yellow
        } else {
            Write-Host "   Run option 1 (full setup) before running validation or benchmarks." -ForegroundColor Yellow
        }
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
            Write-Host "Running full setup..." -ForegroundColor Cyan
            Write-Host ""
            Set-Location $repoPath
            & .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP.ps1
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        2 {
            Write-Host ""
            
            # Check if setup is needed
            $setupStatus = Test-SetupStatus
            if (-not ($setupStatus.WSL2 -and $setupStatus.WSLDistributionReady -and $setupStatus.Docker)) {
                Write-Host "Setup is incomplete!" -ForegroundColor Red
                Write-Host ""
                if (-not $setupStatus.WSL2) {
                    Write-Host "  [X] WSL2 is not installed" -ForegroundColor Red
                } elseif ($setupStatus.WSLDistributionInstalling) {
                    Write-Host "  [INSTALLING] WSL distribution is currently installing" -ForegroundColor Yellow
                    Write-Host "      Installation in progress, wait for completion" -ForegroundColor Gray
                } elseif (-not $setupStatus.WSLDistributionReady) {
                    Write-Host "  [X] WSL distribution is not installed" -ForegroundColor Red
                    Write-Host "      Run option 1 to install Ubuntu" -ForegroundColor Gray
                }
                if ($setupStatus.WSL2 -and $setupStatus.WSLDistributionReady -and -not $setupStatus.Docker) {
                    Write-Host "  [X] Docker is not installed in WSL2" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host "You must run option 1 (full setup) first to install WSL2 and Docker." -ForegroundColor Yellow
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
            
            # Check if setup is needed
            $setupStatus = Test-SetupStatus
            if (-not ($setupStatus.WSL2 -and $setupStatus.WSLDistributionReady -and $setupStatus.Docker)) {
                Write-Host "Setup is incomplete!" -ForegroundColor Red
                Write-Host ""
                if (-not $setupStatus.WSL2) {
                    Write-Host "  [X] WSL2 is not installed" -ForegroundColor Red
                } elseif ($setupStatus.WSLDistributionInstalling) {
                    Write-Host "  [INSTALLING] WSL distribution is currently installing" -ForegroundColor Yellow
                    Write-Host "      Installation in progress, wait for completion" -ForegroundColor Gray
                } elseif (-not $setupStatus.WSLDistributionReady) {
                    Write-Host "  [X] WSL distribution is not installed" -ForegroundColor Red
                    Write-Host "      Run option 1 to install Ubuntu" -ForegroundColor Gray
                }
                if ($setupStatus.WSL2 -and $setupStatus.WSLDistributionReady -and -not $setupStatus.Docker) {
                    Write-Host "  [X] Docker is not installed in WSL2" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host "You must run option 1 (full setup) first to install WSL2 and Docker." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Press any key to return to menu..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            
            Write-Host "Running quick benchmark..." -ForegroundColor Cyan
            Write-Host ""
            Set-Location $repoPath
            Write-Host "Entering WSL..." -ForegroundColor Gray
            wsl bash -c "cd /mnt/c/vtt-hw-benchmarks/docker && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test"
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}
