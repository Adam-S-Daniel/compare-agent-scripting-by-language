#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Run all Pester tests
Invoke-Pester -Path './tests' -Output Detailed
