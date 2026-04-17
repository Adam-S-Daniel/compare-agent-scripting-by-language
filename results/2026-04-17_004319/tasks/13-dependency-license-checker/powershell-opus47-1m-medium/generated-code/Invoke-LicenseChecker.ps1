#!/usr/bin/env pwsh
# Entrypoint for the license-compliance checker.
# Loads a manifest + license config, consults a license database
# (either a local JSON mock or the built-in empty default), and prints a
# human-readable report plus a machine-readable summary line.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$LicenseDbPath,
    [string]$OutputJson,
    [switch]$FailOnDenied
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$moduleDir = Split-Path -Parent $PSCommandPath
Import-Module (Join-Path $moduleDir 'LicenseChecker.psm1') -Force

$config = ConvertTo-LicenseConfig -Path $ConfigPath

# If a license-db fixture is supplied we replace the default lookup with one
# that reads from it. This is the "mocked license lookup" for production runs
# so the script behaves deterministically without external network calls.
if ($LicenseDbPath) {
    if (-not (Test-Path -LiteralPath $LicenseDbPath)) {
        throw "License DB not found: $LicenseDbPath"
    }
    $dbJson = Get-Content -LiteralPath $LicenseDbPath -Raw | ConvertFrom-Json
    $db = @{}
    foreach ($prop in $dbJson.PSObject.Properties) {
        $db[$prop.Name] = [string]$prop.Value
    }
    Set-LicenseDatabase -Database $db
}

$report = New-ComplianceReport -ManifestPath $ManifestPath -Config $config

Write-Host "Dependency License Compliance Report"
Write-Host "Manifest: $($report.Manifest)"
Write-Host ("-" * 60)
foreach ($d in $report.Dependencies) {
    $marker = switch ($d.Status) {
        'approved' { 'OK     ' }
        'denied'   { 'DENIED ' }
        default    { 'UNKNOWN' }
    }
    Write-Host ("{0}  {1,-20} {2,-12} {3,-15} {4}" -f $marker, $d.Name, $d.Version, $d.License, $d.Status)
}
Write-Host ("-" * 60)
Write-Host ("SUMMARY total={0} approved={1} denied={2} unknown={3}" -f `
    $report.Summary.Total, $report.Summary.Approved, $report.Summary.Denied, $report.Summary.Unknown)

if ($OutputJson) {
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputJson
    Write-Host "Wrote JSON report to $OutputJson"
}

if ($FailOnDenied -and $report.Summary.Denied -gt 0) {
    Write-Host "FAIL: denied licenses detected"
    exit 1
}

exit 0
