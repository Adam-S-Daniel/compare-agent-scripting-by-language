#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Semantic version bumper based on conventional commit messages.

.DESCRIPTION
    Parses a version file (VERSION or package.json) containing a semantic version string,
    determines the next version based on conventional commit messages:
      - feat -> minor bump
      - fix -> patch bump
      - BREAKING CHANGE or feat! / fix! -> major bump
    Updates the version file, generates a changelog entry, and outputs the new version.

.PARAMETER VersionFile
    Path to the version file (VERSION or package.json). Defaults to "VERSION".

.PARAMETER CommitLog
    Path to a file containing commit messages (one per line). If not specified,
    reads from git log since the last tag.

.PARAMETER ChangelogFile
    Path to the changelog file. Defaults to "CHANGELOG.md".

.PARAMETER DryRun
    If set, outputs the new version without modifying files.
#>

param(
    [string]$VersionFile = "VERSION",
    [string]$CommitLog = "",
    [string]$ChangelogFile = "CHANGELOG.md",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Helper Functions ---

function Get-SemanticVersion {
    <#
    .SYNOPSIS
        Parses a semantic version string into major, minor, patch components.
    #>
    param([string]$VersionString)

    $VersionString = $VersionString.Trim()

    # Strip leading 'v' if present
    if ($VersionString.StartsWith("v") -or $VersionString.StartsWith("V")) {
        $VersionString = $VersionString.Substring(1)
    }

    if ($VersionString -notmatch '^\d+\.\d+\.\d+') {
        throw "Invalid semantic version: '$VersionString'. Expected format: MAJOR.MINOR.PATCH"
    }

    $parts = $VersionString.Split(".")
    return @{
        Major = [int]$parts[0]
        Minor = [int]$parts[1]
        Patch = [int]$parts[2]
    }
}

function Get-CurrentVersion {
    <#
    .SYNOPSIS
        Reads the current version from a VERSION file or package.json.
    #>
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: '$FilePath'"
    }

    $fileName = [System.IO.Path]::GetFileName($FilePath)

    if ($fileName -eq "package.json") {
        # Parse JSON and extract version field
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json
        if (-not $json.version) {
            throw "No 'version' field found in package.json"
        }
        return $json.version
    }
    else {
        # Plain text version file - read first non-empty line
        $content = Get-Content $FilePath | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1
        if (-not $content) {
            throw "Version file is empty: '$FilePath'"
        }
        return $content.Trim()
    }
}

function Get-BumpType {
    <#
    .SYNOPSIS
        Analyzes commit messages and determines the bump type (major, minor, patch).
        Uses conventional commit format:
          - BREAKING CHANGE or !: -> major
          - feat: -> minor
          - fix: -> patch
    #>
    param([string[]]$Commits)

    $bumpType = "none"

    foreach ($commit in $Commits) {
        $line = $commit.Trim()
        if ($line -eq "") { continue }

        # Check for breaking changes first (highest priority)
        if ($line -match "^(feat|fix|chore|docs|style|refactor|perf|test|build|ci)(\(.+\))?!:" -or
            $line -match "BREAKING CHANGE" -or
            $line -match "BREAKING-CHANGE") {
            return "major"
        }

        # Check for feat (minor bump)
        if ($line -match "^feat(\(.+\))?:") {
            if ($bumpType -ne "major") {
                $bumpType = "minor"
            }
        }

        # Check for fix (patch bump)
        if ($line -match "^fix(\(.+\))?:") {
            if ($bumpType -eq "none") {
                $bumpType = "patch"
            }
        }
    }

    return $bumpType
}

function Get-NextVersion {
    <#
    .SYNOPSIS
        Computes the next version given the current version and bump type.
    #>
    param(
        [hashtable]$Version,
        [string]$BumpType
    )

    switch ($BumpType) {
        "major" {
            return @{
                Major = $Version.Major + 1
                Minor = 0
                Patch = 0
            }
        }
        "minor" {
            return @{
                Major = $Version.Major
                Minor = $Version.Minor + 1
                Patch = 0
            }
        }
        "patch" {
            return @{
                Major = $Version.Major
                Minor = $Version.Minor
                Patch = $Version.Patch + 1
            }
        }
        default {
            # No bump needed, return same version
            return $Version
        }
    }
}

function Format-Version {
    <#
    .SYNOPSIS
        Formats a version hashtable as a string "MAJOR.MINOR.PATCH".
    #>
    param([hashtable]$Version)
    return "$($Version.Major).$($Version.Minor).$($Version.Patch)"
}

function Update-VersionFile {
    <#
    .SYNOPSIS
        Writes the new version back to the version file.
    #>
    param(
        [string]$FilePath,
        [string]$NewVersion
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)

    if ($fileName -eq "package.json") {
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content $FilePath
    }
    else {
        $NewVersion | Set-Content $FilePath
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Generates a changelog entry from commit messages grouped by type.
    #>
    param(
        [string]$NewVersion,
        [string[]]$Commits
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $breaking = @()
    $features = @()
    $fixes = @()
    $other = @()

    foreach ($commit in $Commits) {
        $line = $commit.Trim()
        if ($line -eq "") { continue }

        if ($line -match "BREAKING CHANGE" -or $line -match "BREAKING-CHANGE" -or $line -match "^(\w+)(\(.+\))?!:") {
            $breaking += $line
        }
        elseif ($line -match "^feat(\(.+\))?:(.*)") {
            $features += $Matches[2].Trim()
        }
        elseif ($line -match "^fix(\(.+\))?:(.*)") {
            $fixes += $Matches[2].Trim()
        }
        else {
            $other += $line
        }
    }

    $entry = "## [$NewVersion] - $date`n`n"

    if ($breaking.Count -gt 0) {
        $entry += "### Breaking Changes`n`n"
        foreach ($b in $breaking) {
            $entry += "- $b`n"
        }
        $entry += "`n"
    }

    if ($features.Count -gt 0) {
        $entry += "### Features`n`n"
        foreach ($f in $features) {
            $entry += "- $f`n"
        }
        $entry += "`n"
    }

    if ($fixes.Count -gt 0) {
        $entry += "### Bug Fixes`n`n"
        foreach ($fx in $fixes) {
            $entry += "- $fx`n"
        }
        $entry += "`n"
    }

    return $entry
}

function Update-Changelog {
    <#
    .SYNOPSIS
        Prepends a new changelog entry to the changelog file.
    #>
    param(
        [string]$FilePath,
        [string]$Entry
    )

    if (Test-Path $FilePath) {
        $existing = Get-Content $FilePath -Raw
        $Entry + $existing | Set-Content $FilePath
    }
    else {
        "# Changelog`n`n" + $Entry | Set-Content $FilePath
    }
}

# --- Main Logic ---

function Invoke-SemanticVersionBump {
    param(
        [string]$VersionFilePath,
        [string]$CommitLogPath,
        [string]$ChangelogPath,
        [switch]$DryRunMode
    )

    # Read current version
    $currentVersionString = Get-CurrentVersion -FilePath $VersionFilePath
    $currentVersion = Get-SemanticVersion -VersionString $currentVersionString
    Write-Host "Current version: $(Format-Version $currentVersion)"

    # Read commit messages
    if ($CommitLogPath -and (Test-Path $CommitLogPath)) {
        $commits = Get-Content $CommitLogPath
    }
    else {
        # Try to read from git log
        try {
            $commits = git log --oneline --format="%s" 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "git log failed"
            }
        }
        catch {
            throw "No commit log provided and git log failed: $_"
        }
    }

    # Determine bump type
    $bumpType = Get-BumpType -Commits $commits
    Write-Host "Bump type: $bumpType"

    if ($bumpType -eq "none") {
        Write-Host "No version bump needed based on commits."
        Write-Host "NEW_VERSION=$(Format-Version $currentVersion)"
        return (Format-Version $currentVersion)
    }

    # Calculate next version
    $nextVersion = Get-NextVersion -Version $currentVersion -BumpType $bumpType
    $nextVersionString = Format-Version $nextVersion
    Write-Host "New version: $nextVersionString"

    if (-not $DryRunMode) {
        # Update version file
        Update-VersionFile -FilePath $VersionFilePath -NewVersion $nextVersionString
        Write-Host "Updated $VersionFilePath"

        # Generate and write changelog
        $entry = New-ChangelogEntry -NewVersion $nextVersionString -Commits $commits
        Update-Changelog -FilePath $ChangelogPath -Entry $entry
        Write-Host "Updated $ChangelogPath"
    }

    # Output the new version in a parseable format
    Write-Host "NEW_VERSION=$nextVersionString"
    return $nextVersionString
}

# Run if executed directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne ".") {
    Invoke-SemanticVersionBump `
        -VersionFilePath $VersionFile `
        -CommitLogPath $CommitLog `
        -ChangelogPath $ChangelogFile `
        -DryRunMode:$DryRun
}
