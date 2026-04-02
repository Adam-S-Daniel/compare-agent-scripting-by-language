#!/bin/bash
set -e

# Install PowerShell if not available
if ! command -v pwsh &>/dev/null; then
    echo "Installing PowerShell..."
    apt-get update -qq
    apt-get install -y -qq powershell
fi

echo "PowerShell version:"
pwsh --version

echo "Installing Pester..."
pwsh -NoProfile -NonInteractive -Command 'Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck'

echo "Running tests..."
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -Command 'Invoke-Pester -Path ./tests -Output Detailed'
