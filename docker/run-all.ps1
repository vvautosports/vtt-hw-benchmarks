# Run all benchmarks on Windows (requires Docker Desktop)
# Usage: .\run-all.ps1 [-LlamaModel "C:\path\to\model.gguf"]

param(
    [string]$LlamaModel = "",
    [string]$ResultsDir = "..\results"
)

$ErrorActionPreference = "Stop"

# Create results directory
if (!(Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Hostname = $env:COMPUTERNAME
$OutputFile = Join-Path $ResultsDir "benchmark-$Hostname-$Timestamp.json"
$LogFile = Join-Path $ResultsDir "benchmark-$Hostname-$Timestamp.log"

function Log {
    param($Message)
    Write-Host $Message
    Add-Content -Path $LogFile -Value $Message
}

Log "=== VTT Hardware Benchmark Suite ==="
Log "Host: $Hostname"
Log "Date: $(Get-Date -Format 'o')"
Log "Results: $OutputFile"
Log ""

# Get system info
$CPU = (Get-WmiObject -Class Win32_Processor).Name
$Cores = (Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors
$MemGB = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

Log "System Information:"
Log "  CPU: $CPU"
Log "  Cores: $Cores"
Log "  Memory: $MemGB GB"
Log ""

# Check if Docker is running
try {
    docker ps | Out-Null
} catch {
    Write-Error "Docker is not running. Please start Docker Desktop."
    exit 1
}

# Initialize results JSON
@"
{
  "hostname": "$Hostname",
  "timestamp": "$(Get-Date -Format 'o')",
  "system": {
    "cpu": "$CPU",
    "cores": $Cores,
    "memory_gb": $MemGB
  },
  "benchmarks": {
"@ | Out-File -FilePath $OutputFile -Encoding UTF8

$First = $true

function Add-Result {
    param($Name, $Result)

    if (-not $First) {
        "," | Add-Content -Path $OutputFile
    }
    $script:First = $false

    "    `"$Name`": $Result" | Add-Content -Path $OutputFile
}

# Run 7-Zip benchmark
Log "Running 7-Zip benchmark..."
$Result7Zip = docker run --rm vtt-benchmark-7zip 2>&1 | Out-String
Log $Result7Zip
$Json7Zip = ($Result7Zip -split "`n" | Select-Object -Last 1).Trim()
Add-Result "7zip" $Json7Zip
Log ""

# Run STREAM benchmark
Log "Running STREAM benchmark..."
$ResultStream = docker run --rm vtt-benchmark-stream 2>&1 | Out-String
Log $ResultStream
$JsonStream = ($ResultStream -split "`n" | Select-Object -Last 1).Trim()
Add-Result "stream" $JsonStream
Log ""

# Run Storage benchmark
Log "Running Storage benchmark..."
$ResultStorage = docker run --rm vtt-benchmark-storage 2>&1 | Out-String
Log $ResultStorage
$JsonStorage = ($ResultStorage -split "`n" | Select-Object -Last 1).Trim()
Add-Result "storage" $JsonStorage
Log ""

# Run LLaMA benchmark (if model provided)
if ($LlamaModel -and (Test-Path $LlamaModel)) {
    Log "Running LLaMA benchmark with model: $LlamaModel"

    # Convert Windows path to Docker volume format
    $ModelPath = $LlamaModel.Replace('\', '/')
    if ($ModelPath -match '^([A-Za-z]):') {
        $Drive = $matches[1].ToLower()
        $ModelPath = "/$Drive" + $ModelPath.Substring(2)
    }

    $ResultLlama = docker run --rm `
        -v "${LlamaModel}:/models/model.gguf" `
        vtt-benchmark-llama 2>&1 | Out-String
    Log $ResultLlama
    $JsonLlama = ($ResultLlama -split "`n" | Select-Object -Last 1).Trim()
    Add-Result "llama" $JsonLlama
    Log ""
} else {
    Log "Skipping LLaMA benchmark (no model specified)"
    Log "Use -LlamaModel parameter to include AI inference test"
    Log ""
}

# Close JSON
@"

  }
}
"@ | Add-Content -Path $OutputFile

Log "=== Benchmark Suite Complete ==="
Log ""
Log "Results saved to:"
Log "  JSON: $OutputFile"
Log "  Log:  $LogFile"
Log ""

# Pretty print results summary
Log "Summary:"
if (Get-Command jq -ErrorAction SilentlyContinue) {
    Get-Content $OutputFile | jq '.benchmarks' | Tee-Object -FilePath $LogFile -Append
} else {
    Get-Content $OutputFile | Tee-Object -FilePath $LogFile -Append
}
