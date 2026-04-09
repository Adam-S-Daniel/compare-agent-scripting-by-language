#!/usr/bin/env pwsh
# Invoke-VersionBump.ps1
# CLI entry point for the semantic version bumper.
# Usage:
#   ./Invoke-VersionBump.ps1 -VersionFile VERSION -CommitLogFile commits.txt
#   ./Invoke-VersionBump.ps1 -VersionFile package.json -CommitLogFile commits.txt

param(
    [Parameter(Mandatory)]
    [string]$VersionFile,

    [Parameter(Mandatory)]
    [string]$CommitLogFile
)

$ErrorActionPreference = 'Stop'

# Load the library functions
. "$PSScriptRoot/SemanticVersionBumper.ps1"

try {
    $result = Invoke-SemanticVersionBump -VersionFile $VersionFile -CommitLogFile $CommitLogFile

    Write-Host "Old version: $($result.OldVersion)"
    Write-Host "Bump type:   $($result.BumpType)"
    Write-Host "New version: $($result.NewVersion)"
    Write-Host ''
    Write-Host '--- Changelog ---'
    Write-Host $result.Changelog

    # If running in GitHub Actions, set outputs
    if ($env:GITHUB_OUTPUT) {
        "old_version=$($result.OldVersion)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        "new_version=$($result.NewVersion)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        "bump_type=$($result.BumpType)"     | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        "changelog<<EOF`n$($result.Changelog)`nEOF" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }
} catch {
    Write-Error "Version bump failed: $_"
    exit 1
}
