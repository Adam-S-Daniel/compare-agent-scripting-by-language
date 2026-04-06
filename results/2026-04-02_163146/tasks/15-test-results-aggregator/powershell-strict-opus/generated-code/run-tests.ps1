Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot
Invoke-Pester -Path './TestResultsAggregator.Tests.ps1' -Output Detailed
