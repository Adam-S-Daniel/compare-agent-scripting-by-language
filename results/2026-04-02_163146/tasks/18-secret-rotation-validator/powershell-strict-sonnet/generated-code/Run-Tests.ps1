# Run-Tests.ps1
# Installs Pester 5.x if needed, then runs the test suite with detailed output.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# --- Ensure Pester 5.x is available ---
[bool]$pesterAvailable = [bool](Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge [version]'5.0.0' })

if (-not $pesterAvailable) {
    Write-Host 'Pester 5.x not found — installing...' -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion '5.0.0' -Force -Scope CurrentUser -SkipPublisherCheck
    Write-Host 'Pester installed.' -ForegroundColor Green
}

Import-Module Pester -MinimumVersion '5.0.0' -Force

# --- Configure and run Pester ---
[string]$testFile = Join-Path $PSScriptRoot 'SecretRotationValidator.Tests.ps1'

$config = New-PesterConfiguration
$config.Run.Path          = $testFile
$config.Output.Verbosity  = 'Detailed'
$config.Run.PassThru      = $true

[Pester.RunResult]$result = Invoke-Pester -Configuration $config

# Exit with non-zero code if any tests failed (useful in CI)
if ($result.FailedCount -gt 0) {
    Write-Error "Pester: $($result.FailedCount) test(s) failed."
    exit 1
}
