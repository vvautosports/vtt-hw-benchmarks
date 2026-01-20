# HP ZBook System Information Gathering Script
# Run this on the HP ZBook to collect system specs for benchmark documentation
# Usage: .\hp-zbook-sysinfo.ps1

Write-Host "=== HP ZBook System Information ===" -ForegroundColor Cyan
Write-Host ""

# Computer model
Write-Host "Computer Model:" -ForegroundColor Yellow
Get-WmiObject -Class Win32_ComputerSystem | Select-Object Manufacturer, Model

# CPU Information
Write-Host "`nCPU Information:" -ForegroundColor Yellow
Get-WmiObject -Class Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed

# GPU Information
Write-Host "`nGPU Information:" -ForegroundColor Yellow
Get-WmiObject -Class Win32_VideoController | Select-Object Name, DriverVersion, VideoMemoryType

# RAM Information
Write-Host "`nRAM Information:" -ForegroundColor Yellow
$totalRAM = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB
Write-Host "Total RAM: $([math]::Round($totalRAM, 2)) GB"

Get-WmiObject -Class Win32_PhysicalMemory | Select-Object Manufacturer, Capacity, Speed | ForEach-Object {
    $capacityGB = $_.Capacity / 1GB
    Write-Host "  - $([math]::Round($capacityGB, 2)) GB @ $($_.Speed) MHz ($($_.Manufacturer))"
}

# Storage Information
Write-Host "`nStorage Information:" -ForegroundColor Yellow
Get-PhysicalDisk | Select-Object FriendlyName, MediaType, Size | ForEach-Object {
    $sizeGB = $_.Size / 1GB
    Write-Host "  - $($_.FriendlyName): $([math]::Round($sizeGB, 2)) GB ($($_.MediaType))"
}

# OS Information
Write-Host "`nOperating System:" -ForegroundColor Yellow
Get-WmiObject -Class Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture, BuildNumber

# BIOS Information
Write-Host "`nBIOS Information:" -ForegroundColor Yellow
Get-WmiObject -Class Win32_BIOS | Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate

# Network Information
Write-Host "`nNetwork Interfaces:" -ForegroundColor Yellow
Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed

# Current Power Plan
Write-Host "`nPower Plan:" -ForegroundColor Yellow
$powerPlan = Get-WmiObject -Namespace root\cimv2\power -Class Win32_PowerPlan | Where-Object IsActive -eq $true
Write-Host "  Active: $($powerPlan.ElementName)"

# Battery Status (if laptop)
Write-Host "`nBattery Status:" -ForegroundColor Yellow
$battery = Get-WmiObject -Class Win32_Battery
if ($battery) {
    Write-Host "  Charge: $($battery.EstimatedChargeRemaining)%"
    Write-Host "  Status: $($battery.BatteryStatus)"
    if ($battery.BatteryStatus -eq 2) {
        Write-Host "  [PLUGGED IN - Good for benchmarking]" -ForegroundColor Green
    } else {
        Write-Host "  [NOT PLUGGED IN - Please plug in for consistent results]" -ForegroundColor Red
    }
} else {
    Write-Host "  No battery detected (Desktop system)"
}

# Temperature (requires additional tools - optional)
Write-Host "`nNote: For temperature monitoring during benchmarks, consider:" -ForegroundColor Gray
Write-Host "  - HWiNFO64 (recommended)" -ForegroundColor Gray
Write-Host "  - Open Hardware Monitor" -ForegroundColor Gray
Write-Host "  - Ryzen Master (for AMD CPUs)" -ForegroundColor Gray

Write-Host "`n=== System Information Collection Complete ===" -ForegroundColor Cyan
Write-Host "Copy this output to your benchmark results file." -ForegroundColor Cyan
Write-Host ""

# Optional: Export to file
$exportChoice = Read-Host "Export to file? (y/n)"
if ($exportChoice -eq 'y') {
    $computerName = $env:COMPUTERNAME
    $date = Get-Date -Format "yyyyMMdd"
    $filename = "sysinfo-$computerName-$date.txt"

    $this = $MyInvocation.MyCommand.Definition
    & $this | Out-File -FilePath $filename

    Write-Host "Exported to: $filename" -ForegroundColor Green
}
