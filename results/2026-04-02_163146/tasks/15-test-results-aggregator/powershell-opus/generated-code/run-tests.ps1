#!/usr/bin/env pwsh
# Script to run all Pester tests
Set-Location $PSScriptRoot
Invoke-Pester -Path ./TestResultsAggregator.Tests.ps1 -Output Detailed
