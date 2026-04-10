# VersionBumper.ps1
# Semantic version bumper using conventional commits
# Determines next version based on: feat->minor, fix->patch, breaking->major

<#
.SYNOPSIS
    Reads the current version from a file (version.txt or package.json).
.PARAMETER Path
    Path to version.txt or package.json
.OUTPUTS
    String version number (e.g. "1.2.3")
#>
function Get-CurrentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    $content = (Get-Content -Path $Path -Raw).Trim()

    # Detect JSON by extension or content
    $extension = [System.IO.Path]::GetExtension($Path)
    $isJson = ($extension -eq ".json") -or ($content -match '^\s*\{')

    if ($isJson) {
        $json = $content | ConvertFrom-Json
        if (-not $json.version) {
            throw "No 'version' field found in $Path"
        }
        return $json.version
    }
    else {
        # Plain text version file
        return $content
    }
}

<#
.SYNOPSIS
    Determines the version bump type from a list of conventional commit messages.
    Returns 'major', 'minor', or 'patch'.
.PARAMETER Commits
    Array of commit message strings
#>
function Get-CommitBumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )

    $bumpType = "patch"  # default

    foreach ($commit in $Commits) {
        # Check for breaking change: exclamation mark or BREAKING CHANGE footer
        if ($commit -match "^(\w+)(\(.+\))?!:" -or $commit -match "BREAKING CHANGE:") {
            return "major"
        }
        # feat commits trigger minor bump
        if ($commit -match "^feat(\(.+\))?:" -and $bumpType -ne "major") {
            $bumpType = "minor"
        }
    }

    return $bumpType
}

<#
.SYNOPSIS
    Calculates the next semantic version given the current version and bump type.
.PARAMETER CurrentVersion
    Current version string (e.g. "1.2.3")
.PARAMETER BumpType
    One of 'major', 'minor', 'patch'
#>
function Get-NextVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CurrentVersion,

        [Parameter(Mandatory)]
        [ValidateSet("major", "minor", "patch")]
        [string]$BumpType
    )

    # Parse semver - require exactly 3 numeric parts
    if ($CurrentVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: '$CurrentVersion'. Expected format: MAJOR.MINOR.PATCH"
    }

    $parts = $CurrentVersion -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
    }
}

<#
.SYNOPSIS
    Generates a Keep-a-Changelog formatted entry for the new version.
.PARAMETER Version
    New version string
.PARAMETER Commits
    Array of conventional commit messages
.PARAMETER Date
    Date string (YYYY-MM-DD), defaults to today
#>
function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits,

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $breaking = @()
    $features = @()
    $fixes = @()
    $others = @()

    foreach ($commit in $Commits) {
        # Extract commit description (part after the type prefix)
        if ($commit -match "^(\w+)(\(.+\))?!:\s*(.+)") {
            $breaking += $Matches[3]
        }
        elseif ($commit -match "^feat(\(.+\))?:\s*(.+)") {
            $features += $Matches[2]
        }
        elseif ($commit -match "^fix(\(.+\))?:\s*(.+)") {
            $fixes += $Matches[2]
        }
        else {
            # Non-conventional commit - include as-is
            if ($commit.Trim()) {
                $others += $commit.Trim()
            }
        }

        # Check for BREAKING CHANGE in body (multi-line commit message)
        if ($commit -match "BREAKING CHANGE:\s*(.+)") {
            $breaking += $Matches[1]
        }
    }

    $lines = @("## [$Version] - $Date", "")

    if ($breaking.Count -gt 0) {
        $lines += "### Breaking Changes"
        $lines += ""
        foreach ($item in $breaking) { $lines += "- $item" }
        $lines += ""
    }

    if ($features.Count -gt 0) {
        $lines += "### Features"
        $lines += ""
        foreach ($item in $features) { $lines += "- $item" }
        $lines += ""
    }

    if ($fixes.Count -gt 0) {
        $lines += "### Bug Fixes"
        $lines += ""
        foreach ($item in $fixes) { $lines += "- $item" }
        $lines += ""
    }

    if ($others.Count -gt 0) {
        $lines += "### Other"
        $lines += ""
        foreach ($item in $others) { $lines += "- $item" }
        $lines += ""
    }

    return $lines -join "`n"
}

<#
.SYNOPSIS
    Updates a version file (version.txt or package.json) with the new version.
.PARAMETER Path
    Path to the version file
.PARAMETER NewVersion
    New version string to write
#>
function Update-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    $content = (Get-Content -Path $Path -Raw).Trim()
    $extension = [System.IO.Path]::GetExtension($Path)
    $isJson = ($extension -eq ".json") -or ($content -match '^\s*\{')

    if ($isJson) {
        $json = $content | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
    }
    else {
        Set-Content -Path $Path -Value $NewVersion
    }
}

<#
.SYNOPSIS
    Updates or creates CHANGELOG.md by prepending a new entry.
.PARAMETER Path
    Path to CHANGELOG.md
.PARAMETER Entry
    Formatted changelog entry string
#>
function Update-Changelog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Entry
    )

    if (Test-Path $Path) {
        $existing = Get-Content -Path $Path -Raw
        # Insert new entry after the first header line if present
        if ($existing -match "^# Changelog") {
            $headerEnd = $existing.IndexOf("`n") + 1
            $header = $existing.Substring(0, $headerEnd)
            $rest = $existing.Substring($headerEnd).TrimStart()
            $newContent = "$header`n$Entry`n$rest"
        }
        else {
            $newContent = "$Entry`n$existing"
        }
        Set-Content -Path $Path -Value $newContent -NoNewline
    }
    else {
        $newContent = "# Changelog`n`nAll notable changes to this project will be documented here.`n`n$Entry"
        Set-Content -Path $Path -Value $newContent
    }
}

<#
.SYNOPSIS
    Main orchestration function: reads version, determines bump, updates files.
    Returns the new version string.
.PARAMETER VersionFilePath
    Path to version.txt or package.json
.PARAMETER ChangelogPath
    Path to CHANGELOG.md
.PARAMETER Commits
    Array of conventional commit messages
.PARAMETER Date
    Date for changelog entry (defaults to today)
#>
function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFilePath,

        [Parameter(Mandatory)]
        [string]$ChangelogPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Commits,

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $currentVersion = Get-CurrentVersion -Path $VersionFilePath
    $bumpType = Get-CommitBumpType -Commits $Commits
    $newVersion = Get-NextVersion -CurrentVersion $currentVersion -BumpType $bumpType
    $entry = New-ChangelogEntry -Version $newVersion -Commits $Commits -Date $Date

    Update-VersionFile -Path $VersionFilePath -NewVersion $newVersion
    Update-Changelog -Path $ChangelogPath -Entry $entry

    return $newVersion
}
