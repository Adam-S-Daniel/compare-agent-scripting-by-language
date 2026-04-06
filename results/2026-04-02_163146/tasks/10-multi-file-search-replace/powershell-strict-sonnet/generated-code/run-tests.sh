#!/usr/bin/env bash
# run-tests.sh
# Install Pester if needed, then run all Pester tests.
# Usage: bash run-tests.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== PowerShell Multi-File Search & Replace - Test Runner ==="
echo "Working directory: $SCRIPT_DIR"
echo ""

pwsh -NoProfile -NonInteractive -Command "
Set-StrictMode -Latest
\$ErrorActionPreference = 'Stop'

# Install Pester 5 if not already installed
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { \$_.Version -ge '5.0' })) {
    Write-Host 'Installing Pester 5...' -ForegroundColor Yellow
    Install-Module -Name Pester -Force -Scope CurrentUser -MinimumVersion 5.0.0
    Write-Host 'Pester installed.' -ForegroundColor Green
} else {
    Write-Host 'Pester 5 already available.' -ForegroundColor Green
}

Import-Module Pester -MinimumVersion 5.0 -Force

# Configure and run tests
\$config = New-PesterConfiguration
\$config.Run.Path = '$SCRIPT_DIR/SearchReplace.Tests.ps1'
\$config.Output.Verbosity = 'Detailed'
\$config.Run.Exit = \$true

Write-Host 'Running tests...' -ForegroundColor Cyan
Invoke-Pester -Configuration \$config
"
