#!/bin/bash
# run-tests.sh — convenience wrapper to run the Pester test suite
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure Pester 5+ is installed
pwsh -NoProfile -Command "
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { \$_.Version -ge '5.0.0' })) {
    Write-Host 'Installing Pester 5...'
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
}
"

# Run the tests
pwsh -NoProfile -Command "
Set-Location '$SCRIPT_DIR'
\$config = New-PesterConfiguration
\$config.Run.Path = './ProcessMonitor.Tests.ps1'
\$config.Output.Verbosity = 'Detailed'
\$result = Invoke-Pester -Configuration \$config -PassThru
if (\$result.FailedCount -gt 0) { exit 1 }
"
