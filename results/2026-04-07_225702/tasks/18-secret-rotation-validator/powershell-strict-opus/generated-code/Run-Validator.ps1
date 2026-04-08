#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Entry point for the Secret Rotation Validator.
.DESCRIPTION
    Loads mock secrets, evaluates them against rotation policies,
    and outputs a report in the chosen format (markdown or json).
.PARAMETER Format
    Output format: 'markdown' or 'json'. Defaults to 'markdown'.
.PARAMETER WarningDays
    Number of days before expiry to trigger a warning. Defaults to 7.
.PARAMETER ReferenceDate
    Date to evaluate against. Defaults to today.
#>
[CmdletBinding()]
param(
    [ValidateSet('markdown', 'json')]
    [string]$Format = 'markdown',

    [ValidateRange(0, 365)]
    [int]$WarningDays = 7,

    [datetime]$ReferenceDate = (Get-Date).Date
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load modules
. "$PSScriptRoot/SecretRotationValidator.ps1"
. "$PSScriptRoot/MockSecrets.ps1"

# Generate report
[hashtable[]]$secrets = Get-MockSecrets
[hashtable]$report = Get-RotationReport -Secrets $secrets -ReferenceDate $ReferenceDate -WarningDays $WarningDays

# Output in requested format
switch ($Format) {
    'markdown' {
        [string]$output = ConvertTo-MarkdownReport -Report $report
        Write-Output $output
    }
    'json' {
        [string]$output = ConvertTo-JsonReport -Report $report
        Write-Output $output
    }
}

# Exit with non-zero if any secrets are expired
if ([int]$report.Summary.ExpiredCount -gt 0) {
    exit 1
}
