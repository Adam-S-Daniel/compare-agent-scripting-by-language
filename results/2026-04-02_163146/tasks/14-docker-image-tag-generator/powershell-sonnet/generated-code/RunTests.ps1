# RunTests.ps1 — installs Pester (if needed) and runs the test suite
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0' })) {
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}
Import-Module Pester -MinimumVersion 5.0
$config = New-PesterConfiguration
$config.Run.Path = Join-Path $PSScriptRoot 'DockerTagGenerator.Tests.ps1'
$config.Output.Verbosity = 'Detailed'
$config.Run.Exit = $true
Invoke-Pester -Configuration $config
