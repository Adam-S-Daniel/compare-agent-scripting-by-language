Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
Invoke-Pester -Path './tests' -Output Detailed
