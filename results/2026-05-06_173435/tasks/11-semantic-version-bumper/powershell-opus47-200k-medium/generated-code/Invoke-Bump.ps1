#!/usr/bin/env pwsh
# Invoke-Bump.ps1 — entry-point script the workflow invokes.
# Wraps Invoke-VersionBump and prints a parsable line for CI assertions.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionFile,
    [Parameter(Mandatory)][string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md',
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force

try {
    $r = Invoke-VersionBump -VersionFile $VersionFile -CommitsFile $CommitsFile `
                            -ChangelogFile $ChangelogFile -Date $Date
    Write-Host "OldVersion=$($r.OldVersion)"
    Write-Host "BumpType=$($r.BumpType)"
    Write-Host "NewVersion=$($r.NewVersion)"
    # Stable single-line marker for the harness to grep on.
    Write-Host "RESULT::$($r.OldVersion)::$($r.BumpType)::$($r.NewVersion)"
}
catch {
    Write-Error "Version bump failed: $_"
    exit 1
}
