Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path "./ConfigMigrator.Tests.ps1" -Output Detailed
