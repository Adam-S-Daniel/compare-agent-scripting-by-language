#!/usr/bin/env pwsh
# Get-LicenseReport.ps1
# CLI entry point for the LicenseChecker module.
#
# Usage:
#   pwsh -File src/Get-LicenseReport.ps1 -ManifestPath fixtures/package.json \
#        -PolicyPath fixtures/license-policy.json -OutputFormat text -JsonPath out.json
#
# Exit codes:
#   0 - all dependencies compliant (no Denied or Unknown)
#   1 - at least one Denied or Unknown dependency
#   2 - input/parse error

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$PolicyPath,
    [ValidateSet('text', 'json')][string]$OutputFormat = 'text',
    [string]$JsonPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'LicenseChecker.psm1') -Force

try {
    $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -PolicyPath $PolicyPath
} catch {
    Write-Error $_.Exception.Message
    exit 2
}

# Always emit the human-readable report to stdout for CI logs.
Format-ComplianceReport -Report $report | Write-Output

# Optionally emit machine-readable JSON to a file for downstream tooling.
if ($OutputFormat -eq 'json' -or $JsonPath) {
    $jsonOut = $report | ConvertTo-Json -Depth 10
    if ($JsonPath) {
        Set-Content -Path $JsonPath -Value $jsonOut -Encoding utf8
        Write-Output ""
        Write-Output "JSON report written to: $JsonPath"
    } else {
        Write-Output ""
        Write-Output "--- JSON ---"
        Write-Output $jsonOut
    }
}

if ($report.Compliant) { exit 0 } else { exit 1 }
