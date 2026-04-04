#!/usr/bin/env pwsh
# Helper script to run all Pester tests
Invoke-Pester -Path "$PSScriptRoot/RestApiClient.Tests.ps1" -Output Detailed
