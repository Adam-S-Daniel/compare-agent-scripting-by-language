#!/usr/bin/env pwsh
# CLI wrapper that imports the module and runs the compliance check.
# Exit code: 0 when no denied licenses, 1 otherwise.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$MockLicenseFile,
    [string]$OutputPath,
    [switch]$FailOnUnknown
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'LicenseChecker.psm1') -Force

try {
    $report = Invoke-LicenseCheck `
        -ManifestPath $ManifestPath `
        -ConfigPath $ConfigPath `
        -MockLicenseFile $MockLicenseFile `
        -OutputPath $OutputPath

    if (-not $report.OverallCompliant) { exit 1 }
    if ($FailOnUnknown -and $report.Summary.unknown -gt 0) { exit 1 }
    exit 0
} catch {
    Write-Error $_
    exit 2
}
