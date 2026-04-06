# run_tests.ps1 - Helper to install Pester (if needed) and run the test suite

$ErrorActionPreference = 'Stop'

# Install Pester 5+ if not available
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
    Write-Host "Installing Pester 5.x..."
    Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion '5.0'
}

Import-Module Pester -MinimumVersion '5.0'

$testPath = Join-Path $PSScriptRoot "MatrixGenerator.Tests.ps1"
$result = Invoke-Pester -Path $testPath -Output Detailed -PassThru

if ($result.FailedCount -gt 0) {
    exit 1
}
