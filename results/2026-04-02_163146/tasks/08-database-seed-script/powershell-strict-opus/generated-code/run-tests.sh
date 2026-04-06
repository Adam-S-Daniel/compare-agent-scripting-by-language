#!/bin/bash
# run-tests.sh - Shell wrapper to run Pester tests via PowerShell.
set -e
cd "$(dirname "$0")"

PWSH=$(which pwsh 2>/dev/null || which powershell 2>/dev/null)
if [ -z "$PWSH" ]; then
    echo "ERROR: PowerShell (pwsh) not found. Please install it first."
    exit 1
fi

echo "Using PowerShell: $PWSH"
$PWSH --version

$PWSH -NoProfile -NonInteractive -File ./run-tests.ps1
