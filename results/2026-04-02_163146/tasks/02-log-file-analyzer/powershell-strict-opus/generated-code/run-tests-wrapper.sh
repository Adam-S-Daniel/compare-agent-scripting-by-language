#!/bin/bash
# Wrapper to run Pester tests
cd "$(dirname "$0")"
exec /snap/bin/pwsh -NoProfile -NonInteractive -File run-tests.ps1
