#!/bin/bash
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -c 'Invoke-Pester -Path "./BatchFileRenamer.Tests.ps1" -Output Detailed' 2>&1
