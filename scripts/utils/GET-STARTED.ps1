# VTT Hardware Benchmark Suite - Quick Start Script
# This script can be downloaded and run to fetch setup instructions
# Usage: powershell -ExecutionPolicy Bypass -File .\GET-STARTED.ps1

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmark Suite - Quick Start" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will help you get setup instructions for the VTT Hardware Benchmark Suite." -ForegroundColor Gray
Write-Host ""

# Check if we're in a repo already
$inRepo = Test-Path ".git"
if ($inRepo) {
    Write-Host "[OK] Already in repository - setup instructions are in README.md" -ForegroundColor Green
    Write-Host ""
    Write-Host "View instructions:" -ForegroundColor Cyan
    Write-Host "  Get-Content README.md | more" -ForegroundColor White
    Write-Host "  or" -ForegroundColor Gray
    Write-Host "  notepad README.md" -ForegroundColor White
    exit 0
}

Write-Host "Not in repository. Fetching setup instructions..." -ForegroundColor Yellow
Write-Host ""

# Try to download the fetch script from GitHub
$fetchScript = "Fetch-Setup-Instructions.ps1"
$repo = "vvautosports/vtt-hw-benchmarks"
$branch = "master"

Write-Host "Attempting to fetch setup instructions..." -ForegroundColor Yellow

# Method 1: Try GitHub CLI
try {
    $ghVersion = gh --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] GitHub CLI detected" -ForegroundColor Green
        
        # Check auth
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "GitHub CLI not authenticated. Please authenticate first:" -ForegroundColor Yellow
            Write-Host "  gh auth login" -ForegroundColor White
            Write-Host ""
            Write-Host "Then run this script again, or use the manual method below." -ForegroundColor Gray
            exit 1
        }
        
        # Fetch README
        Write-Host "Fetching README.md..." -ForegroundColor Yellow
        $readmeContent = gh api repos/$repo/contents/README.md --jq '.content' | ForEach-Object {
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
        }
        
        $readmeContent | Out-File -FilePath "SETUP-INSTRUCTIONS.md" -Encoding UTF8
        Write-Host "[OK] Instructions saved to: SETUP-INSTRUCTIONS.md" -ForegroundColor Green
        Write-Host ""
        Write-Host "View instructions:" -ForegroundColor Cyan
        Write-Host "  notepad SETUP-INSTRUCTIONS.md" -ForegroundColor White
        exit 0
    }
} catch {
    # GitHub CLI not available
}

# Method 2: Provide manual instructions
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host "  Manual Setup Instructions" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Yellow
Write-Host ""

Write-Host "To get started, you need to:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Install GitHub CLI:" -ForegroundColor White
Write-Host "   winget install --id GitHub.cli" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Authenticate with GitHub:" -ForegroundColor White
Write-Host "   gh auth login" -ForegroundColor Gray
Write-Host "   (Follow the browser prompts)" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Clone the repository:" -ForegroundColor White
Write-Host "   gh repo clone $repo" -ForegroundColor Gray
Write-Host "   cd vtt-hw-benchmarks" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Run the interactive setup:" -ForegroundColor White
Write-Host "   powershell -ExecutionPolicy Bypass -File .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Or view instructions online:" -ForegroundColor Cyan
Write-Host "   https://github.com/$repo/blob/$branch/README.md" -ForegroundColor Gray
Write-Host ""
exit 0
