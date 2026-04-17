#!/usr/bin/env pwsh
# Invoke-SecretRotation.ps1
# CLI entry point for the secret rotation validator.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [int] $WarningDays = 14,
    [ValidateSet('markdown','json')] [string] $Format = 'markdown',
    [string] $ReferenceDate,
    [string] $OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SecretRotation.psm1') -Force

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    [Console]::Error.WriteLine("ERROR: Config file not found: $ConfigPath")
    exit 2
}

try {
    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    $config = $raw | ConvertFrom-Json
} catch {
    [Console]::Error.WriteLine("ERROR: Failed to parse config JSON: $($_.Exception.Message)")
    exit 2
}

if (-not ($config.PSObject.Properties.Name -contains 'secrets')) {
    [Console]::Error.WriteLine("ERROR: Config missing 'secrets' array")
    exit 2
}

$refDate = if ($ReferenceDate) {
    [datetime]::Parse($ReferenceDate, [System.Globalization.CultureInfo]::InvariantCulture)
} else {
    (Get-Date).Date
}

try {
    $report = Get-SecretRotationReport -Secrets $config.secrets -ReferenceDate $refDate -WarningDays $WarningDays
} catch {
    [Console]::Error.WriteLine("ERROR: Failed to build report: $($_.Exception.Message)")
    exit 2
}

$rendered = Format-SecretRotationReport -Report $report -Format $Format

if ($OutputPath) {
    $rendered | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
Write-Output $rendered

# Single-line summary that CI / test harness can grep.
Write-Output "SUMMARY: EXPIRED=$($report.Counts.Expired) WARNING=$($report.Counts.Warning) OK=$($report.Counts.Ok) TOTAL=$($report.Counts.Total)"

# Exit code: 1 if any expired, 0 otherwise (warnings are not failures).
if ($report.Counts.Expired -gt 0) { exit 1 } else { exit 0 }
