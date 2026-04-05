#!/bin/bash
cd "$(dirname "$0")"
/snap/bin/pwsh -c 'Invoke-Pester "./SemanticVersionBumper.Tests.ps1" -Output Detailed'
