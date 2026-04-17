# CLI entry point for the version bumper.
# Reads a version file + a commits file, bumps the version,
# updates the changelog, and writes "NEW_VERSION=x.y.z" to stdout
# (so it can be captured into $GITHUB_OUTPUT in CI).

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VersionFile,
    [Parameter(Mandatory)][string]$CommitsFile,
    [string]$ChangelogFile = 'CHANGELOG.md',
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1') -Force

try {
    $result = Invoke-VersionBump `
        -VersionFile $VersionFile `
        -CommitsFile $CommitsFile `
        -ChangelogFile $ChangelogFile `
        -Date $Date

    # Write-Output (not Write-Host) so the workflow can pipe the output
    # into $GITHUB_OUTPUT and so callers can capture lines via Tee-Object.
    Write-Output "PREVIOUS_VERSION=$($result.PreviousVersion)"
    Write-Output "BUMP_TYPE=$($result.BumpType)"
    Write-Output "NEW_VERSION=$($result.NewVersion)"
    Write-Output "COMMIT_COUNT=$($result.CommitCount)"
} catch {
    Write-Error "Version bump failed: $_"
    exit 1
}
