#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Log File Analyzer — parses mixed-format log files and reports errors/warnings.

.DESCRIPTION
    Reads a log file containing syslog-style and JSON-structured lines,
    extracts ERROR and WARNING entries, builds a frequency table with
    first/last occurrence timestamps, and outputs the results as a
    human-readable table (to stdout) and a JSON file.

.PARAMETER Path
    Path to the log file to analyze.

.PARAMETER JsonOutputPath
    Path where the JSON analysis output will be written.
    Defaults to 'analysis-output.json' in the current directory.

.EXAMPLE
    ./Analyze-Log.ps1 -Path ./fixtures/sample.log
    ./Analyze-Log.ps1 -Path ./fixtures/sample.log -JsonOutputPath ./results.json
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter()]
    [string]$JsonOutputPath = (Join-Path $PSScriptRoot 'analysis-output.json')
)

# Import the LogAnalyzer module
[string]$modulePath = Join-Path $PSScriptRoot 'LogAnalyzer.psm1'
Import-Module $modulePath -Force

try {
    [string]$result = Invoke-LogAnalysis -Path $Path -JsonOutputPath $JsonOutputPath
    Write-Output $result
    Write-Output "JSON output written to: $JsonOutputPath"
}
catch {
    Write-Error "Log analysis failed: $_"
    exit 1
}
