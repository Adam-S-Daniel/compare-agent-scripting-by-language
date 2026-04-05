#!/bin/bash
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -Command 'Invoke-Pester -Path ./SearchReplace.Tests.ps1 -Output Detailed'
