#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Semantic version bumper driven by conventional commits.
.DESCRIPTION
    Reads the current version from a file (version.txt or package.json),
    analyzes git commit messages since the last tag (or uses provided commit log),
    determines the appropriate semver bump, updates the version file,
    generates a changelog entry, and outputs the new version.
.PARAMETER VersionFile
    Path to the version file (version.txt or package.json). Defaults to VERSION.txt.
.PARAMETER CommitLogFile
    Optional path to a file containing commit messages (one per line, sha-prefixed).
    If not provided, git log is used to get commits since the last tag.
.PARAMETER DryRun
    If set, prints what would happen without modifying any files.
#>
[CmdletBinding()]
param(
    [string]$VersionFile = 'VERSION.txt',
    [string]$CommitLogFile = '',
    [switch]$DryRun
)

# Import the module from the same directory as this script
$ModulePath = Join-Path $PSScriptRoot 'SemanticVersionBumper.psm1'
Import-Module $ModulePath -Force

# --- Step 1: Read current version ---
try {
    $currentVersion = Read-Version -Path $VersionFile
    $currentString = "$($currentVersion.Major).$($currentVersion.Minor).$($currentVersion.Patch)"
    Write-Host "Current version: $currentString"
} catch {
    Write-Error "Failed to read version: $_"
    exit 1
}

# --- Step 2: Get commit messages ---
if ($CommitLogFile -and (Test-Path -LiteralPath $CommitLogFile)) {
    # Use provided commit log file
    $commits = @(Get-Content -LiteralPath $CommitLogFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Write-Host "Read $($commits.Count) commits from $CommitLogFile"
} else {
    # Get commits from git since the last tag
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        if ($lastTag) {
            $commits = @(git log --oneline "$lastTag..HEAD" 2>$null)
        } else {
            $commits = @(git log --oneline 2>$null)
        }
        Write-Host "Found $($commits.Count) commits from git log"
    } catch {
        Write-Error "Failed to read git log: $_"
        exit 1
    }
}

if ($commits.Count -eq 0) {
    Write-Host "No commits found. Nothing to do."
    Write-Host "NEW_VERSION=$currentString"
    exit 0
}

# --- Step 3: Determine bump type ---
$bumpType = Get-BumpType -CommitMessages $commits
Write-Host "Bump type: $bumpType"

if ($bumpType -eq 'none') {
    Write-Host "No version-relevant commits found. Version stays at $currentString"
    Write-Host "NEW_VERSION=$currentString"
    exit 0
}

# --- Step 4: Calculate new version ---
$newVersion = Get-NextVersion -Version $currentVersion -BumpType $bumpType
Write-Host "New version: $newVersion"

# --- Step 5: Generate changelog entry ---
$changelog = New-ChangelogEntry -CommitMessages $commits -Version $newVersion
Write-Host ""
Write-Host "--- Changelog Entry ---"
Write-Host $changelog
Write-Host "--- End Changelog ---"

# --- Step 6: Update version file (unless dry run) ---
if ($DryRun) {
    Write-Host "[DRY RUN] Would update $VersionFile to $newVersion"
} else {
    try {
        Write-Version -Path $VersionFile -NewVersion $newVersion
        Write-Host "Updated $VersionFile to $newVersion"
    } catch {
        Write-Error "Failed to write version: $_"
        exit 1
    }
}

# Output the new version for CI consumption
Write-Host "NEW_VERSION=$newVersion"
