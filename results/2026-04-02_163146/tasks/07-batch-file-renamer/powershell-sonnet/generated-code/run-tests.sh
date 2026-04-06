#!/usr/bin/env bash
# Run Pester tests for the Batch File Renamer
set -e
cd "$(dirname "$0")"

PWSH=$(which pwsh 2>/dev/null || which powershell 2>/dev/null)
if [ -z "$PWSH" ]; then
  echo "ERROR: PowerShell not found. Install pwsh first."
  exit 1
fi

echo "Using PowerShell at: $PWSH"
$PWSH --version

$PWSH -NoProfile -NonInteractive -Command "
  # Install Pester if not already installed
  if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { \$_.Version -ge '5.0' })) {
    Write-Host 'Installing Pester 5.x...'
    Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion 5.0
  }
  \$config = New-PesterConfiguration
  \$config.Run.Path = '.'
  \$config.Output.Verbosity = 'Detailed'
  \$result = Invoke-Pester -Configuration \$config
  if (\$result.FailedCount -gt 0) {
    Write-Error \"Tests failed: \$(\$result.FailedCount) failures\"
    exit 1
  }
  exit 0
"
