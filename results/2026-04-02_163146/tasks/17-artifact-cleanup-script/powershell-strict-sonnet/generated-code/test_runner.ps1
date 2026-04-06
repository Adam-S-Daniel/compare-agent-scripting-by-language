Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Run all Pester tests and display results
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/ArtifactCleanup.Tests.ps1"
$config.Output.Verbosity = 'Detailed'

Invoke-Pester -Configuration $config
