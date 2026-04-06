#!/bin/bash
# Run Pester tests for the SearchReplace module
cd "$(dirname "$0")"
pwsh -NoProfile -NonInteractive -Command "
    # Install Pester if not available
    if (-not (Get-Module -Name Pester -ListAvailable | Where-Object Version -ge '5.0')) {
        Write-Host 'Installing Pester...'
        Install-Module -Name Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck
    }
    Import-Module Pester
    Invoke-Pester -Path './SearchReplace.Tests.ps1' -Output Detailed
"
