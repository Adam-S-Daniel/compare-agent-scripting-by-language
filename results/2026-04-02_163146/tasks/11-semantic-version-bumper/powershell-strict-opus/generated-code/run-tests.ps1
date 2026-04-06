Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Run all Pester tests
Invoke-Pester -Path $PSScriptRoot -Output Detailed
