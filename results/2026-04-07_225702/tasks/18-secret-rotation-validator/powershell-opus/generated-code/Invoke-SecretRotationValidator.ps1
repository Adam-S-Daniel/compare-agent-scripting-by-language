#!/usr/bin/env pwsh
# Invoke-SecretRotationValidator.ps1
# CLI entry point for the secret rotation validator.
# Usage:
#   ./Invoke-SecretRotationValidator.ps1 -ConfigPath secrets.json -Format Markdown -WarningDays 7

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [ValidateSet("JSON", "Markdown")]
    [string]$Format = "Markdown",

    [int]$WarningDays = 7
)

# Load the validator functions
. "$PSScriptRoot/SecretRotationValidator.ps1"

try {
    $secrets = Import-SecretConfig -Path $ConfigPath
    $report  = Get-RotationReport -Secrets $secrets -WarningDays $WarningDays
    $output  = Format-RotationReport -Report $report -Format $Format

    Write-Output $output

    # Exit with non-zero status if any secrets are expired
    if ($report.Summary.Expired -gt 0) {
        exit 1
    }
} catch {
    Write-Error "Error: $_"
    exit 2
}
