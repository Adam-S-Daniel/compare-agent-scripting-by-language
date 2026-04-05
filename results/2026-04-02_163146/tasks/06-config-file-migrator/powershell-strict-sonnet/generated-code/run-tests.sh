#!/usr/bin/env bash
# Run the Pester tests for ConfigMigrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Pester if needed..."
pwsh -NoProfile -NonInteractive -Command "
    if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { \$_.Version -ge '5.0' })) {
        Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
    }
    Write-Host 'Pester is available'
"

echo "Running tests..."
pwsh -NoProfile -NonInteractive -Command "
    Set-Location '$SCRIPT_DIR'
    \$result = Invoke-Pester ./ConfigMigrator.Tests.ps1 -Output Normal -PassThru
    exit \$result.FailedCount
"
