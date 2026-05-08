# Invoke-LicenseCheck.ps1
#
# Thin entry-point script for CI / CLI use. Imports the module, calls
# Invoke-LicenseCheck, and propagates the exit code.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$DatabasePath,
    [Parameter(Mandatory)][string]$ReportPath
)

$ErrorActionPreference = 'Stop'

$here       = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $here 'DependencyLicenseChecker.psm1'
Import-Module $modulePath -Force

$exit = Invoke-LicenseCheck `
    -ManifestPath $ManifestPath `
    -ConfigPath   $ConfigPath   `
    -DatabasePath $DatabasePath `
    -ReportPath   $ReportPath

exit $exit
