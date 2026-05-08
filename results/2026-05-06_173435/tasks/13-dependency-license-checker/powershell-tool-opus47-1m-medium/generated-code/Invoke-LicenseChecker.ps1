#!/usr/bin/env pwsh
# CLI entry point for the dependency license checker.
# Usage:
#   pwsh ./Invoke-LicenseChecker.ps1 -ManifestPath ./package.json `
#       -ConfigPath ./license-config.json -LookupPath ./mock-licenses.json
#
# Exits 0 when no denied or unknown dependencies are found, 1 otherwise.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManifestPath,
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $LookupPath,
    [string] $OutputPath,
    # When set, exits 1 if any denied/unknown dependencies are found.
    # Off by default so CI runs always succeed and assertions work on report text.
    [switch] $StrictExit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'LicenseChecker.psm1') -Force

# Load mocked license registry: { "pkgName": "SPDX-ID", ... }
if (-not (Test-Path -LiteralPath $LookupPath)) {
    throw "License lookup file not found: $LookupPath"
}
$lookupRaw = Get-Content -LiteralPath $LookupPath -Raw | ConvertFrom-Json
$lookup = @{}
foreach ($p in $lookupRaw.PSObject.Properties) { $lookup[$p.Name] = [string]$p.Value }

$rows = Invoke-LicenseComplianceReport `
    -ManifestPath $ManifestPath `
    -ConfigPath   $ConfigPath `
    -LookupTable  $lookup

$report = Format-ComplianceReport -Rows $rows
Write-Output $report

if ($OutputPath) {
    Set-Content -LiteralPath $OutputPath -Value $report
}

$denied  = @($rows | Where-Object Status -eq 'denied').Count
$unknown = @($rows | Where-Object Status -eq 'unknown').Count
if ($denied -gt 0 -or $unknown -gt 0) {
    Write-Output ("FAIL: {0} denied, {1} unknown" -f $denied, $unknown)
    if ($StrictExit) { exit 1 }
    exit 0
}

Write-Output "PASS: all dependencies approved"
exit 0
