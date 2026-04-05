# Run-Tests.ps1
# Ensures Pester is available, then runs all tests.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Ensure Pester >= 5 is installed
# ---------------------------------------------------------------------------
[version]$minPesterVersion = '5.0.0'
$pester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge $minPesterVersion } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -eq $pester) {
    Write-Host 'Pester >= 5 not found. Installing from PSGallery...'
    Install-Module -Name Pester -MinimumVersion '5.0.0' -Force -Scope CurrentUser -SkipPublisherCheck
    Write-Host 'Pester installed.'
}
else {
    Write-Host "Using Pester $($pester.Version)"
}

# ---------------------------------------------------------------------------
# Run the tests
# ---------------------------------------------------------------------------
[string]$testFile = Join-Path $PSScriptRoot 'VersionBumper.Tests.ps1'

$config = New-PesterConfiguration
$config.Run.Path          = $testFile
$config.Output.Verbosity  = 'Detailed'
$config.TestResult.Enabled = $true

$result = Invoke-Pester -Configuration $config

# Exit with a non-zero code if any tests failed (important for CI)
if ($result.FailedCount -gt 0) {
    Write-Error "Tests FAILED: $($result.FailedCount) failure(s)."
    exit 1
}

Write-Host "All $($result.PassedCount) tests passed."
