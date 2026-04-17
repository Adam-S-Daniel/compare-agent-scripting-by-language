#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI entry point for the semantic version bumper.

.DESCRIPTION
    Thin wrapper around SemanticVersionBumper.psm1. Exists separately so the
    GitHub Actions workflow can invoke a plain .ps1 file. Emits the new version
    on stdout and, when running under GitHub Actions, also writes the values to
    $GITHUB_OUTPUT so downstream steps can consume them.

.EXAMPLE
    pwsh ./Invoke-VersionBumper.ps1 -VersionFile version.txt -CommitLog commits.txt -ChangelogFile CHANGELOG.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionFile,
    [Parameter(Mandatory)][string]$CommitLog,
    [Parameter(Mandatory)][string]$ChangelogFile,
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force

try {
    $result = Invoke-VersionBumper `
        -VersionFile $VersionFile `
        -CommitLog $CommitLog `
        -ChangelogFile $ChangelogFile `
        -Date $Date
}
catch {
    Write-Error "Version bump failed: $($_.Exception.Message)"
    exit 1
}

# Human-readable summary.
Write-Host "Previous version: $($result.PreviousVersion)"
Write-Host "Bump type:        $($result.Bump)"
Write-Host "New version:      $($result.NewVersion)"

# GitHub Actions outputs: only set when the caller is running inside Actions.
if ($env:GITHUB_OUTPUT) {
    "new_version=$($result.NewVersion)"      | Add-Content -LiteralPath $env:GITHUB_OUTPUT
    "previous_version=$($result.PreviousVersion)" | Add-Content -LiteralPath $env:GITHUB_OUTPUT
    "bump=$($result.Bump)"                    | Add-Content -LiteralPath $env:GITHUB_OUTPUT
}

# Machine-readable tail line — assertion target for act-based tests.
Write-Output "NEW_VERSION=$($result.NewVersion)"
