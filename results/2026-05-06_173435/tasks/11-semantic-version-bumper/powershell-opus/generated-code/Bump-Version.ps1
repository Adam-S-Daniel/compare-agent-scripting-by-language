# Semantic Version Bumper
# Parses a VERSION file, determines bump type from conventional commits,
# updates the file, generates a changelog entry, and outputs the new version.

param(
    [string]$VersionFile = "VERSION",
    [string]$CommitLogFile = "",
    [string]$ChangelogFile = "CHANGELOG.md",
    [switch]$UseGitLog
)

$ErrorActionPreference = "Stop"

function Parse-SemanticVersion {
    param([string]$VersionString)

    $trimmed = $VersionString.Trim()
    if ($trimmed -match '^\d+\.\d+\.\d+$') {
        $parts = $trimmed -split '\.'
        return @{
            Major = [int]$parts[0]
            Minor = [int]$parts[1]
            Patch = [int]$parts[2]
        }
    }
    # Try parsing from package.json format
    if ($trimmed -match '"version"\s*:\s*"(\d+\.\d+\.\d+)"') {
        $parts = $Matches[1] -split '\.'
        return @{
            Major = [int]$parts[0]
            Minor = [int]$parts[1]
            Patch = [int]$parts[2]
        }
    }
    throw "Invalid version format: '$trimmed'. Expected semantic version (e.g., 1.2.3)"
}

function Get-BumpType {
    param([string[]]$CommitMessages)

    $bumpType = "none"

    foreach ($msg in $CommitMessages) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        # Breaking change via footer
        if ($msg -match 'BREAKING CHANGE:') {
            return "major"
        }
        # Breaking change via ! after type
        if ($msg -match '^\w+!:') {
            return "major"
        }
        # Feature commit -> minor (but keep checking for major)
        if ($msg -match '^feat(\(.+\))?:') {
            if ($bumpType -ne "major") { $bumpType = "minor" }
        }
        # Fix commit -> patch
        if ($msg -match '^fix(\(.+\))?:') {
            if ($bumpType -eq "none") { $bumpType = "patch" }
        }
    }

    return $bumpType
}

function Bump-SemanticVersion {
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
            return $Version
        }
    }
}

function Format-Version {
    param([hashtable]$Version)
    return "$($Version.Major).$($Version.Minor).$($Version.Patch)"
}

function Generate-Changelog {
    param(
        [string]$NewVersion,
        [string[]]$CommitMessages
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = "## [$NewVersion] - $date`n`n"

    $breaking = @()
    $features = @()
    $fixes = @()
    $other = @()

    foreach ($msg in $CommitMessages) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        if ($msg -match 'BREAKING CHANGE:' -or $msg -match '^\w+!:') {
            $breaking += "- $msg"
        }
        elseif ($msg -match '^feat') {
            $features += "- $msg"
        }
        elseif ($msg -match '^fix') {
            $fixes += "- $msg"
        }
        else {
            $other += "- $msg"
        }
    }

    if ($breaking.Count -gt 0) {
        $entry += "### Breaking Changes`n" + ($breaking -join "`n") + "`n`n"
    }
    if ($features.Count -gt 0) {
        $entry += "### Features`n" + ($features -join "`n") + "`n`n"
    }
    if ($fixes.Count -gt 0) {
        $entry += "### Bug Fixes`n" + ($fixes -join "`n") + "`n`n"
    }
    if ($other.Count -gt 0) {
        $entry += "### Other`n" + ($other -join "`n") + "`n`n"
    }

    return $entry
}

# Main execution (only runs when script is invoked directly, not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    # Read version file
    if (-not (Test-Path $VersionFile)) {
        Write-Error "Version file not found: $VersionFile"
        exit 1
    }

    $versionContent = Get-Content $VersionFile -Raw
    $currentVersion = Parse-SemanticVersion -VersionString $versionContent

    # Get commit messages
    $commits = @()
    if ($UseGitLog) {
        $gitOutput = git log --format="%s" HEAD 2>&1
        if ($LASTEXITCODE -eq 0) {
            $commits = $gitOutput -split "`n"
        } else {
            Write-Error "Failed to read git log: $gitOutput"
            exit 1
        }
    }
    elseif ($CommitLogFile -and (Test-Path $CommitLogFile)) {
        $commits = Get-Content $CommitLogFile
    }
    else {
        Write-Error "No commit source specified. Use -CommitLogFile or -UseGitLog"
        exit 1
    }

    # Determine bump type
    $bumpType = Get-BumpType -CommitMessages $commits
    if ($bumpType -eq "none") {
        Write-Output "NO_BUMP"
        Write-Output "No version bump needed based on commit messages."
        exit 0
    }

    # Calculate new version
    $newVersion = Bump-SemanticVersion -Version $currentVersion -BumpType $bumpType
    $newVersionStr = Format-Version -Version $newVersion

    # Update version file
    Set-Content -Path $VersionFile -Value $newVersionStr -NoNewline

    # Generate changelog
    $changelogEntry = Generate-Changelog -NewVersion $newVersionStr -CommitMessages $commits
    if (Test-Path $ChangelogFile) {
        $existingChangelog = Get-Content $ChangelogFile -Raw
        Set-Content -Path $ChangelogFile -Value ($changelogEntry + $existingChangelog)
    }
    else {
        Set-Content -Path $ChangelogFile -Value ("# Changelog`n`n" + $changelogEntry)
    }

    Write-Output "BUMP_TYPE=$bumpType"
    Write-Output "NEW_VERSION=$newVersionStr"
    Write-Output "Bumped version from $(Format-Version $currentVersion) to $newVersionStr ($bumpType)"
}
