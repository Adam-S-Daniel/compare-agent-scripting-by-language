Set-Location $PSScriptRoot
Invoke-Pester './ErrorRetryPipeline.Tests.ps1' -Output Detailed
