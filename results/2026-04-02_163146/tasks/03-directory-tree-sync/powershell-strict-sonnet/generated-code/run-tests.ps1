Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path "$PSScriptRoot/DirectorySync.Tests.ps1" -Output Detailed
