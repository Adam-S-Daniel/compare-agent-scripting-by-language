Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path './ArtifactCleanup.Tests.ps1' -Output Detailed
