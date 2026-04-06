# Run-Tests.ps1
# Ensures Pester 5 is available, then runs the ProcessMonitor test suite.
# Usage: pwsh -File Run-Tests.ps1

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ── Ensure Pester 5.x is available ────────────────────────────────────────────
$pesterModule = Get-Module -ListAvailable -Name 'Pester' |
    Where-Object { $_.Version.Major -ge 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -eq $pesterModule) {
    Write-Host 'Pester 5 not found — installing from PSGallery...' -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck
    Write-Host 'Pester installed.' -ForegroundColor Green
}
else {
    Write-Host "Pester $($pesterModule.Version) found." -ForegroundColor Green
}

Import-Module Pester -MinimumVersion 5.0.0 -Force

# ── Run tests ─────────────────────────────────────────────────────────────────
[string]$testFile = Join-Path $PSScriptRoot 'ProcessMonitor.Tests.ps1'

$config = New-PesterConfiguration
$config.Run.Path          = $testFile
$config.Output.Verbosity  = 'Detailed'
$config.Run.Exit          = $true   # non-zero exit code on failure

Invoke-Pester -Configuration $config
