@echo off
REM VTT Hardware Benchmark Setup - Consolidated Version
REM Right-click -> Run as Administrator

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ERROR: This script must be run as Administrator
    echo.
    echo Right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

REM Run the PowerShell setup script with execution policy bypass
powershell.exe -ExecutionPolicy Bypass -File "%~dp0HP-ZBOOK-SETUP-INTERACTIVE.ps1"

pause
