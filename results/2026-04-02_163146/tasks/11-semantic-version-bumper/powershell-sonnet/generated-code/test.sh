#!/usr/bin/env bash
# Run Pester tests for VersionBumper
cd "$(dirname "$0")"
pwsh -Command "
  # Install Pester if not present
  if (-not (Get-Module Pester -ListAvailable)) {
    Install-Module -Name Pester -Force -Scope CurrentUser
  }
  Invoke-Pester ./VersionBumper.Tests.ps1 -Output Detailed
"
