#!/usr/bin/env pwsh
# Thin CLI wrapper around Invoke-SecretRotationValidator so the workflow
# has a single stable entry point. Parameters map 1:1 to the module function.
#
# Exit codes:
#   0 = all ok
#   1 = at least one warning, no expired
#   2 = at least one expired
#   3 = script error (thrown exception)

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [int] $WarningDays = 14,
    [ValidateSet('markdown','json')] [string] $Format = 'markdown',
    # -Now lets callers (CI, tests) freeze time for deterministic output.
    [string] $Now,
    # If set, write output to this path instead of stdout.
    [string] $OutputPath,
    # If set, never exit non-zero on expired/warning (useful for
    # "report-only" runs where the pipeline should not fail the PR).
    [switch] $FailSoft
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
    Import-Module (Join-Path $PSScriptRoot 'SecretRotationValidator.psm1') -Force

    $nowDate = if ($Now) { [DateTime]::Parse($Now) } else { Get-Date }

    $result = Invoke-SecretRotationValidator `
        -ConfigPath $ConfigPath `
        -Now $nowDate `
        -WarningDays $WarningDays `
        -Format $Format `
        -ReturnExitCode

    if ($OutputPath) {
        Set-Content -LiteralPath $OutputPath -Value $result.Output
        Write-Host "Report written to $OutputPath"
    } else {
        Write-Output $result.Output
    }

    # Always echo a one-line summary to stderr so CI logs show the verdict
    # even when -OutputPath swallows the report body.
    $t = $result.Report.Totals
    [Console]::Error.WriteLine("Summary: expired=$($t.Expired) warning=$($t.Warning) ok=$($t.Ok)")

    if ($FailSoft) { exit 0 }
    exit $result.ExitCode
}
catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 3
}
