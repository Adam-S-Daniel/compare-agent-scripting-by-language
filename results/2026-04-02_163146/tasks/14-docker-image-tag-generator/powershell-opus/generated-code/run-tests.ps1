#!/usr/bin/env pwsh
# Test runner — invoke with: pwsh -NoProfile -File run-tests.ps1
Invoke-Pester -Path $PSScriptRoot/Get-DockerImageTags.Tests.ps1 -Output Detailed
