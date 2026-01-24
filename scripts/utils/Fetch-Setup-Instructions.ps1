# Fetch Setup Instructions from GitHub
# Downloads setup instructions from the repository without requiring full clone access
# Usage: .\Fetch-Setup-Instructions.ps1 [-OutputPath "setup-instructions.md"]

param(
    [string]$OutputPath = "setup-instructions.md",
    [string]$Repo = "vvautosports/vtt-hw-benchmarks",
    [string]$Branch = "master"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Fetch Setup Instructions from GitHub" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# Try GitHub CLI first (if available)
$useGitHubCLI = $false
try {
    $ghVersion = gh --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        $useGitHubCLI = $true
        Write-Host "[OK] GitHub CLI detected" -ForegroundColor Green
    }
} catch {
    Write-Host "[INFO] GitHub CLI not available, will try alternative methods" -ForegroundColor Yellow
}

# Method 1: Use GitHub CLI (if available)
if ($useGitHubCLI) {
    Write-Host "Fetching README.md using GitHub CLI..." -ForegroundColor Yellow
    
    try {
        # Check if authenticated
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARN] Not authenticated with GitHub CLI" -ForegroundColor Yellow
            Write-Host "Authenticating..." -ForegroundColor Yellow
            gh auth login
        }
        
        # Fetch README
        $readmeContent = gh api repos/$Repo/contents/README.md --jq '.content' | ForEach-Object {
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
        }
        
        # Also fetch setup guide
        Write-Host "Fetching setup guide..." -ForegroundColor Yellow
        $setupGuideContent = ""
        try {
            $setupContent = gh api repos/$Repo/contents/docs/guides/HP-ZBOOK-SETUP.md --jq '.content' 2>&1
            if ($LASTEXITCODE -eq 0) {
                $setupGuideContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($setupContent))
            }
        } catch {
            Write-Host "[INFO] Setup guide not found, using README only" -ForegroundColor Gray
        }
        
        # Combine content
        $fullContent = @"
# VTT Hardware Benchmark Suite - Setup Instructions

*Fetched from: https://github.com/$Repo*

---

$readmeContent

---

$setupGuideContent
"@
        
        $fullContent | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "[OK] Instructions saved to: $OutputPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now view the instructions:" -ForegroundColor Cyan
        Write-Host "  notepad $OutputPath" -ForegroundColor White
        Write-Host "  or" -ForegroundColor Gray
        Write-Host "  Get-Content $OutputPath | more" -ForegroundColor White
        exit 0
        
    } catch {
        Write-Host "[ERROR] Failed to fetch using GitHub CLI: $_" -ForegroundColor Red
        Write-Host "Falling back to alternative method..." -ForegroundColor Yellow
    }
}

# Method 2: Use GitHub API with token (if available)
$githubToken = $env:GITHUB_TOKEN
if ($githubToken) {
    Write-Host "Fetching using GitHub API token..." -ForegroundColor Yellow
    
    try {
        $headers = @{
            "Authorization" = "token $githubToken"
            "Accept" = "application/vnd.github.v3.raw"
        }
        
        # Fetch README
        $readmeUrl = "https://api.github.com/repos/$Repo/contents/README.md?ref=$Branch"
        $readmeResponse = Invoke-RestMethod -Uri $readmeUrl -Headers $headers -Method Get
        $readmeContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($readmeResponse.content))
        
        # Fetch setup guide
        $setupGuideContent = ""
        try {
            $setupUrl = "https://api.github.com/repos/$Repo/contents/docs/guides/HP-ZBOOK-SETUP.md?ref=$Branch"
            $setupResponse = Invoke-RestMethod -Uri $setupUrl -Headers $headers -Method Get
            $setupGuideContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($setupResponse.content))
        } catch {
            Write-Host "[INFO] Setup guide not found, using README only" -ForegroundColor Gray
        }
        
        # Combine content
        $fullContent = @"
# VTT Hardware Benchmark Suite - Setup Instructions

*Fetched from: https://github.com/$Repo*

---

$readmeContent

---

$setupGuideContent
"@
        
        $fullContent | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "[OK] Instructions saved to: $OutputPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now view the instructions:" -ForegroundColor Cyan
        Write-Host "  notepad $OutputPath" -ForegroundColor White
        exit 0
        
    } catch {
        Write-Host "[ERROR] Failed to fetch using API token: $_" -ForegroundColor Red
    }
}

# Method 3: Provide instructions for manual download
Write-Host ""
Write-Host "[INFO] Automatic fetch not available" -ForegroundColor Yellow
Write-Host ""
Write-Host "To get setup instructions, use one of these methods:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Option 1: Install GitHub CLI and authenticate" -ForegroundColor White
Write-Host "  winget install --id GitHub.cli" -ForegroundColor Gray
Write-Host "  gh auth login" -ForegroundColor Gray
Write-Host "  Then run this script again" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Set GITHUB_TOKEN environment variable" -Foreground White
Write-Host "  Create token: https://github.com/settings/tokens" -ForegroundColor Gray
Write-Host "  Set scope: 'repo' (for private repos)" -ForegroundColor Gray
Write-Host "  \$env:GITHUB_TOKEN = 'your_token_here'" -ForegroundColor Gray
Write-Host "  Then run this script again" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 3: View instructions in browser" -ForegroundColor White
Write-Host "  https://github.com/$Repo/blob/$Branch/README.md" -ForegroundColor Gray
Write-Host "  https://github.com/$Repo/blob/$Branch/docs/guides/HP-ZBOOK-SETUP.md" -ForegroundColor Gray
Write-Host ""
exit 1
