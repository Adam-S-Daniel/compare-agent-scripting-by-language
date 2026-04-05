#!/usr/bin/env pwsh
# Helper script to run all Pester tests for the SearchReplace module.
# Usage: pwsh ./run-tests.ps1
Set-Location $PSScriptRoot
$result = Invoke-Pester -Path ./SearchReplace.Tests.ps1 -Output Detailed -PassThru
exit $result.FailedCount
