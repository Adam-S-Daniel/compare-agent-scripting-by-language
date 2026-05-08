#requires -Version 7.0
<#
.SYNOPSIS
Script entrypoint for the secret rotation validator.

.DESCRIPTION
Reads a JSON configuration of secrets, classifies them by urgency relative
to AsOf, and prints a markdown or json report. Optionally exits with code
1 when any secret is expired (-FailOnExpired) - useful for CI gating.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [ValidateSet('markdown','json')] [string] $Format = 'markdown',
    [string] $AsOf,
    [int]    $WarningDays = 7,
    [switch] $FailOnExpired
)

$ErrorActionPreference = 'Stop'

# Resolve AsOf default to current UTC date so behaviour is reproducible in CI.
$asOfDate = if ([string]::IsNullOrWhiteSpace($AsOf)) {
    [datetime]::UtcNow.Date
} else {
    [datetime]::Parse($AsOf, [System.Globalization.CultureInfo]::InvariantCulture)
}

# Import the module relative to this script so the entry-point works
# regardless of caller's working directory.
Import-Module (Join-Path $PSScriptRoot 'SecretRotation.psm1') -Force

try {
    $secrets = Read-SecretConfig -Path $ConfigPath
    $report  = Invoke-SecretRotationReport -Secrets $secrets -AsOf $asOfDate -WarningDays $WarningDays
    $rendered = Format-SecretRotationReport -Report $report -Format $Format
    Write-Output $rendered
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}

if ($FailOnExpired -and $report.Summary.Expired -gt 0) {
    exit 1
}
exit 0
