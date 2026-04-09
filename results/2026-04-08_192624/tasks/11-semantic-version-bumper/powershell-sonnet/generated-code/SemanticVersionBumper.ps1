# SemanticVersionBumper.ps1
# Semantic version bumper using conventional commit messages
# Conventional commits spec: https://www.conventionalcommits.org/

# Helper: create a temporary directory
function New-TemporaryDirectory {
    $tmpPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $tmpPath | Out-Null
    return $tmpPath
}

<#
.SYNOPSIS
    Determines the semver bump type from a list of commit messages.
.PARAMETER Commits
    Array of commit message strings following conventional commits format.
.OUTPUTS
    String: 'major', 'minor', 'patch', or 'none'
#>
function Get-BumpType {
    param(
        [string[]]$Commits
    )

    $bumpType = "none"

    foreach ($commit in $Commits) {
        # Breaking change: feat! or fix! or any type with ! before colon
        if ($commit -match '^[a-z]+(\([^)]+\))?!:' -or $commit -match 'BREAKING CHANGE:') {
            return "major"
        }

        # Feature: feat: prefix -> minor bump
        if ($commit -match '^feat(\([^)]+\))?:') {
            if ($bumpType -ne "major") {
                $bumpType = "minor"
            }
        }

        # Fix: fix: prefix -> patch bump
        if ($commit -match '^fix(\([^)]+\))?:') {
            if ($bumpType -eq "none") {
                $bumpType = "patch"
            }
        }
    }

    return $bumpType
}

<#
.SYNOPSIS
    Computes the next semantic version given current version and bump type.
.PARAMETER CurrentVersion
    Semantic version string like "1.2.3"
.PARAMETER BumpType
    One of: 'major', 'minor', 'patch', 'none'
.OUTPUTS
    String: new version like "1.3.0"
#>
function Get-NextVersion {
    param(
        [string]$CurrentVersion,
        [string]$BumpType
    )

    # Parse the version string
    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version format: '$CurrentVersion'. Expected format: MAJOR.MINOR.PATCH"
    }

    [int]$major = $Matches[1]
    [int]$minor = $Matches[2]
    [int]$patch = $Matches[3]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
        "none"  { return $CurrentVersion }
        default { throw "Unknown bump type: '$BumpType'" }
    }
}

<#
.SYNOPSIS
    Reads the current version from a file (version.txt or package.json).
.PARAMETER FilePath
    Path to the version file.
.OUTPUTS
    String: the current version
#>
function Read-VersionFromFile {
    param(
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: '$FilePath'"
    }

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    if ($extension -eq ".json") {
        # Parse as package.json and extract version field
        try {
            $pkg = Get-Content -Raw $FilePath | ConvertFrom-Json
            if ($null -eq $pkg.version) {
                throw "No 'version' field found in JSON file: '$FilePath'"
            }
            return $pkg.version.Trim()
        } catch {
            throw "Failed to parse JSON version file '$FilePath': $_"
        }
    } else {
        # Plain text file: read first line and trim whitespace
        $content = (Get-Content $FilePath -First 1).Trim()
        if ([string]::IsNullOrWhiteSpace($content)) {
            throw "Version file '$FilePath' is empty"
        }
        return $content
    }
}

<#
.SYNOPSIS
    Writes a new version to a file (version.txt or package.json).
.PARAMETER FilePath
    Path to the version file.
.PARAMETER NewVersion
    The new version string to write.
#>
function Write-VersionToFile {
    param(
        [string]$FilePath,
        [string]$NewVersion
    )

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    if ($extension -eq ".json") {
        $pkg = Get-Content -Raw $FilePath | ConvertFrom-Json
        $pkg.version = $NewVersion
        $pkg | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath
    } else {
        Set-Content -Path $FilePath -Value $NewVersion
    }
}

<#
.SYNOPSIS
    Generates a changelog entry for a new version release.
.PARAMETER Version
    The new version string.
.PARAMETER Commits
    Array of commit messages for this release.
.PARAMETER Date
    Release date string (defaults to today).
.OUTPUTS
    String: formatted changelog section
#>
function New-ChangelogEntry {
    param(
        [string]$Version,
        [string[]]$Commits,
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    # Group commits by type
    $features = @()
    $bugFixes = @()
    $breaking = @()
    $other = @()

    foreach ($commit in $Commits) {
        if ($commit -match '^[a-z]+(\([^)]+\))?!:' -or $commit -match 'BREAKING CHANGE:') {
            $breaking += "- $commit"
        } elseif ($commit -match '^feat(\([^)]+\))?:\s*(.+)') {
            $features += "- $($Matches[2])"
        } elseif ($commit -match '^fix(\([^)]+\))?:\s*(.+)') {
            $bugFixes += "- $($Matches[2])"
        } else {
            $other += "- $commit"
        }
    }

    $lines = @("## [$Version] - $Date", "")

    if ($breaking.Count -gt 0) {
        $lines += "### Breaking Changes"
        $lines += $breaking
        $lines += ""
    }

    if ($features.Count -gt 0) {
        $lines += "### Features"
        $lines += $features
        $lines += ""
    }

    if ($bugFixes.Count -gt 0) {
        $lines += "### Bug Fixes"
        $lines += $bugFixes
        $lines += ""
    }

    return $lines -join "`n"
}

<#
.SYNOPSIS
    Main entry point: reads version, determines bump, updates file, generates changelog.
.PARAMETER VersionFile
    Path to version.txt or package.json.
.PARAMETER Commits
    Array of commit messages (conventional commits format).
.OUTPUTS
    Hashtable with keys: OldVersion, NewVersion, BumpType, ChangelogEntry
#>
function Invoke-SemanticVersionBump {
    param(
        [string]$VersionFile,
        [string[]]$Commits
    )

    $oldVersion = Read-VersionFromFile -FilePath $VersionFile
    $bumpType = Get-BumpType -Commits $Commits
    $newVersion = Get-NextVersion -CurrentVersion $oldVersion -BumpType $bumpType

    # Update file only if version actually changed
    if ($newVersion -ne $oldVersion) {
        Write-VersionToFile -FilePath $VersionFile -NewVersion $newVersion
    }

    $changelogEntry = New-ChangelogEntry -Version $newVersion -Commits $Commits

    return @{
        OldVersion     = $oldVersion
        NewVersion     = $newVersion
        BumpType       = $bumpType
        ChangelogEntry = $changelogEntry
    }
}

# Script entry point: this block runs only when the script is invoked directly.
# When dot-sourced (. ./SemanticVersionBumper.ps1), $MyInvocation.CommandOrigin
# is 'Runspace' rather than 'Internal', and we skip execution.
# We detect direct invocation by checking PSCommandPath matches InvocationName.
$_isDirectRun = ($MyInvocation.PSCommandPath -and
                 ($MyInvocation.InvocationName -eq $MyInvocation.PSCommandPath -or
                  $MyInvocation.InvocationName -like "*SemanticVersionBumper*")) -and
                ($MyInvocation.CommandOrigin -eq 'Runspace')

if ($_isDirectRun) {
    $VersionFile = if ($args -contains "-VersionFile") {
        $args[$args.IndexOf("-VersionFile") + 1]
    } else { "version.txt" }

    $CommitFile = if ($args -contains "-CommitFile") {
        $args[$args.IndexOf("-CommitFile") + 1]
    } else { "" }

    $Commits = @()
    if ($CommitFile -and (Test-Path $CommitFile)) {
        $Commits = Get-Content $CommitFile
    }

    if ($Commits.Count -eq 0) {
        Write-Error "No commits provided. Use -CommitFile parameter."
        exit 1
    }

    $result = Invoke-SemanticVersionBump -VersionFile $VersionFile -Commits $Commits
    Write-Output "OLD_VERSION=$($result.OldVersion)"
    Write-Output "NEW_VERSION=$($result.NewVersion)"
    Write-Output "BUMP_TYPE=$($result.BumpType)"
    Write-Output ""
    Write-Output $result.ChangelogEntry
}
