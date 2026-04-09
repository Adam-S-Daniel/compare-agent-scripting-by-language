#!/usr/bin/env pwsh
# Bump-SemanticVersion.ps1 - Entry point for semantic version bumping pipeline
#
# Reads the current version, classifies conventional commits, bumps the version,
# updates the version file, generates a changelog, and outputs the new version.
#
# Usage:
#   ./Bump-SemanticVersion.ps1 [-VersionFile VERSION] [-CommitLogFile commits.txt] [-ChangelogFile CHANGELOG.md]

[CmdletBinding()]
param(
    [string]$VersionFile   = 'VERSION',
    [string]$CommitLogFile = '',
    [string]$ChangelogFile = 'CHANGELOG.md'
)

$ErrorActionPreference = 'Stop'

# Import core functions
. "$PSScriptRoot/VersionBumper.ps1"

# Step 1: Read current version
Write-Host "Reading version from: $VersionFile"
try {
    $currentVersion = Get-CurrentVersion -FilePath $VersionFile
    $currentStr = "$($currentVersion.Major).$($currentVersion.Minor).$($currentVersion.Patch)"
    Write-Host "Current version: $currentStr"
} catch {
    Write-Error "Failed to read version: $_"
    exit 1
}

# Step 2: Collect commit messages
Write-Host 'Retrieving commit messages...'
try {
    $commits = Get-CommitMessages -CommitLogFile $CommitLogFile
    if (-not $commits -or $commits.Count -eq 0) {
        Write-Warning 'No commit messages found. Nothing to bump.'
        exit 0
    }
    Write-Host "Found $($commits.Count) commit(s)"
} catch {
    Write-Error "Failed to get commits: $_"
    exit 1
}

# Step 3: Determine bump type from commit messages
$bumpType = Get-BumpType -CommitMessages $commits
Write-Host "Bump type: $bumpType"

# Step 4: Calculate new version
$newVersion = Invoke-VersionBump -CurrentVersion $currentVersion -BumpType $bumpType
Write-Host "New version: $newVersion"

# Step 5: Update the version file
try {
    Update-VersionFile -FilePath $VersionFile -NewVersion $newVersion
    Write-Host "Updated $VersionFile to $newVersion"
} catch {
    Write-Error "Failed to update version file: $_"
    exit 1
}

# Step 6: Generate changelog entry
try {
    $changelogEntry = New-ChangelogEntry -NewVersion $newVersion -CommitMessages $commits
    if (Test-Path $ChangelogFile) {
        $existing = Get-Content $ChangelogFile -Raw
        ($changelogEntry + "`n" + $existing) | Set-Content $ChangelogFile -NoNewline
    } else {
        ("# Changelog`n`n" + $changelogEntry) | Set-Content $ChangelogFile -NoNewline
    }
    Write-Host "Updated changelog: $ChangelogFile"
} catch {
    Write-Error "Failed to update changelog: $_"
    exit 1
}

# Output for CI/CD consumption (parseable by downstream steps)
Write-Output "NEW_VERSION=$newVersion"
