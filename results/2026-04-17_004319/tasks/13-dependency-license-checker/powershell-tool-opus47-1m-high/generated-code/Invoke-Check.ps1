# CLI wrapper for the DependencyLicenseChecker module.
# Separating the script from the module lets Pester import the module
# directly (no CLI side effects at import time).

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManifestPath,
    [Parameter(Mandatory)] [string] $PolicyPath,
    [Parameter(Mandatory)] [string] $LicenseDatabasePath,
    [Parameter()]          [string] $OutputPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'src' 'DependencyLicenseChecker.psm1') -Force

try {
    $exit = Invoke-DependencyLicenseCheck `
        -ManifestPath $ManifestPath `
        -PolicyPath $PolicyPath `
        -LicenseDatabasePath $LicenseDatabasePath `
        -OutputPath $OutputPath
    exit $exit
} catch {
    Write-Error $_
    exit 2
}
