#!/usr/bin/env pwsh
# Check-Licenses.ps1
#
# Thin entry point that wires the LicenseChecker module to a CLI.
#
# Usage:
#   pwsh ./Check-Licenses.ps1 \
#       -ManifestPath    fixtures/package.basic.json \
#       -ConfigPath      fixtures/license-config.json \
#       -LicenseDataPath fixtures/license-data.allgood.json \
#       -OutputPath      report.txt
#
# Exit codes:
#   0  - report generated and no denied dependencies
#   1  - report generated but at least one denied dependency
#   2  - script failed (config missing, manifest unparseable, etc.)
#
# License lookup is mocked via -LicenseDataPath so this runs in any
# air-gapped environment (including the act container). A real-world
# version would replace -LicenseDataPath with calls to npmjs / pypi.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManifestPath,
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter()]          [string] $LicenseDataPath,
    [Parameter()]          [string] $OutputPath,
    [Parameter()]          [switch] $FailOnUnknown
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

try {
    Import-Module (Join-Path $PSScriptRoot 'src/LicenseChecker.psm1') -Force

    $report = Invoke-LicenseCheck `
        -ManifestPath    $ManifestPath `
        -ConfigPath      $ConfigPath `
        -LicenseDataPath $LicenseDataPath

    Write-Output $report.Text

    if ($OutputPath) {
        $report.Text | Set-Content -LiteralPath $OutputPath -Encoding utf8
        Write-Output ""
        Write-Output "Report written to: $OutputPath"
    }

    $exit = 0
    if ($report.Denied -gt 0) { $exit = 1 }
    elseif ($FailOnUnknown -and $report.Unknown -gt 0) { $exit = 1 }
    exit $exit
}
catch {
    Write-Error "License check failed: $($_.Exception.Message)"
    exit 2
}
