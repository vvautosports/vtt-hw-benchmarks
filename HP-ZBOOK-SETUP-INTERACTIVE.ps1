# HP ZBook Interactive Setup with Terminal GUI
# Simple menu-driven setup process
# Usage: .\HP-ZBOOK-SETUP-INTERACTIVE.ps1

$ErrorActionPreference = "Continue"

function Show-Menu {
    param([string]$Title, [array]$Options)
    
    Clear-Host
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
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

# Main menu
$mainMenu = @(
    "Install GitHub CLI (if needed)",
    "Authenticate with GitHub",
    "Clone repository",
    "Run setup script",
    "Do everything automatically"
)

$ghInstalled = $false
$ghAuthenticated = $false
$repoCloned = $false

while ($true) {
    Show-Menu -Title "HP ZBook Setup" -Options $mainMenu
    
    # Show status
    Write-Host "Status:" -ForegroundColor Cyan
    $ghStatus = if ($ghInstalled) { "✓ Installed" } else { "✗ Not installed" }
    $authStatus = if ($ghAuthenticated) { "✓ Authenticated" } else { "✗ Not authenticated" }
    $repoStatus = if ($repoCloned) { "✓ Cloned" } else { "✗ Not cloned" }
    Write-Host "  GitHub CLI: $ghStatus" -ForegroundColor $(if ($ghInstalled) { "Green" } else { "Yellow" })
    Write-Host "  GitHub Auth: $authStatus" -ForegroundColor $(if ($ghAuthenticated) { "Green" } else { "Yellow" })
    Write-Host "  Repository: $repoStatus" -ForegroundColor $(if ($repoCloned) { "Green" } else { "Yellow" })
    Write-Host ""
    
    $choice = Get-MenuChoice -MaxChoice $mainMenu.Length
    
    switch ($choice) {
        0 { 
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        1 {
            Write-Host ""
            Write-Host "Checking GitHub CLI..." -ForegroundColor Yellow
            try {
                $ghVersion = gh --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ GitHub CLI is already installed" -ForegroundColor Green
                    $ghInstalled = $true
                }
            } catch {
                Write-Host "Installing GitHub CLI..." -ForegroundColor Yellow
                winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                Write-Host "✓ GitHub CLI installed" -ForegroundColor Green
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Start-Sleep -Seconds 2
                $ghInstalled = $true
            }
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        2 {
            if (-not $ghInstalled) {
                Write-Host ""
                Write-Host "ERROR: GitHub CLI must be installed first" -ForegroundColor Red
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            Write-Host ""
            Write-Host "Checking authentication..." -ForegroundColor Yellow
            try {
                $authStatus = gh auth status 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Already authenticated" -ForegroundColor Green
                    $ghAuthenticated = $true
                }
            } catch {
                Write-Host "Starting authentication..." -ForegroundColor Yellow
                Write-Host "This will open your browser." -ForegroundColor Gray
                gh auth login
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Authentication successful" -ForegroundColor Green
                    $ghAuthenticated = $true
                } else {
                    Write-Host "✗ Authentication failed" -ForegroundColor Red
                }
            }
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        3 {
            if (-not $ghAuthenticated) {
                Write-Host ""
                Write-Host "ERROR: Must authenticate with GitHub first" -ForegroundColor Red
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            Write-Host ""
            $repoPath = "C:\vtt-hw-benchmarks"
            if (Test-Path $repoPath) {
                Write-Host "Repository already exists at $repoPath" -ForegroundColor Yellow
                $response = Read-Host "Use existing? (y/n)"
                if ($response -eq 'y') {
                    $repoCloned = $true
                }
            } else {
                Write-Host "Cloning repository..." -ForegroundColor Yellow
                gh repo clone vvautosports/vtt-hw-benchmarks $repoPath
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Repository cloned" -ForegroundColor Green
                    $repoCloned = $true
                } else {
                    Write-Host "✗ Clone failed" -ForegroundColor Red
                }
            }
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        4 {
            if (-not $repoCloned) {
                Write-Host ""
                Write-Host "ERROR: Repository must be cloned first" -ForegroundColor Red
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                continue
            }
            Write-Host ""
            Write-Host "Running setup script..." -ForegroundColor Yellow
            Set-Location "C:\vtt-hw-benchmarks"
            & .\HP-ZBOOK-SETUP.ps1
            Write-Host ""
            Write-Host "Press any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        5 {
            Write-Host ""
            Write-Host "Running automatic setup..." -ForegroundColor Cyan
            Write-Host ""
            
            # Install gh if needed
            if (-not $ghInstalled) {
                Write-Host "Installing GitHub CLI..." -ForegroundColor Yellow
                winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
                Start-Sleep -Seconds 2
                $ghInstalled = $true
            }
            
            # Authenticate if needed
            if (-not $ghAuthenticated) {
                Write-Host "Authenticating with GitHub..." -ForegroundColor Yellow
                gh auth login
                $ghAuthenticated = $true
            }
            
            # Clone if needed
            if (-not $repoCloned) {
                Write-Host "Cloning repository..." -ForegroundColor Yellow
                gh repo clone vvautosports/vtt-hw-benchmarks C:\vtt-hw-benchmarks
                $repoCloned = $true
            }
            
            # Run setup
            Write-Host "Running setup script..." -ForegroundColor Yellow
            Set-Location "C:\vtt-hw-benchmarks"
            & .\HP-ZBOOK-SETUP.ps1
            
            Write-Host ""
            Write-Host "Setup complete!" -ForegroundColor Green
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 0
        }
    }
}
