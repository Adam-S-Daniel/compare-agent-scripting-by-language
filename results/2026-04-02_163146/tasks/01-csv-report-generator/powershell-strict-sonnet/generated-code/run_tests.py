#!/usr/bin/env python3
"""Helper script to run Pester tests via subprocess."""
import subprocess
import sys
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Build the PowerShell command
ps_cmd = (
    "if (-not (Get-Module -ListAvailable Pester)) {"
    "  Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck"
    "};"
    "Invoke-Pester -Path './EmployeeReport.Tests.ps1' -Output Detailed;"
    "exit $LASTEXITCODE"
)

result = subprocess.run(
    ["pwsh", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
    text=True
)
sys.exit(result.returncode)
