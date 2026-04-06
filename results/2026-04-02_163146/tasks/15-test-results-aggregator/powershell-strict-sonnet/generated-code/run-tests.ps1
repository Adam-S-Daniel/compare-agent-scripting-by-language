Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path (Join-Path $PSScriptRoot 'TestResultsAggregator.Tests.ps1') -Output Detailed
