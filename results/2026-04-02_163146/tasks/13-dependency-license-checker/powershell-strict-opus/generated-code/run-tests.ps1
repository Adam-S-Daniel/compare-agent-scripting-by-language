#!/usr/bin/env pwsh
# Runner script to invoke Pester tests
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Invoke-Pester -Path "$PSScriptRoot/DependencyLicenseChecker.Tests.ps1" -Output Detailed
