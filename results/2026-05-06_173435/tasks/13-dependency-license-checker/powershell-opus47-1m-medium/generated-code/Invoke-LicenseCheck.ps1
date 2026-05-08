#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Entry point: read a manifest + policy, run the compliance check, write a
    JSON report, print a one-line summary, and exit with a status reflecting
    findings (0 = clean, 1 = had unknowns, 2 = had denied dependencies).

.PARAMETER ManifestPath
    Path to package.json or requirements.txt.

.PARAMETER ConfigPath
    Path to a JSON file with shape: { "allow": [...], "deny": [...] }.

.PARAMETER MockDatabase
    Path to a JSON file mapping dependency names to license strings. Used as
    the "license lookup" data source. Mocked here for testability since real
    license discovery would require network calls / SBOM tools that are out
    of scope for this task.

.PARAMETER ReportPath
    Where to write the JSON compliance report.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManifestPath,
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $MockDatabase,
    [Parameter(Mandatory)] [string] $ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Import-Module (Join-Path $PSScriptRoot 'LicenseChecker.psm1') -Force

    if (-not (Test-Path -LiteralPath $ConfigPath))   { throw "Policy config not found: $ConfigPath" }
    if (-not (Test-Path -LiteralPath $MockDatabase)) { throw "Mock license DB not found: $MockDatabase" }

    $config = Get-Content -LiteralPath $ConfigPath   -Raw | ConvertFrom-Json
    $db     = Get-Content -LiteralPath $MockDatabase -Raw | ConvertFrom-Json

    # Wrap the JSON object as a closure so the module sees a scriptblock.
    $lookup = {
        param($name, $version)
        if ($db.PSObject.Properties.Name -contains $name) { return [string]$db.$name }
        return $null
    }.GetNewClosure()

    $deps   = Get-Dependencies -Path $ManifestPath
    $report = New-ComplianceReport -Dependencies $deps -Config $config -LicenseLookup $lookup

    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding utf8

    $approved = @($report | Where-Object Status -EQ 'approved').Count
    $denied   = @($report | Where-Object Status -EQ 'denied').Count
    $unknown  = @($report | Where-Object Status -EQ 'unknown').Count
    Write-Output "license-check summary: total=$($report.Count) approved=$approved denied=$denied unknown=$unknown"
    Write-Output "report: $ReportPath"

    if ($denied  -gt 0) { exit 2 }
    if ($unknown -gt 0) { exit 1 }
    exit 0
}
catch {
    Write-Error "license-check failed: $($_.Exception.Message)"
    exit 64
}
