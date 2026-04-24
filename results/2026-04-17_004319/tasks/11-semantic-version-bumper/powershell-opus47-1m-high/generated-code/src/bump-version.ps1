#!/usr/bin/env pwsh
# bump-version.ps1
#
# CLI wrapper around the SemanticVersionBumper module. Reads the current
# version, inspects the supplied commit log, writes the new version and
# changelog entry, and emits the new version on stdout (so a calling CI
# pipeline can capture it via `id` / outputs).

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionFile,
    [Parameter(Mandatory)][string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md',
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
Import-Module $modulePath -Force

try {
    $result = Invoke-VersionBump `
        -VersionFile $VersionFile `
        -CommitsFile $CommitsFile `
        -ChangelogFile $ChangelogFile `
        -Date $Date

    if (-not $Quiet) {
        Write-Host "Bumped $($result.OldVersion) -> $($result.NewVersion) ($($result.BumpType))"
    }
    # Machine-readable line that the workflow/test harness can grep for.
    Write-Output "NEW_VERSION=$($result.NewVersion)"
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
