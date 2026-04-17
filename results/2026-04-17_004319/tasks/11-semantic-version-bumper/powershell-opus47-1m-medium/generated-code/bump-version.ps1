#!/usr/bin/env pwsh
<#
.SYNOPSIS
  CLI wrapper for the SemVerBumper module.

.PARAMETER VersionPath
  Path to a package.json or plain VERSION file.

.PARAMETER CommitsPath
  Path to a commit-log fixture (commits separated by lines of '---').
  Takes precedence over -Commits.

.PARAMETER Commits
  Array of commit messages (alternative to -CommitsPath).

.PARAMETER ChangelogPath
  Path to CHANGELOG.md to prepend a new entry to.

.OUTPUTS
  Prints "NEW_VERSION=<x.y.z>" and "BUMP=<level>" to stdout.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionPath,
    [string]$CommitsPath,
    [string[]]$Commits,
    [string]$ChangelogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SemVerBumper.psm1') -Force

try {
    if ($CommitsPath) {
        $Commits = Read-CommitFixture -Path $CommitsPath
    }
    if (-not $Commits) {
        throw "Provide -CommitsPath or -Commits."
    }

    $result = Invoke-VersionBump -VersionPath $VersionPath -Commits $Commits -ChangelogPath $ChangelogPath

    Write-Output "OLD_VERSION=$($result.OldVersion)"
    Write-Output "NEW_VERSION=$($result.NewVersion)"
    Write-Output "BUMP=$($result.Bump)"
    Write-Output "---CHANGELOG---"
    Write-Output $result.Changelog
}
catch {
    Write-Error "bump-version failed: $($_.Exception.Message)"
    exit 1
}
