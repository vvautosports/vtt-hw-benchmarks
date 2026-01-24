# Download Light Models from HuggingFace
# Downloads the light-mode models specified in model-config.yaml
# Usage: .\Download-Light-Models.ps1 [-ModelPath "D:\ai-models"] [-Force]

param(
    [string]$ModelPath = "D:\ai-models",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  VTT Hardware Benchmarks - Light Model Downloader" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Models to download (from model-config.yaml light_models)
$Models = @(
    @{
        Name = "GPT-OSS-20B"
        Repo = "unsloth/gpt-oss-20b-F16-GGUF"
        File = "gpt-oss-20b-F16.gguf"
        SizeGB = 13
        SubDir = "gpt-oss-20b-F16"
    },
    @{
        Name = "Qwen3-8B-128K-Q8"
        Repo = "unsloth/Qwen3-8B-128K-GGUF"
        File = "qwen3-8b-128k-q8_0.gguf"
        SizeGB = 9
        SubDir = "Qwen3-8B-128K-Q8"
    }
)

$TotalSizeGB = ($Models | Measure-Object -Property SizeGB -Sum).Sum

Write-Host "Download Configuration:" -ForegroundColor Cyan
Write-Host "  Target Directory: $ModelPath" -ForegroundColor White
Write-Host "  Models to Download: $($Models.Count)" -ForegroundColor White
Write-Host "  Total Size: ~${TotalSizeGB}GB" -ForegroundColor White
Write-Host ""

# Check disk space
$TargetDrive = Split-Path -Qualifier $ModelPath
try {
    # Use WMI for more reliable disk space check
    $driveLetter = $TargetDrive.TrimEnd(':')
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$TargetDrive'" -ErrorAction Stop
    $FreeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
} catch {
    # Fallback to Get-PSDrive
    try {
        $Drive = Get-PSDrive -Name $driveLetter -ErrorAction Stop
        $FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)
    } catch {
        Write-Host "WARNING: Could not check disk space for $TargetDrive" -ForegroundColor Yellow
        $FreeSpaceGB = 0
    }
}

Write-Host "Available Disk Space: ${FreeSpaceGB}GB" -ForegroundColor $(if ($FreeSpaceGB -gt ($TotalSizeGB * 1.2)) { "Green" } else { "Yellow" })

if ($FreeSpaceGB -lt ($TotalSizeGB * 1.2)) {
    Write-Host ""
    Write-Host "WARNING: Low disk space. Recommended: $([math]::Round($TotalSizeGB * 1.2, 0))GB" -ForegroundColor Yellow
    Write-Host "Available: ${FreeSpaceGB}GB" -ForegroundColor Yellow
    
    if (-not $Force) {
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y') {
            Write-Host "Download cancelled." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""

# Create model directory
if (-not (Test-Path $ModelPath)) {
    Write-Host "Creating model directory: $ModelPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $ModelPath -Force | Out-Null
    Write-Host "[OK] Directory created" -ForegroundColor Green
}

Write-Host ""

# Download each model
$SuccessCount = 0
$SkippedCount = 0
$FailedCount = 0

foreach ($Model in $Models) {
    Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Model: $($Model.Name)" -ForegroundColor Cyan
    Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "  Repository: $($Model.Repo)" -ForegroundColor Gray
    Write-Host "  File: $($Model.File)" -ForegroundColor Gray
    Write-Host "  Size: ~$($Model.SizeGB)GB" -ForegroundColor Gray
    Write-Host ""

    # Create subdirectory
    $TargetDir = Join-Path $ModelPath $Model.SubDir
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $TargetFile = Join-Path $TargetDir $Model.File

    # Check if already exists
    if ((Test-Path $TargetFile) -and -not $Force) {
        Write-Host "  [SKIP]  Model already exists, skipping" -ForegroundColor Yellow
        Write-Host "  Path: $TargetFile" -ForegroundColor Gray
        $SkippedCount++
        Write-Host ""
        continue
    }

    # Download using HuggingFace Hub URL
    $HFUrl = "https://huggingface.co/$($Model.Repo)/resolve/main/$($Model.File)"
    
    Write-Host "  Downloading from HuggingFace..." -ForegroundColor Yellow
    Write-Host "  URL: $HFUrl" -ForegroundColor Gray
    Write-Host ""

    try {
        # Use BITS transfer for resumable downloads
        $BitsJob = Start-BitsTransfer -Source $HFUrl -Destination $TargetFile -DisplayName "Downloading $($Model.Name)" -Description $Model.File -Asynchronous

        # Monitor progress
        while ($BitsJob.JobState -eq "Transferring" -or $BitsJob.JobState -eq "Connecting") {
            $Progress = [math]::Round(($BitsJob.BytesTransferred / $BitsJob.BytesTotal) * 100, 1)
            $TransferredGB = [math]::Round($BitsJob.BytesTransferred / 1GB, 2)
            $TotalGB = [math]::Round($BitsJob.BytesTotal / 1GB, 2)
            
            Write-Progress -Activity "Downloading $($Model.Name)" -Status "$TransferredGB GB / $TotalGB GB" -PercentComplete $Progress
            Start-Sleep -Seconds 2
        }

        Complete-BitsTransfer -BitsJob $BitsJob
        Write-Progress -Activity "Downloading $($Model.Name)" -Completed

        if (Test-Path $TargetFile) {
            $FileSize = (Get-Item $TargetFile).Length
            $FileSizeGB = [math]::Round($FileSize / 1GB, 2)
            Write-Host "  [OK] Download complete!" -ForegroundColor Green
            Write-Host "  Saved to: $TargetFile" -ForegroundColor Gray
            Write-Host "  Size: ${FileSizeGB}GB" -ForegroundColor Gray
            $SuccessCount++
        } else {
            throw "File not found after download"
        }

    } catch {
        Write-Host "  [X] Download failed: $_" -ForegroundColor Red
        $FailedCount++
        
        if ($BitsJob) {
            Remove-BitsTransfer -BitsJob $BitsJob -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
}

# Summary
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Download Summary" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

if ($SuccessCount -gt 0) {
    Write-Host "[OK] Successfully downloaded: $SuccessCount" -ForegroundColor Green
}
if ($SkippedCount -gt 0) {
    Write-Host "[SKIP]  Skipped (already exists): $SkippedCount" -ForegroundColor Yellow
}
if ($FailedCount -gt 0) {
    Write-Host "[X] Failed: $FailedCount" -ForegroundColor Red
}

Write-Host ""

if ($FailedCount -eq 0) {
    Write-Host "All models ready in: $ModelPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run benchmarks in WSL2:" -ForegroundColor White
    Write-Host "     wsl" -ForegroundColor Gray
    Write-Host "     cd /mnt/c/repos/vtt-hw-benchmarks/docker" -ForegroundColor Gray
    Write-Host "     MODEL_CONFIG_MODE=light ./run-ai-models.sh" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "Some downloads failed. Check network connection and try again." -ForegroundColor Red
    Write-Host "Use -Force to re-download existing files." -ForegroundColor Yellow
    exit 1
}
