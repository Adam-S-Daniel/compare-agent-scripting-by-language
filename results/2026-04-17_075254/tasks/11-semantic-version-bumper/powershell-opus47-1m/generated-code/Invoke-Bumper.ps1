#!/usr/bin/env pwsh
# Thin CLI wrapper around SemanticVersionBumper.psm1.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $VersionFile,
    [Parameter(Mandatory)][string] $CommitsFile,
    [string] $ChangelogFile = 'CHANGELOG.md'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force
$result = Invoke-VersionBump -VersionFile $VersionFile -CommitsFile $CommitsFile -ChangelogFile $ChangelogFile
Write-Output ("OLD_VERSION={0}" -f $result.OldVersion)
Write-Output ("NEW_VERSION={0}" -f $result.NewVersion)
Write-Output ("BUMP_TYPE={0}"   -f $result.BumpType)
