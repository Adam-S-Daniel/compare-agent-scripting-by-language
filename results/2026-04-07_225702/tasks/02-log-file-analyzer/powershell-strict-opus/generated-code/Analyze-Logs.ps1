#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Main entry point — analyzes a log file and outputs results.
.DESCRIPTION
    Parses a mixed-format log file (syslog + JSON), extracts errors and
    warnings, builds a frequency table, prints a human-readable table to
    stdout, and writes a JSON report to disk.
.PARAMETER LogPath
    Path to the log file to analyze. Defaults to fixtures/sample.log.
.PARAMETER JsonOutputPath
    Path for the JSON output. Defaults to analysis-output.json.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LogPath = (Join-Path $PSScriptRoot 'fixtures' 'sample.log'),

    [Parameter()]
    [string]$JsonOutputPath = (Join-Path $PSScriptRoot 'analysis-output.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the analyzer functions
. (Join-Path $PSScriptRoot 'LogAnalyzer.ps1')

try {
    Write-Host "Analyzing log file: $LogPath" -ForegroundColor Cyan
    Write-Host ''

    [string]$table = Invoke-LogAnalysis -LogPath $LogPath -JsonOutputPath $JsonOutputPath

    Write-Host $table
    Write-Host ''
    Write-Host "JSON report written to: $JsonOutputPath" -ForegroundColor Green
}
catch {
    Write-Error "Log analysis failed: $_"
    exit 1
}
