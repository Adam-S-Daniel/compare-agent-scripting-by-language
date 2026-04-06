#!/usr/bin/env pwsh
# Run all Pester tests for the Dependency License Checker
Set-Location $PSScriptRoot
Invoke-Pester -Output Detailed
