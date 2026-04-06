# run-tests.ps1
# Runs all Pester tests for the Environment Matrix Generator
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/MatrixGenerator.Tests.ps1"
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = "$PSScriptRoot/test-results.xml"
Invoke-Pester -Configuration $config
