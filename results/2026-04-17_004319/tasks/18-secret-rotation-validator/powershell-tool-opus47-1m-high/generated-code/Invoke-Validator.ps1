#!/usr/bin/env pwsh
# Entry point consumed by the CI workflow. Thin wrapper over the module so the
# workflow does not need to know about Import-Module plumbing.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $ReferenceDate,
    [Parameter(Mandatory)] [int]    $WarningDays,
    [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format,
    [string] $OutputPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SecretRotationValidator.psm1') -Force

try {
    $result = Invoke-SecretRotationValidator `
        -ConfigPath $ConfigPath `
        -ReferenceDate $ReferenceDate `
        -WarningDays $WarningDays `
        -Format $Format
} catch {
    Write-Error $_.Exception.Message
    exit 3
}

# Always print the report so the workflow log captures it.
Write-Output $result.Output

if ($OutputPath) {
    $result.Output | Set-Content -Path $OutputPath -Encoding UTF8
}

# Summary line the act harness can grep for exact assertions.
$summary = "SUMMARY total=$($result.Report.TotalSecrets) expired=$(@($result.Report.Expired).Count) warning=$(@($result.Report.Warning).Count) ok=$(@($result.Report.Ok).Count) exit=$($result.ExitCode)"
Write-Output $summary

exit $result.ExitCode
