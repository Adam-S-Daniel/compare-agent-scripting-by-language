#!/usr/bin/env python3
"""Helper to run PowerShell Pester tests."""
import subprocess
import os
import sys

script_dir = os.path.dirname(os.path.abspath(__file__))
run_script = os.path.join(script_dir, "Run-Tests.ps1")

result = subprocess.run(
    ["pwsh", "-NoProfile", "-NonInteractive", "-File", run_script],
    capture_output=False,
    text=True,
    cwd=script_dir
)
sys.exit(result.returncode)
