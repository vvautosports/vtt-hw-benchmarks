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

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmark Suite" -ForegroundColor Cyan
Write-Host "  Light Mode Configuration (GPT-OSS-20B + Qwen3-8B)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
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

function Test-WSLDistribution {
    try {
        $distros = wsl --list --quiet 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Check if any distribution is installed (skip header line)
            $installed = $distros | Where-Object { $_ -match '^\w' -and $_ -notmatch '^NAME' }
            return ($installed.Count -gt 0)
        }
        return $false
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

Write-Log "=================================================================" "Cyan"
Write-Log "  Phase 1: System Validation" "Cyan"
Write-Log "=================================================================" "Cyan"
Write-Log ""

# Check Windows version
$OSInfo = Get-CimInstance Win32_OperatingSystem
Write-Log "Operating System: $($OSInfo.Caption)" "Gray"
Write-Log "Version: $($OSInfo.Version)" "Gray"
Write-Log "Build: $($OSInfo.BuildNumber)" "Gray"
Write-Log ""

# Check disk space
$TargetDrive = Split-Path -Qualifier $ModelPath
$FreeSpaceGB = 0

try {
    # Try Get-CimInstance first (more reliable on modern Windows)
    $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$TargetDrive'" -ErrorAction Stop
    if ($drive -and $drive.FreeSpace) {
        $FreeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    }
} catch {
    try {
        # Fallback to Get-WmiObject
        $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$TargetDrive'" -ErrorAction Stop
        if ($drive -and $drive.FreeSpace) {
            $FreeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        }
    } catch {
        try {
            # Fallback to Get-PSDrive
            $driveLetter = $TargetDrive.TrimEnd(':')
            $Drive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
            if ($Drive -and $Drive.Free) {
                $FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)
            }
        } catch {
            Write-Log "WARNING: Could not check disk space for $TargetDrive" "Yellow"
            Write-Log "  Error: $($_.Exception.Message)" "Gray"
            $FreeSpaceGB = 0
        }
    }
}

# If still 0, try checking all drives to find the system drive
if ($FreeSpaceGB -eq 0) {
    try {
        $systemDrive = $env:SystemDrive
        $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$systemDrive'" -ErrorAction Stop
        if ($drive -and $drive.FreeSpace) {
            $FreeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
            Write-Log "Using system drive ($systemDrive) for disk space check" "Gray"
        }
    } catch {
        # Last resort: try to get any available drive
        try {
            $allDrives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 -and $_.FreeSpace } | Sort-Object FreeSpace -Descending
            if ($allDrives) {
                $FreeSpaceGB = [math]::Round($allDrives[0].FreeSpace / 1GB, 2)
                Write-Log "Using drive $($allDrives[0].DeviceID) for disk space check" "Gray"
            }
        } catch {
            Write-Log "WARNING: All disk space check methods failed" "Yellow"
        }
    }
}
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
        Write-Log "[OK] Network connectivity OK" "Green"
    } else {
        Write-Log "WARNING: Cannot reach github.com" "Yellow"
    }
} catch {
    Write-Log "WARNING: Network test failed: $_" "Yellow"
}

Write-Log ""
Write-Log "=================================================================" "Cyan"
Write-Log "  Phase 2: WSL2 Installation" "Cyan"
Write-Log "=================================================================" "Cyan"
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
    Write-Log "[OK] WSL2 already installed" "Green"
    
    # Check if a distribution is installed
    $hasDistribution = Test-WSLDistribution
    if (-not $hasDistribution) {
        Write-Log "WSL2 is installed but no Linux distribution found" "Yellow"
        Write-Log "Installing Ubuntu distribution..." "Yellow"
        Write-Log "This may take a few minutes and will download Ubuntu from Microsoft Store." "Gray"
        Write-Log ""
        
        if (-not $NonInteractive) {
            $response = Read-Host "Continue with Ubuntu installation? (y/n)"
            if ($response -ne 'y') {
                Write-Log "Installation cancelled." "Red"
                Write-Log "You can install Ubuntu manually: wsl --install -d Ubuntu" "Yellow"
                exit 1
            }
        }
        
        try {
            # Try using winget first (more reliable)
            Write-Log "Attempting to install Ubuntu via winget..." "Yellow"
            $wingetInstalled = $false
            $rebootRequired = $false
            $allOutput = @()
            
            try {
                $wingetCheck = winget --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Installing Ubuntu using winget..." "Gray"
                    $wingetOutput = winget install --id Canonical.Ubuntu -e --source winget --accept-package-agreements --accept-source-agreements 2>&1
                    $allOutput += $wingetOutput
                    if ($LASTEXITCODE -eq 0) {
                        $wingetInstalled = $true
                        Write-Log "[OK] Ubuntu installed via winget" "Green"
                    }
                }
            } catch {
                Write-Log "winget not available, trying wsl --install method" "Gray"
            }
            
            # If winget didn't work, try wsl --install
            if (-not $wingetInstalled) {
                Write-Log "Running: wsl --install -d Ubuntu" "Gray"
                $installOutput = wsl --install -d Ubuntu 2>&1
                $allOutput += $installOutput
                Write-Log $installOutput "Gray"
            }
            
            # Check if reboot is required (from either method)
            $outputString = ($allOutput | Out-String) -join " "
            if ($outputString -match "reboot|restart|Changes will not be effective" -or 
                ($wingetInstalled -and -not (Test-WSLDistribution))) {
                # If winget succeeded but distribution not ready, likely needs reboot
                $rebootRequired = $true
            }
            
            if ($rebootRequired) {
                Write-Log "" "Yellow"
                Write-Log "IMPORTANT: System reboot required for Ubuntu installation!" "Red"
                Write-Log "The WSL distribution will be available after reboot." "Yellow"
                Write-Log ""
                
                if (-not $NonInteractive) {
                    $restart = Read-Host "Restart now? (y/n)"
                    if ($restart -eq 'y') {
                        Write-Log "Restarting system..." "Yellow"
                        Write-Log "After restart, run this script again to continue with Docker setup." "Cyan"
                        Write-Log ""
                        Write-Log "Command to run after restart:" "Cyan"
                        Write-Log "  .\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath `"$ModelPath`" -NonInteractive" "White"
                        Write-Log ""
                        Start-Sleep -Seconds 3
                        Restart-Computer -Force
                        exit 0
                    } else {
                        Write-Log "Please restart manually and re-run this script to continue." "Yellow"
                        exit 0
                    }
                } else {
                    Write-Log "Non-interactive mode: Please restart manually and re-run script" "Yellow"
                    Write-Log "Command: .\scripts\utils\Setup-HP-ZBook-Automated.ps1 -ModelPath `"$ModelPath`" -NonInteractive" "Cyan"
                    exit 0
                }
            }
            
            # Wait and poll for installation to complete with detailed progress
            Write-Log "Waiting for Ubuntu installation to complete..." "Yellow"
            Write-Log "This may take 2-5 minutes. Monitoring progress..." "Gray"
            Write-Log ""
            
            $maxWaitTime = 300  # 5 minutes
            $checkInterval = 5  # Check every 5 seconds for more responsive updates
            $elapsed = 0
            $installed = $false
            $lastProgress = ""
            $lastDistroCheck = ""
            
            while ($elapsed -lt $maxWaitTime -and -not $installed) {
                Start-Sleep -Seconds $checkInterval
                $elapsed += $checkInterval
                
                # Check if distribution is now installed
                $checkDistros = wsl --list --quiet 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $distros = $checkDistros | Where-Object { $_ -match '^\w' -and $_ -notmatch '^NAME' }
                    if ($distros.Count -gt 0) {
                        $installed = $true
                        Write-Log "[OK] Ubuntu distribution installed successfully!" "Green"
                        Write-Log "Distribution: $($distros -join ', ')" "Gray"
                        break
                    }
                }
                
                # Get detailed status information
                $progressInfo = @()
                
                # Check wsl --list --verbose for Ubuntu status
                try {
                    $wslListVerbose = wsl --list --verbose 2>&1
                    if ($LASTEXITCODE -eq 0 -and $wslListVerbose) {
                        $ubuntuLine = $wslListVerbose | Where-Object { $_ -match 'Ubuntu' -or $_ -match 'ubuntu' }
                        if ($ubuntuLine -and $ubuntuLine -ne $lastDistroCheck) {
                            $lastDistroCheck = $ubuntuLine
                            # Extract status from verbose output
                            if ($ubuntuLine -match 'Installing') {
                                $progressInfo += "Ubuntu: Installing"
                            } elseif ($ubuntuLine -match 'Stopped') {
                                $progressInfo += "Ubuntu: Installed (Stopped)"
                            } elseif ($ubuntuLine -match 'Running') {
                                $progressInfo += "Ubuntu: Running"
                            } else {
                                $progressInfo += "Ubuntu: Detected"
                            }
                        }
                    }
                } catch {}
                
                # Check AppxPackage installation status (Microsoft Store apps)
                # Note: App package installed != WSL distribution ready
                try {
                    $ubuntuApp = Get-AppxPackage -Name "*Ubuntu*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Ubuntu*" } | Select-Object -First 1
                    if ($ubuntuApp) {
                        # App package is installed, but check if WSL distribution is ready
                        $wslHasUbuntu = $false
                        try {
                            $wslListCheck = wsl --list --quiet 2>&1
                            if ($LASTEXITCODE -eq 0 -and $wslListCheck) {
                                $wslHasUbuntu = ($wslListCheck | Where-Object { $_ -match 'Ubuntu' -or $_ -match 'ubuntu' -and $_ -notmatch '^NAME' }).Count -gt 0
                            }
                        } catch {}
                        
                        if ($wslHasUbuntu) {
                            $progressInfo += "Store: Ready"
                        } else {
                            $progressInfo += "Store: App installed, WSL initializing..."
                        }
                    } else {
                        # Check if it's in the process of being installed
                        $pendingApps = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*Ubuntu*" }
                        if ($pendingApps) {
                            $progressInfo += "Store: Downloading/Installing app"
                        } else {
                            $progressInfo += "Store: Not found"
                        }
                    }
                } catch {}
                
                # Always show WSL list check status
                try {
                    $wslListCheck = wsl --list --quiet 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        if ($wslListCheck) {
                            $hasUbuntu = $wslListCheck | Where-Object { 
                                $_ -and 
                                $_ -match 'Ubuntu|ubuntu' -and 
                                $_ -notmatch '^NAME' -and
                                $_ -notmatch '^Windows'
                            }
                            if ($hasUbuntu) {
                                $progressInfo += "WSL: Distribution ready"
                            } else {
                                $progressInfo += "WSL: Waiting for distribution"
                            }
                        } else {
                            $progressInfo += "WSL: Checking..."
                        }
                    }
                } catch {}
                
                # Check for active installation processes
                $activeProcesses = @()
                try {
                    $storeProcess = Get-Process -Name "Microsoft.Store" -ErrorAction SilentlyContinue
                    if ($storeProcess) { $activeProcesses += "Store" }
                } catch {}
                
                try {
                    $wslProcess = Get-Process -Name "wsl" -ErrorAction SilentlyContinue
                    if ($wslProcess) { $activeProcesses += "WSL" }
                } catch {}
                
                try {
                    $ubuntuProcesses = Get-Process | Where-Object { 
                        $_.ProcessName -like "*ubuntu*" -or 
                        $_.ProcessName -like "*canonical*" -or
                        $_.ProcessName -like "*wslhost*"
                    }
                    if ($ubuntuProcesses) {
                        $activeProcesses += "Ubuntu"
                    }
                } catch {}
                
                if ($activeProcesses.Count -gt 0) {
                    $progressInfo += "Processes: $($activeProcesses -join ', ')"
                }
                
                # Check Windows Event Log for WSL installation events (last 30 seconds)
                try {
                    $cutoffTime = (Get-Date).AddSeconds(-30)
                    $events = Get-WinEvent -FilterHashtable @{
                        LogName = 'System', 'Application'
                        StartTime = $cutoffTime
                    } -ErrorAction SilentlyContinue | Where-Object {
                        $_.Message -match 'WSL|Ubuntu|Linux|Subsystem' -or
                        $_.ProviderName -match 'WSL|Ubuntu'
                    } | Select-Object -First 2
                    
                    if ($events) {
                        foreach ($event in $events) {
                            $eventTime = $event.TimeCreated.ToString("HH:mm:ss")
                            $eventMsg = ($event.Message -split "`n")[0]
                            if ($eventMsg.Length -gt 50) {
                                $eventMsg = $eventMsg.Substring(0, 47) + "..."
                            }
                            $progressInfo += "[$eventTime] $eventMsg"
                        }
                    }
                } catch {}
                
                # Show progress with details - always on new line for clarity
                $minutes = [math]::Floor($elapsed / 60)
                $seconds = $elapsed % 60
                $timeStr = if ($minutes -gt 0) { "$minutes min $seconds sec" } else { "$seconds sec" }
                
                # Build meaningful progress message
                $progressMessage = ""
                $progressColor = "Gray"
                
                if ($progressInfo.Count -gt 0) {
                    $progressMessage = $progressInfo -join " | "
                    $progressColor = "Cyan"
                } else {
                    # Build status from checks
                    $statusParts = @()
                    
                    # Check WSL distribution status
                    try {
                        $wslListCheck = wsl --list --quiet 2>&1
                        if ($LASTEXITCODE -eq 0 -and $wslListCheck) {
                            $hasUbuntu = $wslListCheck | Where-Object { 
                                $_ -and 
                                ($_ -match 'Ubuntu' -or $_ -match 'ubuntu') -and 
                                $_ -notmatch '^NAME' -and
                                $_ -notmatch '^Windows'
                            }
                            if ($hasUbuntu) {
                                $statusParts += "WSL: Distribution found"
                                $progressColor = "Green"
                            } else {
                                $statusParts += "WSL: No distribution yet"
                            }
                        }
                    } catch {
                        $statusParts += "WSL: Checking..."
                    }
                    
                    # Check for active processes
                    $activeProcs = @()
                    try {
                        $storeProc = Get-Process -Name "Microsoft.Store" -ErrorAction SilentlyContinue
                        if ($storeProc) { $activeProcs += "Store" }
                    } catch {}
                    
                    try {
                        $wslProc = Get-Process -Name "wsl" -ErrorAction SilentlyContinue
                        if ($wslProc) { $activeProcs += "WSL" }
                    } catch {}
                    
                    if ($activeProcs.Count -gt 0) {
                        $statusParts += "Active: $($activeProcs -join ', ')"
                        $progressColor = "Yellow"
                    }
                    
                    if ($statusParts.Count -gt 0) {
                        $progressMessage = $statusParts -join " | "
                    } else {
                        $progressMessage = "Checking installation status..."
                    }
                }
                
                # Always write new line with progress
                Write-Log "  [$timeStr] $progressMessage" $progressColor
            }
            
            Write-Host ""  # New line after progress loop
            
            if (-not $installed) {
                Write-Log "[WARN] Ubuntu installation is taking longer than expected" "Yellow"
                Write-Log "The installation may still be in progress." "Yellow"
                Write-Log ""
                Write-Log "To check installation status: wsl --list --verbose" "Cyan"
                Write-Log "After Ubuntu is installed, run this script again to continue with Docker setup." "Yellow"
                Write-Log ""
                Write-Log "You can also check the Microsoft Store for installation progress." "Gray"
                exit 0
            }
        } catch {
            Write-Log "ERROR: Failed to install Ubuntu distribution: $_" "Red"
            Write-Log ""
            Write-Log "Manual installation options:" "Yellow"
            Write-Log "  1. Run: wsl --install -d Ubuntu" "Cyan"
            Write-Log "  2. Or install from Microsoft Store: Ubuntu" "Cyan"
            Write-Log "  3. Or use winget: winget install Canonical.Ubuntu" "Cyan"
            exit 1
        }
    } else {
        Write-Log "[OK] Linux distribution is installed" "Green"
    }
}

Write-Log ""
Write-Log "=================================================================" "Cyan"
Write-Log "  Phase 3: Docker Installation" "Cyan"
Write-Log "=================================================================" "Cyan"
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
        Write-Log "[OK] Docker installed in WSL2" "Green"
        Write-Log "Restarting WSL2 for group membership to take effect..." "Yellow"
        wsl --shutdown
        Start-Sleep -Seconds 3
        Write-Log "[OK] WSL2 restarted" "Green"
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
    Write-Log "[OK] Docker already installed" "Green"
    
    # Ensure Docker is running
    Write-Log "Ensuring Docker service is running..." "Yellow"
    try {
        wsl bash -c 'sudo service docker start 2>/dev/null || true'
        Write-Log "[OK] Docker service started" "Green"
    } catch {
        Write-Log "WARNING: Could not start Docker service" "Yellow"
    }
}

Write-Log ""
Write-Log "=================================================================" "Cyan"
Write-Log "  Phase 4: Model Configuration" "Cyan"
Write-Log "=================================================================" "Cyan"
Write-Log ""

# Convert Windows path to WSL path
$wslModelPath = $ModelPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }

Write-Log "Windows path: $ModelPath" "Cyan"
Write-Log "WSL2 path: $wslModelPath" "Cyan"
Write-Log ""

# Configure MODEL_DIR in WSL2
$bashrcConfig = "export MODEL_DIR='$wslModelPath'"
try {
    $bashCmd = "grep -q 'MODEL_DIR' ~/.bashrc || echo '$bashrcConfig' >> ~/.bashrc"
    wsl bash -c $bashCmd
    Write-Log "[OK] Model directory configured in WSL2" "Green"
} catch {
    Write-Log "WARNING: Could not configure bashrc automatically" "Yellow"
    Write-Log "Add this line to ~/.bashrc in WSL2: $bashrcConfig" "Yellow"
}

Write-Log ""

if (-not $SkipModels) {
    Write-Log "=================================================================" "Cyan"
    Write-Log "  Phase 5: Model Download" "Cyan"
    Write-Log "=================================================================" "Cyan"
    Write-Log ""

    $DownloadScript = Join-Path (Get-Location) "scripts\utils\Download-Light-Models.ps1"
    
    if (Test-Path $DownloadScript) {
        Write-Log "Downloading light models..." "Yellow"
        try {
            & $DownloadScript -ModelPath $ModelPath
            if ($LASTEXITCODE -eq 0) {
                Write-Log "[OK] Models downloaded successfully" "Green"
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
Write-Log "=================================================================" "Cyan"
Write-Log "  Phase 6: Container Setup" "Cyan"
Write-Log "=================================================================" "Cyan"
Write-Log ""

$repoPath = (Get-Location).Path
# Convert Windows path to WSL path (C:\Users\... -> /mnt/c/Users/...)
if ($repoPath -match '^([A-Z]):') {
    $driveLetter = $matches[1].ToLower()
    $wslRepoPath = $repoPath -replace '\\', '/' -replace "^$($matches[1]):", "/mnt/$driveLetter"
} else {
    $wslRepoPath = $repoPath -replace '\\', '/'
}

Write-Log "Pulling benchmark containers from GHCR..." "Yellow"
Write-Log "Repository path: $wslRepoPath" "Gray"
Write-Log ""

try {
    $pullOutput = wsl bash -c "cd '$wslRepoPath' && ./scripts/ci-cd/pull-from-ghcr.sh" 2>&1
    Write-Log $pullOutput "Gray"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log ""
        Write-Log "[OK] Containers pulled successfully from GHCR" "Green"
        
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
    Write-Log "=================================================================" "Cyan"
    Write-Log "  Phase 7: Validation Test" "Cyan"
    Write-Log "=================================================================" "Cyan"
    Write-Log ""

    Write-Log "Running quick validation test (2-3 minutes)..." "Yellow"
    Write-Log "This tests one light model to verify the complete setup" "Gray"
    Write-Log ""

    try {
        $testOutput = wsl bash -c "cd '$wslRepoPath/docker' && MODEL_CONFIG_MODE=light ./run-ai-models.sh --quick-test" 2>&1
        Write-Log $testOutput "Gray"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log ""
            Write-Log "[OK] Validation test PASSED" "Green"
        } else {
            Write-Log ""
            Write-Log "[X] Validation test FAILED" "Red"
            Write-Log "Check the output above for errors" "Yellow"
        }
    } catch {
        Write-Log "ERROR: Validation test failed: $_" "Red"
    }
} else {
    Write-Log "Phase 7: Validation Test - SKIPPED" "Yellow"
}

Write-Log ""
Write-Log "=================================================================" "Green"
Write-Log "  Setup Complete!" "Green"
Write-Log "=================================================================" "Green"
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
