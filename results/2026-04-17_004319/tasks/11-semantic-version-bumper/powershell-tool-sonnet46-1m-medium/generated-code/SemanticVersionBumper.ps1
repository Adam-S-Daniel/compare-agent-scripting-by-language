# SemanticVersionBumper.ps1
# Parses a version file (version.json or package.json), determines the next
# semantic version based on conventional commit messages, updates the file,
# generates a changelog entry, and outputs the new version.
#
# Conventional commit rules:
#   feat!: / fix!: / any!: or "BREAKING CHANGE:" in body -> major bump
#   feat: / feat(scope):                                 -> minor bump
#   fix:  / fix(scope):                                  -> patch bump
#   everything else (chore, docs, style, ci, ...)        -> no bump

[CmdletBinding()]
param(
    [string]$VersionFile  = "version.json",
    [string]$CommitsFile  = "commits.txt",
    [string]$ChangelogFile = "CHANGELOG.md",
    [switch]$DryRun
)

# ---------------------------------------------------------------------------
# Core functions (dot-sourced into the test file)
# ---------------------------------------------------------------------------

function Get-BumpType {
    <#
    .SYNOPSIS
        Given an array of conventional-commit message strings, returns the
        required bump type: "major", "minor", "patch", or "none".
    #>
    param(
        [string[]]$Commits
    )

    $bump = "none"

    foreach ($commit in $Commits) {
        # Breaking change: exclamation mark before colon  (feat!:, fix!:, etc.)
        # or "BREAKING CHANGE:" anywhere in the message
        if ($commit -match '^[a-zA-Z]+(\([^)]*\))?!:' -or $commit -match 'BREAKING CHANGE:') {
            return "major"
        }
        # Feature: feat: or feat(scope):
        if ($commit -match '^feat(\([^)]*\))?:' -and $bump -ne "major") {
            $bump = "minor"
        }
        # Fix: fix: or fix(scope):
        if ($commit -match '^fix(\([^)]*\))?:' -and $bump -eq "none") {
            $bump = "patch"
        }
    }

    return $bump
}

function Get-NewVersion {
    <#
    .SYNOPSIS
        Calculates the next semantic version given the current version string
        and a bump type ("major", "minor", "patch", "none").
    #>
    param(
        [string]$CurrentVersion,
        [string]$BumpType
    )

    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: '$CurrentVersion'. Expected format X.Y.Z"
    }

    [int]$major = $Matches[1]
    [int]$minor = $Matches[2]
    [int]$patch = $Matches[3]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
        default { return $CurrentVersion }
    }
}

function Get-ChangelogEntry {
    <#
    .SYNOPSIS
        Generates a markdown changelog entry for the given new version and
        list of conventional commit messages.
    #>
    param(
        [string]$NewVersion,
        [string[]]$Commits,
        [DateTime]$Date = (Get-Date)
    )

    $dateStr = $Date.ToString("yyyy-MM-dd")
    $entry   = "## [$NewVersion] - $dateStr`n`n"

    $breaking = $Commits | Where-Object {
        $_ -match '^[a-zA-Z]+(\([^)]*\))?!:' -or $_ -match 'BREAKING CHANGE:'
    }
    $features = $Commits | Where-Object {
        $_ -match '^feat(\([^)]*\))?:' -and $_ -notmatch '^[a-zA-Z]+(\([^)]*\))?!:'
    }
    $fixes = $Commits | Where-Object {
        $_ -match '^fix(\([^)]*\))?:' -and $_ -notmatch '^[a-zA-Z]+(\([^)]*\))?!:'
    }

    if ($breaking) {
        $entry += "### Breaking Changes`n"
        foreach ($c in $breaking) { $entry += "- $c`n" }
        $entry += "`n"
    }
    if ($features) {
        $entry += "### Features`n"
        foreach ($c in $features) { $entry += "- $c`n" }
        $entry += "`n"
    }
    if ($fixes) {
        $entry += "### Bug Fixes`n"
        foreach ($c in $fixes) { $entry += "- $c`n" }
        $entry += "`n"
    }

    return $entry
}

# ---------------------------------------------------------------------------
# Main execution (skipped when dot-sourced by tests)
# ---------------------------------------------------------------------------

# Guard: only run main body when executed as a script, not dot-sourced
if ($MyInvocation.InvocationName -ne '.') {

    # Validate version file exists
    if (-not (Test-Path $VersionFile)) {
        throw "Version file not found: '$VersionFile'"
    }

    # Read current version from JSON file (supports both version.json and package.json)
    $versionData = Get-Content $VersionFile -Raw | ConvertFrom-Json
    if (-not $versionData.version) {
        throw "No 'version' field found in '$VersionFile'"
    }
    $currentVersion = $versionData.version

    # Read commit messages (one per line); missing file -> empty list
    $commits = @()
    if (Test-Path $CommitsFile) {
        $commits = Get-Content $CommitsFile | Where-Object { $_.Trim() -ne "" }
    }

    # Determine bump type and compute new version
    $bumpType   = Get-BumpType -Commits $commits
    $newVersion = Get-NewVersion -CurrentVersion $currentVersion -BumpType $bumpType

    # Update the version file unless dry-run
    if (-not $DryRun) {
        $versionData.version = $newVersion
        $versionData | ConvertTo-Json -Depth 10 | Set-Content $VersionFile -Encoding UTF8
    }

    # Generate and write changelog entry unless dry-run and no new version
    if (-not $DryRun) {
        $entry = Get-ChangelogEntry -NewVersion $newVersion -Commits $commits

        if (Test-Path $ChangelogFile) {
            $existing = Get-Content $ChangelogFile -Raw
            Set-Content $ChangelogFile -Value ($entry + $existing) -Encoding UTF8
        } else {
            Set-Content $ChangelogFile -Value $entry -Encoding UTF8
        }
    }

    # Always output the new version so callers (CI steps, tests) can parse it.
    # Write-Output sends to pipeline (captured by callers); also visible in GHA logs.
    Write-Output "NEW_VERSION=$newVersion"
    Write-Output "BUMP_TYPE=$bumpType"
    Write-Output "PREVIOUS_VERSION=$currentVersion"
}
