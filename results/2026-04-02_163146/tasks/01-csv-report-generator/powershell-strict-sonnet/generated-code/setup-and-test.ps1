# setup-and-test.ps1
# Installs Pester (if needed) and runs all tests.
# Usage: pwsh -File setup-and-test.ps1

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Ensure Pester 5.x is available
$pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester -or $pester.Version.Major -lt 5) {
    Write-Host "Installing Pester 5.x..."
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck -MinimumVersion 5.0.0
}

Import-Module Pester -MinimumVersion 5.0.0 -Force

Write-Host "`nRunning Pester tests..."
Set-Location $PSScriptRoot

$config = New-PesterConfiguration
$config.Run.Path = './EmployeeReport.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = './test-results.xml'
$config.TestResult.OutputFormat = 'JUnitXml'

$result = Invoke-Pester -Configuration $config

Write-Host "`nTest run complete: $($result.PassedCount) passed, $($result.FailedCount) failed."

if ($result.FailedCount -gt 0) {
    exit 1
}
exit 0
