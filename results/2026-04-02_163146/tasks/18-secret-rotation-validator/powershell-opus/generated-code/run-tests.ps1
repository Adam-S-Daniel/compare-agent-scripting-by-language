# run-tests.ps1
# Convenience script to run all Pester tests for the Secret Rotation Validator.
# Usage: pwsh ./run-tests.ps1

Set-Location $PSScriptRoot
$result = Invoke-Pester -Path ./SecretRotationValidator.Tests.ps1 -Output Detailed -PassThru
Write-Host "`nTests: $($result.TotalCount) | Passed: $($result.PassedCount) | Failed: $($result.FailedCount)"
exit $result.FailedCount
