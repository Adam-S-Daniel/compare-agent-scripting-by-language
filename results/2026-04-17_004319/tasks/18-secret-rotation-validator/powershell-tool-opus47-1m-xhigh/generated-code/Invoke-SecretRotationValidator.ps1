#requires -Version 7.0
<#
    .SYNOPSIS
    CLI wrapper for the SecretRotationValidator module.

    .DESCRIPTION
    Loads the module, runs Invoke-SecretRotationValidator against the supplied
    config, and prints the rendered report to stdout. Exits 2 when any secret
    is expired, 1 when only warnings are present, and 0 when everything is ok.
    -FailOn lets callers opt out of the non-zero exit for specific severities
    (e.g. "-FailOn none" for pure reporting).

    .EXAMPLE
    pwsh ./Invoke-SecretRotationValidator.ps1 -ConfigPath secrets.json -WarningDays 14 -Format markdown
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]   $ConfigPath,
    [int]                            $WarningDays = 14,
    [ValidateSet('markdown', 'json')]
    [string]                         $Format      = 'markdown',
    [ValidateSet('expired', 'warning', 'none')]
    [string]                         $FailOn      = 'expired',
    [string]                         $Now
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'SecretRotationValidator.psm1'
Import-Module $modulePath -Force

try {
    $secrets = Import-SecretConfig -Path $ConfigPath
    # Let -Now be optional for real use, required for deterministic tests.
    $nowArg = if ($PSBoundParameters.ContainsKey('Now') -and $Now) { $Now } else { (Get-Date) }
    $report = Invoke-SecretRotationReport -Secrets $secrets -WarningDays $WarningDays -Now $nowArg
    $rendered = Format-SecretRotationReport -Report $report -As $Format
    Write-Output $rendered

    # Pick exit code based on severity so CI can gate merges.
    $exit = 0
    if ($FailOn -eq 'expired' -and $report.Summary.Expired -gt 0) { $exit = 2 }
    elseif ($FailOn -eq 'warning' -and ($report.Summary.Expired -gt 0 -or $report.Summary.Warning -gt 0)) { $exit = 1 }
    exit $exit
} catch {
    # Surface error to stderr so stdout stays clean for JSON consumers.
    [Console]::Error.WriteLine("secret-rotation-validator: $($_.Exception.Message)")
    exit 3
}
