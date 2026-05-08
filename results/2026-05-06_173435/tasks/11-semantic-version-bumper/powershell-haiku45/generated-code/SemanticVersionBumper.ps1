# SemanticVersionBumper.ps1
# Semantic version bumping with conventional commits support

<#
.SYNOPSIS
Parses the current version from a version file (package.json or version.txt).

.PARAMETER Path
Path to the version file (package.json or version.txt)
#>
function Get-CurrentVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    if ($Path -like "*.json") {
        # Parse package.json
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $content.version
    }
    else {
        # Parse version.txt
        return (Get-Content -Path $Path).Trim()
    }
}

<#
.SYNOPSIS
Compares two semantic versions.

.PARAMETER Version1
First version to compare
.PARAMETER Version2
Second version to compare

.OUTPUTS
Returns 1 if Version1 > Version2, 0 if equal, -1 if Version1 < Version2
#>
function Compare-Versions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version1,
        [Parameter(Mandatory = $true)]
        [string]$Version2
    )

    $v1 = [System.Version]$Version1
    $v2 = [System.Version]$Version2

    if ($v1 -gt $v2) { return 1 }
    if ($v1 -lt $v2) { return -1 }
    return 0
}

<#
.SYNOPSIS
Determines the bump type (major, minor, patch) based on conventional commit messages.

.PARAMETER Commits
Array of commit objects with 'message' property

.OUTPUTS
Returns "major", "minor", or "patch"
#>
function Get-BumpType {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Commits = @()
    )

    $hasBreaking = $false
    $hasFeature = $false
    $hasFix = $false

    # Handle empty or null commits array
    if ($null -eq $Commits -or $Commits.Count -eq 0) {
        return "patch"
    }

    foreach ($commit in $Commits) {
        $message = $commit.message

        # Check for breaking change (feat!: or BREAKING CHANGE:)
        if ($message -match "^(feat|fix|refactor|perf)!:|BREAKING CHANGE:" -or $message -match "BREAKING CHANGE:") {
            $hasBreaking = $true
        }

        # Check for feature
        if ($message -match "^feat:") {
            $hasFeature = $true
        }

        # Check for fix
        if ($message -match "^fix:") {
            $hasFix = $true
        }
    }

    if ($hasBreaking) { return "major" }
    if ($hasFeature) { return "minor" }
    if ($hasFix) { return "patch" }

    return "patch"  # Default to patch if no conventional commits found
}

<#
.SYNOPSIS
Bumps a semantic version based on the bump type.

.PARAMETER Version
Current version
.PARAMETER BumpType
Type of bump: "major", "minor", or "patch"

.OUTPUTS
Returns the new version string
#>
function Bump-Version {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [ValidateSet("major", "minor", "patch")]
        [string]$BumpType
    )

    $v = [System.Version]$Version
    $major = $v.Major
    $minor = $v.Minor
    $patch = $v.Build

    switch ($BumpType) {
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
    }

    return "$major.$minor.$patch"
}

<#
.SYNOPSIS
Updates the version in a version file.

.PARAMETER Path
Path to the version file (package.json or version.txt)
.PARAMETER NewVersion
The new version string
#>
function Update-VersionFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$NewVersion
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    if ($Path -like "*.json") {
        # Update package.json
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $content.version = $NewVersion
        $content | ConvertTo-Json | Set-Content -Path $Path -Force
    }
    else {
        # Update version.txt
        Set-Content -Path $Path -Value $NewVersion -Force
    }
}

<#
.SYNOPSIS
Generates a changelog entry from commits.

.PARAMETER Version
The version being released
.PARAMETER Commits
Array of commit objects with 'message' property

.OUTPUTS
Returns formatted changelog text
#>
function Generate-ChangelogEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $false)]
        [array]$Commits = @()
    )

    $changelog = @()
    $changelog += "## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')"
    $changelog += ""

    $features = @()
    $fixes = @()
    $breaking = @()

    foreach ($commit in $Commits) {
        $message = $commit.message
        $hash = if ($commit.hash) { $commit.hash.Substring(0, [Math]::Min(7, $commit.hash.Length)) } else { "unknown" }

        if ($message -match "^feat!:|BREAKING CHANGE:") {
            $breaking += "- $($message -replace '^feat!:\s*', '') ($hash)"
        }
        elseif ($message -match "^feat:") {
            $features += "- $($message -replace '^feat:\s*', '') ($hash)"
        }
        elseif ($message -match "^fix:") {
            $fixes += "- $($message -replace '^fix:\s*', '') ($hash)"
        }
    }

    if ($breaking.Count -gt 0) {
        $changelog += "### Breaking Changes"
        $changelog += $breaking
        $changelog += ""
    }

    if ($features.Count -gt 0) {
        $changelog += "### Features"
        $changelog += $features
        $changelog += ""
    }

    if ($fixes.Count -gt 0) {
        $changelog += "### Bug Fixes"
        $changelog += $fixes
        $changelog += ""
    }

    return $changelog -join "`n"
}

<#
.SYNOPSIS
Main orchestration function for semantic version bumping.

.PARAMETER ProjectPath
Path to the project directory
.PARAMETER CommitsFile
Optional path to a JSON file containing commit messages (for testing)

.OUTPUTS
Returns an object with NewVersion, BumpType, and Changelog properties
#>
function Invoke-SemanticVersionBumper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $false)]
        [string]$CommitsFile
    )

    # Find version file
    $packageJsonPath = Join-Path $ProjectPath "package.json"
    $versionTxtPath = Join-Path $ProjectPath "version.txt"

    $versionPath = $null
    if (Test-Path $packageJsonPath) {
        $versionPath = $packageJsonPath
    }
    elseif (Test-Path $versionTxtPath) {
        $versionPath = $versionTxtPath
    }
    else {
        throw "No package.json or version.txt found in $ProjectPath"
    }

    # Get current version
    $currentVersion = Get-CurrentVersion -Path $versionPath

    # Get commits
    if ($CommitsFile -and (Test-Path $CommitsFile)) {
        # Use commits from file (for testing)
        $commitsData = Get-Content -Path $CommitsFile -Raw | ConvertFrom-Json
        # Ensure commits is always an array, even if empty
        if ($null -eq $commitsData) {
            $commits = @()
        }
        elseif ($commitsData -is [array]) {
            $commits = $commitsData
        }
        else {
            $commits = @($commitsData)
        }
    }
    else {
        # TODO: Get commits from git history in real usage
        $commits = @()
    }

    # Determine bump type
    $bumpType = Get-BumpType -Commits $commits

    # Only bump version if there are actual commits
    if ($commits.Count -eq 0) {
        $newVersion = $currentVersion
    }
    else {
        $newVersion = Bump-Version -Version $currentVersion -BumpType $bumpType
    }

    # Generate changelog
    $changelog = Generate-ChangelogEntry -Version $newVersion -Commits $commits

    # Update version file
    Update-VersionFile -Path $versionPath -NewVersion $newVersion

    return @{
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}

