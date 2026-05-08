#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI entry point for the dependency-license checker.

.DESCRIPTION
    Imports the DependencyLicenseChecker module, runs an end-to-end check,
    prints the textual report, and exits with:
       0  - all approved or unknown but no denied
       1  - one or more denied dependencies (compliance violation)
       2  - operational error (bad input, missing files, etc.)

    Used by the GitHub Actions workflow as the gate step.

.PARAMETER ManifestPath
    Path to package.json or requirements.txt.

.PARAMETER ConfigPath
    JSON config with AllowList and DenyList arrays.

.PARAMETER MockDataPath
    JSON file mapping package name -> license string.
    In real usage this would be replaced by an HTTP lookup; we mock for tests.

.PARAMETER OutputJson
    If set, also write the JSON form of the report to this path.

.PARAMETER FailOnUnknown
    If set, treat any 'unknown' status as a violation (exit 1).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManifestPath,
    [Parameter(Mandatory)] [string] $ConfigPath,
    [Parameter(Mandatory)] [string] $MockDataPath,
    [string] $OutputJson,
    [switch] $FailOnUnknown
)

$ErrorActionPreference = 'Stop'

try {
    $modulePath = Join-Path $PSScriptRoot '..' 'src' 'DependencyLicenseChecker.psm1'
    Import-Module $modulePath -Force

    $report = Invoke-LicenseCheck `
        -ManifestPath $ManifestPath `
        -ConfigPath   $ConfigPath `
        -MockDataPath $MockDataPath

    Write-Output (Format-LicenseReport -Report $report -As Text)

    if ($OutputJson) {
        Format-LicenseReport -Report $report -As Json | Set-Content -LiteralPath $OutputJson
        Write-Output "Wrote JSON report to: $OutputJson"
    }

    if ($report.HasViolations) {
        Write-Output 'RESULT: VIOLATIONS_FOUND'
        exit 1
    }
    if ($FailOnUnknown -and $report.Summary.Unknown -gt 0) {
        Write-Output 'RESULT: UNKNOWN_LICENSES_PRESENT'
        exit 1
    }
    Write-Output 'RESULT: COMPLIANT'
    exit 0
}
catch {
    # Operational failure (file missing, parse error, etc.)
    Write-Error ("ERROR: {0}" -f $_.Exception.Message)
    exit 2
}
