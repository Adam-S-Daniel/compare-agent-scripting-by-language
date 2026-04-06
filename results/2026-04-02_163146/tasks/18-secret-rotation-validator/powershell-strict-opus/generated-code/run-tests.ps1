Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path './SecretRotationValidator.Tests.ps1' -Output Detailed
