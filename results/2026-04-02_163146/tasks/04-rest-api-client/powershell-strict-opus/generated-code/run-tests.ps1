#!/usr/bin/env pwsh
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Run all Pester tests with detailed output
Invoke-Pester -Path "$PSScriptRoot/RestApiClient.Tests.ps1" -Output Detailed
