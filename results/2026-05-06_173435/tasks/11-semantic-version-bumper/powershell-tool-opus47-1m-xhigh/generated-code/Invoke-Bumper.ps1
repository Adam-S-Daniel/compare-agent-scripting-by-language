<#
.SYNOPSIS
    CLI wrapper around the SemverBumper module.

.DESCRIPTION
    Reads the current version from -VersionFile (VERSION or package.json),
    parses conventional commits from -CommitsFile, computes the next version,
    rewrites the version file, prepends an entry to -ChangelogFile, and
    prints the new version.

    Designed to be called from CI: emits machine-readable output to stdout
    (NEW_VERSION=..., BUMP_TYPE=..., OLD_VERSION=...) and a human readable
    summary on top.

.EXAMPLE
    pwsh ./Invoke-Bumper.ps1 -VersionFile VERSION -CommitsFile commits.txt -ChangelogFile CHANGELOG.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$VersionFile,
    [Parameter(Mandatory)] [string]$CommitsFile,
    [Parameter(Mandatory)] [string]$ChangelogFile,
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve the module path relative to this script so the CLI works no matter
# the caller's CWD.
$modulePath = Join-Path $PSScriptRoot 'src/SemverBumper.psm1'
Import-Module $modulePath -Force

try {
    $result = Invoke-Bumper `
        -VersionFile  $VersionFile `
        -CommitsFile  $CommitsFile `
        -ChangelogFile $ChangelogFile `
        -Date         $Date

    Write-Host "Old version:  $($result.OldVersion)"
    Write-Host "Bump type:    $($result.BumpType)"
    Write-Host "New version:  $($result.NewVersion)"

    # Machine-readable, easy to grep from CI logs.
    Write-Output "OLD_VERSION=$($result.OldVersion)"
    Write-Output "BUMP_TYPE=$($result.BumpType)"
    Write-Output "NEW_VERSION=$($result.NewVersion)"

    # Optionally append to GITHUB_OUTPUT when running inside Actions.
    if ($env:GITHUB_OUTPUT -and (Test-Path -LiteralPath $env:GITHUB_OUTPUT)) {
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "old_version=$($result.OldVersion)"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "bump_type=$($result.BumpType)"
        Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "new_version=$($result.NewVersion)"
    }

    exit 0
} catch {
    Write-Error "Bump failed: $($_.Exception.Message)"
    exit 1
}
