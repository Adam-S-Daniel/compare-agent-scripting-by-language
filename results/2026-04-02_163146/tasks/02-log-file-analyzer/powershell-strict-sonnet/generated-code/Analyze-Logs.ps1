# Analyze-Logs.ps1
# Entry-point script for the log file analyzer.
# Usage: pwsh Analyze-Logs.ps1 [-LogPath <path>] [-OutputDir <dir>]
#
# Defaults:
#   LogPath   = fixtures/sample.log
#   OutputDir = . (current directory)

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

param(
    [string]$LogPath   = (Join-Path $PSScriptRoot 'fixtures/sample.log'),
    [string]$OutputDir = $PSScriptRoot
)

# Import the module
$modulePath = Join-Path $PSScriptRoot 'LogAnalyzer.psm1'
Import-Module $modulePath -Force

# Derive output JSON path
[string]$jsonOutput = Join-Path $OutputDir 'analysis.json'

Write-Host "Log Analyzer"
Write-Host "  Input : $LogPath"
Write-Host "  Output: $jsonOutput"
Write-Host ""

# Run the analysis — Invoke-LogAnalysis throws on missing file
[string]$report = Invoke-LogAnalysis -LogPath $LogPath -JsonOutputPath $jsonOutput

# Print human-readable report to console
Write-Host $report

Write-Host ""
Write-Host "JSON output written to: $jsonOutput"
