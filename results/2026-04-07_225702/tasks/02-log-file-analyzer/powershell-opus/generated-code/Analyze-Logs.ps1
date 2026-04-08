#!/usr/bin/env pwsh
# Analyze-Logs.ps1 - CLI entry point for the log file analyzer.
# Usage: pwsh Analyze-Logs.ps1 [-LogPath <path>] [-JsonOutputPath <path>]

param(
    [string]$LogPath = (Join-Path $PSScriptRoot "fixtures/sample.log"),
    [string]$JsonOutputPath = (Join-Path $PSScriptRoot "analysis-output.json")
)

# Import the library functions
. "$PSScriptRoot/LogAnalyzer.ps1"

try {
    Write-Host "Analyzing log file: $LogPath" -ForegroundColor Cyan
    Write-Host ""

    $result = Invoke-LogAnalysis -Path $LogPath -JsonOutputPath $JsonOutputPath

    Write-Host $result
    Write-Host ""
    Write-Host "JSON report written to: $JsonOutputPath" -ForegroundColor Green
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
