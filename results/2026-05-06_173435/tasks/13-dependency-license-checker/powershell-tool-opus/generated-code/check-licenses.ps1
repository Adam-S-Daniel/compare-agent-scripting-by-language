param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/DependencyLicenseChecker.psm1" -Force

$report = Invoke-LicenseCheck -ManifestPath $ManifestPath -ConfigPath $ConfigPath

$denied = @($report | Where-Object { $_.Status -eq 'denied' })
if ($denied.Count -gt 0) {
    exit 1
}
exit 0
