# Windows Short Test - HP Readiness Validation
# Validates setup and runs quick benchmark to prove readiness for HP ZBook testing
# Usage: .\Test-Windows-Short.ps1

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Windows Short Test - HP Readiness Validation" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

$TestsPassed = 0
$TestsFailed = 0

function Test-Pass {
    param($Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Test-Fail {
    param($Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:TestsFailed++
    return $false
}

# Test 1: Setup Validation
Write-Host "Step 1: Validating Windows Setup..." -ForegroundColor Yellow
Write-Host ""

$repoPath = (Get-Location).Path
if (-not (Test-Path "$repoPath\scripts\testing\Test-Windows-Setup.ps1")) {
    Write-Host "ERROR: Must run from vtt-hw-benchmarks root directory" -ForegroundColor Red
    exit 1
}

# Run setup validation (check-only)
Write-Host "Running setup validation..." -ForegroundColor Gray
& "$repoPath\scripts\testing\Test-Windows-Setup.ps1"

if ($LASTEXITCODE -eq 0) {
    Test-Pass "Setup validation complete"
} else {
    Test-Fail "Setup validation failed - fix issues before proceeding"
    Write-Host ""
    Write-Host "Run setup script to install WSL2 and complete setup:" -ForegroundColor Yellow
    Write-Host "  .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP.ps1" -ForegroundColor White
    Write-Host "Or use the interactive menu:" -ForegroundColor Yellow
    Write-Host "  .\scripts\setup\hp-zbook\HP-ZBOOK-SETUP-INTERACTIVE.ps1" -ForegroundColor White
    Write-Host "  (Select option 1: Run full setup)" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# Test 2: Quick Benchmark
Write-Host "Step 2: Running Quick Benchmark (2-3 minutes)..." -ForegroundColor Yellow
Write-Host "This validates the complete setup including model access and GPU acceleration" -ForegroundColor Gray
Write-Host ""

# Convert Windows path to WSL path (C:\Users\... -> /mnt/c/Users/...)
if ($repoPath -match '^([A-Z]):') {
    $driveLetter = $matches[1].ToLower()
    $wslRepoPath = $repoPath -replace '\\', '/' -replace "^$($matches[1]):", "/mnt/$driveLetter"
} else {
    $wslRepoPath = $repoPath -replace '\\', '/'
}

try {
    Write-Host "Executing quick test in WSL2..." -ForegroundColor Gray
    $benchResult = wsl bash -c "cd '$wslRepoPath/docker' && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Test-Pass "Quick benchmark completed successfully"
        Write-Host ""
        Write-Host "Benchmark output:" -ForegroundColor Cyan
        Write-Host $benchResult -ForegroundColor Gray
    } else {
        Test-Fail "Quick benchmark failed"
        Write-Host ""
        Write-Host "Error output:" -ForegroundColor Red
        Write-Host $benchResult -ForegroundColor Gray
        exit 1
    }
} catch {
    Test-Fail "Quick benchmark failed: $_"
    exit 1
}

Write-Host ""

# Summary
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

if ($TestsFailed -eq 0) {
    Write-Host "✅ All tests passed! ($TestsPassed/$($TestsPassed + $TestsFailed))" -ForegroundColor Green
    Write-Host ""
    Write-Host "Windows setup is validated and ready for HP ZBook testing!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  Run full default benchmark (30-45 min):" -ForegroundColor White
    Write-Host "    wsl" -ForegroundColor Gray
    Write-Host "    cd /mnt/c/repos/vtt-hw-benchmarks/docker" -ForegroundColor Gray
    Write-Host "    MODEL_CONFIG_MODE=default ./run-ai-models.sh" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "❌ Some tests failed ($TestsFailed failed, $TestsPassed passed)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above before proceeding with HP testing." -ForegroundColor Yellow
    exit 1
}
