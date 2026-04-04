#!/usr/bin/env pwsh
# Run all Pester tests with detailed output
Set-Location $PSScriptRoot
$result = Invoke-Pester -Path "./ConfigMigrator.Tests.ps1" -Output Detailed -PassThru
exit $result.FailedCount
