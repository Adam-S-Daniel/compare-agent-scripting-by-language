Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path './PrLabelAssigner.Tests.ps1' -Output Detailed
