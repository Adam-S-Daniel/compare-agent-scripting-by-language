#!/usr/bin/env pwsh
# Bump.ps1 - thin CLI wrapper around SemanticVersionBumper.ps1.
# Used by .github/workflows/semantic-version-bumper.yml so the workflow
# never has to dot-source PowerShell modules in the YAML body.
#
# Usage:
#   pwsh ./Bump.ps1 -VersionFile package.json -CommitsFile commits.bin \
#                   -ChangelogFile CHANGELOG.md [-Date 2026-05-07]

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $VersionFile,
    [Parameter(Mandatory)] [string] $CommitsFile,
    [Parameter(Mandatory)] [string] $ChangelogFile,
    [string] $Date = (Get-Date -Format 'yyyy-MM-dd')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'SemanticVersionBumper.ps1')

$next = Invoke-VersionBumper `
    -VersionFile $VersionFile `
    -CommitsFile $CommitsFile `
    -ChangelogFile $ChangelogFile `
    -Date $Date

# Stable, easy-to-grep output for the workflow + act-result asserts.
Write-Host "NEW_VERSION=$next"
