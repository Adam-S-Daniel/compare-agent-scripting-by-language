#!/bin/bash
# run-tests.sh — wrapper to run Pester tests via PowerShell
exec pwsh -NoProfile -NonInteractive -File "$(dirname "$0")/RunTests.ps1"
