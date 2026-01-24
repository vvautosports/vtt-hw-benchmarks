# Windows Setup Test Suite
# Validates that setup-windows-full.ps1 completed successfully
# Usage: .\Test-Windows-Setup.ps1 [-FullTest]

param(
    [switch]$FullTest
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Windows Setup Test Suite" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
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

# Test 1: WSL2 Installation
Write-Host "Test 1: WSL2 Status..." -ForegroundColor Yellow
try {
    $wslStatus = wsl --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Pass "WSL2 is installed"
        Write-Host "  $wslStatus" -ForegroundColor Gray
    } else {
        Test-Fail "WSL2 not installed - run: wsl --install"
        exit 1
    }
} catch {
    Test-Fail "WSL2 check failed: $_"
    exit 1
}
Write-Host ""

# Test 2: Docker in WSL2
Write-Host "Test 2: Docker in WSL2..." -ForegroundColor Yellow
try {
    $dockerVersion = wsl bash -c "docker --version" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Pass "Docker installed in WSL2"
        Write-Host "  $dockerVersion" -ForegroundColor Gray
    } else {
        Test-Fail "Docker not installed in WSL2"
        Write-Host "  Install with: curl -fsSL https://get.docker.com | sudo sh" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Test-Fail "Docker check failed: $_"
    exit 1
}
Write-Host ""

# Test 3: Docker Service Running
Write-Host "Test 3: Docker Service..." -ForegroundColor Yellow
try {
    $dockerInfo = wsl bash -c "docker info" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Pass "Docker service is running"
    } else {
        Test-Fail "Docker service not running"
        Write-Host "  Start with: wsl sudo service docker start" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Test-Fail "Docker service check failed: $_"
    exit 1
}
Write-Host ""

# Test 4: Benchmark Containers
Write-Host "Test 4: Benchmark Containers..." -ForegroundColor Yellow
try {
    $containers = wsl bash -c "docker images --format '{{.Repository}}:{{.Tag}}' | grep vtt-benchmark" 2>&1
    if ($containers -and $LASTEXITCODE -eq 0) {
        $count = ($containers -split "`n" | Where-Object { $_ -match "vtt-benchmark" }).Count
        Test-Pass "Found $count benchmark container(s)"
        Write-Host "  Containers:" -ForegroundColor Gray
        $containers -split "`n" | Where-Object { $_ -match "vtt-benchmark" } | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
    } else {
        Test-Fail "No benchmark containers found"
        Write-Host "  Pull with: wsl bash -c 'cd /mnt/c/vtt-hw-benchmarks && ./scripts/ci-cd/pull-from-ghcr.sh'" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Test-Fail "Container check failed: $_"
    exit 1
}
Write-Host ""

# Test 5: Model Directory (if configured)
Write-Host "Test 5: Model Directory..." -ForegroundColor Yellow
try {
    $modelDir = wsl bash -c "echo `$MODEL_DIR" 2>&1
    if ($modelDir -and $modelDir -ne "") {
        $modelPath = $modelDir.Trim()
        $modelExists = wsl bash -c "test -d '$modelPath' && echo 'exists' || echo 'missing'" 2>&1
        if ($modelExists -match "exists") {
            $modelCount = wsl bash -c "find '$modelPath' -name '*.gguf' -type f 2>/dev/null | wc -l" 2>&1
            Test-Pass "Model directory configured: $modelPath ($modelCount GGUF files)"
        } else {
            Write-Host "[WARN] MODEL_DIR set but directory not found: $modelPath" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[INFO] MODEL_DIR not configured (optional)" -ForegroundColor Gray
    }
} catch {
    Write-Host "[WARN] Model directory check failed: $_" -ForegroundColor Yellow
}
Write-Host ""

# Test 6: Repository Access
Write-Host "Test 6: Repository Access..." -ForegroundColor Yellow
try {
    $repoPath = (Get-Location).Path
    $wslRepoPath = $repoPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }
    $repoExists = wsl bash -c "test -d '$wslRepoPath' && echo 'exists' || echo 'missing'" 2>&1
    if ($repoExists -match "exists") {
        Test-Pass "Repository accessible in WSL2: $wslRepoPath"
    } else {
        Test-Fail "Repository not accessible in WSL2"
        exit 1
    }
} catch {
    Test-Fail "Repository check failed: $_"
    exit 1
}
Write-Host ""

# Test 7: Quick Benchmark (if FullTest)
if ($FullTest) {
    Write-Host "Test 7: Quick Benchmark..." -ForegroundColor Yellow
    try {
        $repoPath = (Get-Location).Path
        $wslRepoPath = $repoPath -replace '\\', '/' -replace '^([A-Z]):', { "/mnt/$($_.Groups[1].Value.ToLower())" }
        
        Write-Host "  Running quick test (this may take 2-3 minutes)..." -ForegroundColor Gray
        $benchResult = wsl bash -c "cd '$wslRepoPath/docker' && MODEL_CONFIG_MODE=default ./run-ai-models.sh --quick-test" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Test-Pass "Quick benchmark completed successfully"
        } else {
            Test-Fail "Quick benchmark failed"
            Write-Host "  Output:" -ForegroundColor Yellow
            Write-Host $benchResult -ForegroundColor Gray
            exit 1
        }
    } catch {
        Test-Fail "Quick benchmark failed: $_"
        exit 1
    }
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($TestsFailed -eq 0) {
    Write-Host "✅ All tests passed! ($TestsPassed/$($TestsPassed + $TestsFailed))" -ForegroundColor Green
    Write-Host ""
    Write-Host "Windows setup is complete and ready for benchmarking." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  wsl" -ForegroundColor White
    Write-Host "  cd /mnt/c/vtt-hw-benchmarks/docker" -ForegroundColor White
    Write-Host "  ./run-all.sh                                    # All non-AI benchmarks" -ForegroundColor White
    Write-Host "  MODEL_CONFIG_MODE=default ./run-ai-models.sh   # AI model benchmarks" -ForegroundColor White
    exit 0
} else {
    Write-Host "❌ Some tests failed ($TestsFailed failed, $TestsPassed passed)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above and run the setup script again:" -ForegroundColor Yellow
    Write-Host "  .\scripts\utils\setup-windows-full.ps1" -ForegroundColor White
    exit 1
}
