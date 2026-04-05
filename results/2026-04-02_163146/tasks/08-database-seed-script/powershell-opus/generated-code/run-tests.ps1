# Run all Pester tests
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/DatabaseSeed.Tests.ps1"
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
