# Automated Test Runner for Windows Setup Scripts
# Runs setup and validation scripts non-interactively
# Usage: .\run-automated-tests.ps1 [-FullTest]

param(
    [switch]$FullTest
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Automated Windows Setup Test Runner" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$TestResults = @{
    SetupScript = $false
    ValidationScript = $false
    DockerTest = $false
    ContainerTest = $false
}

# Test 1: Run setup script (non-interactive)
Write-Host "Test 1: Running setup script (non-interactive)..." -ForegroundColor Yellow
try {
    $setupOutput = .\scripts\utils\setup-windows-full.ps1 -NonInteractive -SkipTests -SkipContainers 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
        $TestResults.SetupScript = $true
        Write-Host "[PASS] Setup script executed" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Setup script failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host $setupOutput -ForegroundColor Gray
    }
} catch {
    Write-Host "[FAIL] Setup script error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 2: Run validation script
Write-Host "Test 2: Running validation script..." -ForegroundColor Yellow
try {
    if ($FullTest) {
        $validationOutput = .\scripts\testing\Test-Windows-Setup.ps1 -FullTest 2>&1
    } else {
        $validationOutput = .\scripts\testing\Test-Windows-Setup.ps1 2>&1
    }
    
    if ($LASTEXITCODE -eq 0) {
        $TestResults.ValidationScript = $true
        Write-Host "[PASS] Validation script passed" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Validation script failed with exit code $LASTEXITCODE" -ForegroundColor Red
        Write-Host $validationOutput -ForegroundColor Gray
    }
} catch {
    Write-Host "[FAIL] Validation script error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 3: Docker functionality
Write-Host "Test 3: Testing Docker in WSL2..." -ForegroundColor Yellow
try {
    $dockerVersion = wsl bash -c "docker --version" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $TestResults.DockerTest = $true
        Write-Host "[PASS] Docker is available: $dockerVersion" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Docker not available (may not be installed)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[SKIP] Docker test skipped: $_" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Container availability
Write-Host "Test 4: Checking benchmark containers..." -ForegroundColor Yellow
try {
    $containers = wsl bash -c "docker images --format '{{.Repository}}:{{.Tag}}' | grep vtt-benchmark" 2>&1
    if ($containers -and $LASTEXITCODE -eq 0) {
        $count = ($containers -split "`n" | Where-Object { $_ -match "vtt-benchmark" }).Count
        $TestResults.ContainerTest = $true
        Write-Host "[PASS] Found $count benchmark container(s)" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] No containers found (expected if -SkipContainers was used)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[SKIP] Container check skipped: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$passed = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
$total = $TestResults.Count

Write-Host "Setup Script:        $(if ($TestResults.SetupScript) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($TestResults.SetupScript) { 'Green' } else { 'Red' })
Write-Host "Validation Script:  $(if ($TestResults.ValidationScript) { '[PASS]' } else { '[FAIL]' })" -ForegroundColor $(if ($TestResults.ValidationScript) { 'Green' } else { 'Red' })
Write-Host "Docker Test:        $(if ($TestResults.DockerTest) { '[PASS]' } else { '[SKIP]' })" -ForegroundColor $(if ($TestResults.DockerTest) { 'Green' } else { 'Yellow' })
Write-Host "Container Test:     $(if ($TestResults.ContainerTest) { '[PASS]' } else { '[SKIP]' })" -ForegroundColor $(if ($TestResults.ContainerTest) { 'Green' } else { 'Yellow' })
Write-Host ""

if ($TestResults.SetupScript -and $TestResults.ValidationScript) {
    Write-Host "✅ Core tests passed ($passed/$total)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Core tests failed" -ForegroundColor Red
    exit 1
}
