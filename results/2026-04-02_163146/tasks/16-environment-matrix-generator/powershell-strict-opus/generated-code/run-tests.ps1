Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Run all Pester tests and output detailed results
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/MatrixGenerator.Tests.ps1"
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true
Invoke-Pester -Configuration $config
