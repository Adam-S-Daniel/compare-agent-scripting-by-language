Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'
Invoke-Pester -Path ./DockerTagGenerator.Tests.ps1 -Output Detailed
