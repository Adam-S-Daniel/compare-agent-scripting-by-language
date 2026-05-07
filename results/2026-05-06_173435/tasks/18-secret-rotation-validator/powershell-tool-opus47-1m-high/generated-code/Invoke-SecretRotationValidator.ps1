#requires -Version 7.0
<#
.SYNOPSIS
    CLI wrapper for the SecretRotationValidator module.

.DESCRIPTION
    Loads a JSON config of secrets, classifies each as expired/warning/ok
    relative to today (or -Today), and prints either a markdown report or JSON.
    Exit code: 0 on success, 1 on any error.

.PARAMETER ConfigPath
    Path to the secrets JSON file. Either a top-level array or { "secrets": [...] }.

.PARAMETER WarningWindowDays
    Days before expiry that trigger the "warning" bucket. Default 14.

.PARAMETER Format
    Output format. 'markdown' (default) or 'json'.

.PARAMETER Today
    Override today's date (yyyy-MM-dd). Useful for deterministic CI runs.

.PARAMETER FailOnExpired
    If set, exit with code 2 when any secret is expired (still prints output first).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ConfigPath,

    [int] $WarningWindowDays = 14,

    [ValidateSet('markdown', 'json')]
    [string] $Format = 'markdown',

    [string] $Today,

    [switch] $FailOnExpired
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $modulePath = Join-Path $PSScriptRoot 'src/SecretRotationValidator.psm1'
    Import-Module $modulePath -Force

    $asOf = if ($PSBoundParameters.ContainsKey('Today') -and $Today) {
        [datetime]::Parse($Today)
    } else {
        (Get-Date).Date
    }

    # Wrap in @() so an empty config doesn't get unwrapped to $null and trip
    # Get-SecretRotationReport's mandatory parameter binding.
    $secrets = @(Read-SecretsConfig -Path $ConfigPath)
    $report  = Get-SecretRotationReport `
                  -Secrets $secrets `
                  -AsOf $asOf `
                  -WarningWindowDays $WarningWindowDays

    Format-RotationReport -Report $report -Format $Format | Write-Output

    if ($FailOnExpired -and $report.summary.expired -gt 0) {
        Write-Error "There are $($report.summary.expired) expired secret(s)."
        exit 2
    }
    exit 0
}
catch {
    # Surface a single, actionable error line to stderr — no stack noise.
    Write-Error $_.Exception.Message
    exit 1
}
