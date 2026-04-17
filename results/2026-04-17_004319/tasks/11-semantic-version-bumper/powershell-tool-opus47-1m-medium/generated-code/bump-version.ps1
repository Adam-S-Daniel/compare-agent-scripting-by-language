#!/usr/bin/env pwsh
# CLI entry point: reads commits from a file (one per --COMMIT-- separator) or stdin,
# and bumps the version in VersionFile, writing to ChangelogFile.
# Prints NEW_VERSION=<version> for easy parsing.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$VersionFile,
    [string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force

if (-not $CommitsFile) { throw "CommitsFile is required" }
$raw = Get-Content -LiteralPath $CommitsFile -Raw
$commits = @($raw -split "(?m)^--COMMIT--\s*$" | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$result = Invoke-VersionBump -VersionFile $VersionFile -Commits $commits -ChangelogFile $ChangelogFile
Write-Output "OLD_VERSION=$($result.OldVersion)"
Write-Output "NEW_VERSION=$($result.NewVersion)"
Write-Output "BUMP_TYPE=$($result.BumpType)"
