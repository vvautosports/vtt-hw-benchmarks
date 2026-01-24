# HP ZBook One-Command Setup
# Installs GitHub CLI, authenticates, clones repo, and runs setup
# Usage: .\HP-ZBOOK-SETUP-ONE-COMMAND.ps1

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  HP ZBook - One-Command Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host ""
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or run:" -ForegroundColor Yellow
    Write-Host "  Start-Process powershell -Verb RunAs -ArgumentList '-File', '.\HP-ZBOOK-SETUP-ONE-COMMAND.ps1'" -ForegroundColor Gray
    exit 1
}

# Step 1: Check/Install GitHub CLI
Write-Host "Step 1: Checking GitHub CLI..." -ForegroundColor Yellow
$ghInstalled = $false
try {
    $ghVersion = gh --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ghInstalled = $true
        Write-Host "✓ GitHub CLI is installed" -ForegroundColor Green
    }
} catch {
    $ghInstalled = $false
}

if (-not $ghInstalled) {
    Write-Host "Installing GitHub CLI via winget..." -ForegroundColor Yellow
    try {
        winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        Write-Host "✓ GitHub CLI installed" -ForegroundColor Green
        Write-Host "Refreshing PATH..." -ForegroundColor Gray
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 2
        
        # Verify gh is now available
        $ghVersion = gh --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: GitHub CLI installed but not in PATH. Please restart PowerShell and try again." -ForegroundColor Yellow
            exit 1
        }
    } catch {
        Write-Host "ERROR: Could not install GitHub CLI" -ForegroundColor Red
        Write-Host "Please install manually: winget install --id GitHub.cli" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""

# Step 2: Check GitHub authentication
Write-Host "Step 2: Checking GitHub authentication..." -ForegroundColor Yellow
$ghAuthenticated = $false
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ghAuthenticated = $true
        Write-Host "✓ Already authenticated with GitHub" -ForegroundColor Green
    }
} catch {
    $ghAuthenticated = $false
}

if (-not $ghAuthenticated) {
    Write-Host "GitHub authentication required..." -ForegroundColor Yellow
    Write-Host "This will open your browser to authenticate." -ForegroundColor Gray
    Write-Host ""
    $response = Read-Host "Continue with authentication? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Setup cancelled." -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Opening GitHub authentication..." -ForegroundColor Cyan
    Write-Host "Follow the prompts in your browser." -ForegroundColor Gray
    Write-Host ""
    
    try {
        gh auth login
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Authentication successful" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Authentication failed" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "ERROR: Authentication failed: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 3: Clone repository
Write-Host "Step 3: Cloning repository..." -ForegroundColor Yellow
$repoPath = "C:\vtt-hw-benchmarks"

if (Test-Path $repoPath) {
    Write-Host "Repository already exists at $repoPath" -ForegroundColor Yellow
    $response = Read-Host "Use existing repository? (y/n)"
    if ($response -ne 'y') {
        Write-Host "Please remove the existing directory and try again." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Cloning vvautosports/vtt-hw-benchmarks..." -ForegroundColor Gray
    try {
        gh repo clone vvautosports/vtt-hw-benchmarks $repoPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Repository cloned successfully" -ForegroundColor Green
        } else {
            Write-Host "ERROR: Clone failed" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "ERROR: Clone failed: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 4: Run setup script
Write-Host "Step 4: Running setup script..." -ForegroundColor Yellow
Write-Host ""

Set-Location $repoPath

if (-not (Test-Path ".\HP-ZBOOK-SETUP.ps1")) {
    Write-Host "ERROR: Setup script not found" -ForegroundColor Red
    exit 1
}

& .\HP-ZBOOK-SETUP.ps1
