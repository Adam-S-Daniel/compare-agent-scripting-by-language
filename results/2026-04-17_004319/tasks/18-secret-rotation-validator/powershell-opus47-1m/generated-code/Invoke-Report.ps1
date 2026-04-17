#!/usr/bin/env pwsh
# Entry point used by the GitHub Actions workflow.
#
# Reads a JSON secrets config and writes a rotation report to stdout.
# Intended for CI: warnings / expired secrets do NOT exit non-zero, so the
# workflow job still succeeds and the test harness can assert on the output.
#
# Parameters may come from either the command line or environment variables
# (SECRETS_PATH, WARNING_DAYS, OUTPUT_FORMAT, NOW). This lets the same script
# be invoked directly or driven from workflow `env:` blocks.

[CmdletBinding()]
param(
    [string] $Path,
    [int]    $WarningDays,
    [ValidateSet('markdown','json')] [string] $Format,
    [datetime] $Now
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path)        { $Path        = $env:SECRETS_PATH }
if (-not $WarningDays) { $WarningDays = [int]($env:WARNING_DAYS ? $env:WARNING_DAYS : 7) }
if (-not $Format)      { $Format      = if ($env:OUTPUT_FORMAT) { $env:OUTPUT_FORMAT } else { 'markdown' } }
if (-not $PSBoundParameters.ContainsKey('Now')) {
    if ($env:NOW) { $Now = [datetime]$env:NOW } else { $Now = Get-Date }
}
if (-not $Path) { $Path = Join-Path $PSScriptRoot 'fixtures' 'secrets.json' }

$modulePath = Join-Path $PSScriptRoot 'src' 'SecretRotationValidator.psm1'
Import-Module $modulePath -Force

$output = Invoke-SecretRotationValidator -Path $Path -WarningDays $WarningDays `
    -Format $Format -Now $Now

# Plain Write-Output so downstream tools can capture stdout cleanly.
Write-Output $output
