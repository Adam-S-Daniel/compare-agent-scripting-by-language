#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    CLI entry point for the semantic-version-bumper.
.DESCRIPTION
    Reads a version file (VERSION or package.json), applies semantic bumping
    based on conventional-commit messages in $CommitsFile, updates the file,
    appends a new changelog entry, and writes the resulting version to stdout.
.PARAMETER VersionFile
    Path to the version file. If it ends in package.json the version field is
    read/written in place.
.PARAMETER CommitsFile
    Plain-text file: one commit message per line. Literal "\n" is expanded
    to a real newline so footer-style BREAKING CHANGE lines are supported.
.PARAMETER ChangelogFile
    Path to CHANGELOG.md; created if missing.
.PARAMETER Date
    ISO date string for the changelog entry (defaults to today).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionFile,
    [Parameter(Mandatory)][string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md',
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'VersionBumper.psm1') -Force

try {
    $next = Invoke-VersionBump -VersionFile $VersionFile -CommitsFile $CommitsFile -ChangelogFile $ChangelogFile -Date $Date
    # Print the new version on its own line so downstream steps can grep it.
    Write-Output "version=$next"
}
catch {
    Write-Error "bump-version failed: $($_.Exception.Message)"
    exit 1
}
