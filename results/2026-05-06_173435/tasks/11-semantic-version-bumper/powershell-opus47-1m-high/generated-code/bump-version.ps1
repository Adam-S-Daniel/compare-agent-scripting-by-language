#!/usr/bin/env pwsh
# bump-version.ps1
#
# Thin CLI wrapper around the Bumper module. Reads a version file (VERSION
# or package.json), parses a commit fixture, bumps the version per the
# Conventional Commits spec, and writes a new CHANGELOG entry.
#
# Designed to be called from CI: stdout contains a single line of the form
#   NEW_VERSION=<x.y.z>
# plus a JSON summary on stderr (so CI logs stay parseable).

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$VersionFile,
    [Parameter(Mandatory)] [string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md',
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'Bumper.psm1'
Import-Module $modulePath -Force

try {
    $result = Invoke-VersionBump `
        -VersionFile   $VersionFile `
        -CommitsFile   $CommitsFile `
        -ChangelogFile $ChangelogFile `
        -Date          $Date

    # Machine-readable output on stdout (one line per fact).
    "PREVIOUS_VERSION=$($result.PreviousVersion)"
    "NEW_VERSION=$($result.NextVersion)"
    "BUMP_TYPE=$($result.BumpType)"

    # JSON summary on stderr for human inspection.
    $json = $result | ConvertTo-Json -Compress
    [Console]::Error.WriteLine($json)

    exit 0
}
catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}
