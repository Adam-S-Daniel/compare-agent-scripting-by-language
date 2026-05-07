#!/usr/bin/env pwsh
# CLI wrapper for the semantic version bumper. Prints the new version (only) to stdout.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionFile,
    [Parameter(Mandatory)][string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force

try {
    $newVersion = Invoke-VersionBump -VersionFile $VersionFile -CommitsFile $CommitsFile -ChangelogFile $ChangelogFile
    Write-Host "NEW_VERSION=$newVersion"
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
