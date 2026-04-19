# Semantic Version Bumper
# Parses version files, determines next version from conventional commits,
# updates files, and generates changelog entries.

<#
.SYNOPSIS
Gets the current version from a version file (package.json or VERSION).

.PARAMETER Path
Path to the version file (package.json or VERSION).

.OUTPUTS
String containing the semantic version.
#>
function Get-VersionFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    $filename = Split-Path -Leaf $Path

    if ($filename -eq "package.json") {
        $packageJson = Get-Content -Path $Path | ConvertFrom-Json
        return $packageJson.version
    }
    elseif ($filename -eq "VERSION") {
        return (Get-Content -Path $Path).Trim()
    }
    else {
        throw "Unsupported file type. Expected package.json or VERSION file."
    }
}

<#
.SYNOPSIS
Parses a conventional commit message and extracts type, scope, and breaking status.

.PARAMETER Message
The commit message to parse.

.OUTPUTS
PSObject with type, scope, message, and isBreaking properties.
#>
function Parse-ConventionalCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    # Pattern: type(scope)?: message or type!: message or type(scope)!: message
    $pattern = '^(?<type>\w+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?:\s*(?<msg>.+)$'

    $firstLine = ($Message -split "`n")[0]

    if ($firstLine -match $pattern) {
        $type = $matches['type']
        $scope = $matches['scope']
        $msg = $matches['msg']
        $hasBreakingMark = $matches['breaking'] -eq '!'

        # Check for BREAKING CHANGE in body
        $hasBreakingBody = $Message -match 'BREAKING\s*CHANGE\s*:'
        $isBreaking = $hasBreakingMark -or $hasBreakingBody

        return [PSCustomObject]@{
            type       = $type
            scope      = $scope
            message    = $msg
            isBreaking = $isBreaking
        }
    }
    else {
        # If it doesn't match conventional commit format, treat as chore
        return [PSCustomObject]@{
            type       = "chore"
            scope      = $null
            message    = $firstLine
            isBreaking = $false
        }
    }
}

<#
.SYNOPSIS
Determines the next semantic version based on commits.

.PARAMETER CurrentVersion
The current version (e.g., "1.2.3").

.PARAMETER Commits
Array of commit objects with type and isBreaking properties.

.OUTPUTS
String containing the next semantic version.
#>
function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,

        [Parameter(Mandatory = $true)]
        [array]$Commits
    )

    # Parse current version
    if ($CurrentVersion -match '^(\d+)\.(\d+)\.(\d+)') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
    }
    else {
        throw "Invalid semantic version: $CurrentVersion"
    }

    # Determine bump type: major, minor, or patch
    $bumpType = "none"

    foreach ($commit in $Commits) {
        if ($commit.isBreaking -eq $true) {
            $bumpType = "major"
            break
        }
        elseif ($commit.type -eq "feat" -and $bumpType -ne "major") {
            $bumpType = "minor"
        }
        elseif ($commit.type -eq "fix" -and $bumpType -eq "none") {
            $bumpType = "patch"
        }
    }

    # Calculate next version
    switch ($bumpType) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        "minor" {
            $minor++
            $patch = 0
        }
        "patch" {
            $patch++
        }
        default {
            # No change
        }
    }

    return "$major.$minor.$patch"
}

<#
.SYNOPSIS
Generates a changelog entry for a version.

.PARAMETER Version
The version number.

.PARAMETER Commits
Array of commit objects to include in changelog.

.OUTPUTS
String containing formatted changelog entry.
#>
function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [array]$Commits
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $changelog = "## [$Version] - $date`n"

    # Group commits by type
    $features = $Commits | Where-Object { $_.type -eq "feat" }
    $fixes = $Commits | Where-Object { $_.type -eq "fix" }
    $breaking = $Commits | Where-Object { $_.isBreaking -eq $true }

    # Add breaking changes section
    if ($breaking) {
        $changelog += "`n### Breaking Changes`n`n"
        foreach ($commit in $breaking) {
            $scope = if ($commit.scope) { "**$($commit.scope)**: " } else { "" }
            $changelog += "- $scope$($commit.message)`n"
        }
    }

    # Add features section
    if ($features) {
        $changelog += "`n### Features`n`n"
        foreach ($commit in $features) {
            $scope = if ($commit.scope) { "**$($commit.scope)**: " } else { "" }
            $changelog += "- $scope$($commit.message)`n"
        }
    }

    # Add fixes section
    if ($fixes) {
        $changelog += "`n### Bug Fixes`n`n"
        foreach ($commit in $fixes) {
            $scope = if ($commit.scope) { "**$($commit.scope)**: " } else { "" }
            $changelog += "- $scope$($commit.message)`n"
        }
    }

    return $changelog
}

<#
.SYNOPSIS
Updates the version in a file (package.json or VERSION).

.PARAMETER Path
Path to the version file.

.PARAMETER NewVersion
The new version to set.
#>
function Update-VersionInFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    $filename = Split-Path -Leaf $Path

    if ($filename -eq "package.json") {
        $packageJson = Get-Content -Path $Path | ConvertFrom-Json
        $packageJson.version = $NewVersion
        $packageJson | ConvertTo-Json | Set-Content -Path $Path
    }
    elseif ($filename -eq "VERSION") {
        Set-Content -Path $Path -Value $NewVersion
    }
    else {
        throw "Unsupported file type: $filename"
    }
}

<#
.SYNOPSIS
Main function: executes the complete semantic version bumping workflow.

.PARAMETER PackagePath
Path to the version file (package.json or VERSION).

.PARAMETER Commits
Array of commit objects (or convert from message strings).

.PARAMETER UpdateFile
Whether to update the version file (default: $true).

.OUTPUTS
PSObject with oldVersion, newVersion, and changelog properties.
#>
function Invoke-SemanticVersionBumper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [array]$Commits,

        [switch]$UpdateFile = $true
    )

    # Get current version
    $currentVersion = Get-VersionFromFile -Path $PackagePath

    # Parse commits if they're strings
    $parsedCommits = @()
    foreach ($commit in $Commits) {
        if ($commit -is [string]) {
            $parsedCommits += Parse-ConventionalCommit -Message $commit
        }
        else {
            $parsedCommits += $commit
        }
    }

    # Determine next version
    $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $parsedCommits

    # Generate changelog
    $changelog = New-ChangelogEntry -Version $nextVersion -Commits $parsedCommits

    # Update file if requested
    if ($UpdateFile -and $nextVersion -ne $currentVersion) {
        Update-VersionInFile -Path $PackagePath -NewVersion $nextVersion
    }

    return [PSCustomObject]@{
        oldVersion = $currentVersion
        newVersion = $nextVersion
        changelog  = $changelog
    }
}
