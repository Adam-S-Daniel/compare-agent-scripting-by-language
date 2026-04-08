# SemanticVersionBumper.psm1
# Module for parsing semantic versions, analyzing conventional commits,
# bumping versions, and generating changelogs.
# Built using TDD - each function was test-driven.

function Read-Version {
    <#
    .SYNOPSIS
        Parses a semantic version string from a version.txt or package.json file.
    .DESCRIPTION
        Reads the given file, extracts a semver (Major.Minor.Patch), and returns
        a PSCustomObject with Major, Minor, Patch integer properties.
        Supports plain text files and package.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file '$Path' does not exist."
    }

    $content = Get-Content -LiteralPath $Path -Raw

    # Determine file type and extract version string
    if ($Path -match '\.json$') {
        # Parse JSON and extract the "version" field
        $json = $content | ConvertFrom-Json
        $versionString = $json.version
    } else {
        # Plain text - the whole content is the version (trimmed)
        $versionString = $content.Trim()
    }

    # Parse semver pattern: Major.Minor.Patch
    if ($versionString -match '^(\d+)\.(\d+)\.(\d+)$') {
        return [PSCustomObject]@{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
        }
    }

    throw "Could not parse semantic version from '$Path'. Content: '$versionString'"
}

function Get-BumpType {
    <#
    .SYNOPSIS
        Analyzes conventional commit messages to determine the version bump type.
    .DESCRIPTION
        Scans commit messages for conventional commit prefixes:
        - "feat!:" or "fix!:" or "BREAKING CHANGE" -> major
        - "feat:" -> minor
        - "fix:" -> patch
        Returns the highest-priority bump type found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CommitMessages
    )

    $hasMajor = $false
    $hasMinor = $false
    $hasPatch = $false

    foreach ($msg in $CommitMessages) {
        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        # Strip leading short-sha prefix (e.g. "abc1234 feat: ...")
        $cleaned = $msg -replace '^\s*[a-zA-Z0-9]+\s+', ''

        # Check for breaking changes: "type!:" suffix or "BREAKING CHANGE" anywhere
        if ($cleaned -match '^\w+!:' -or $cleaned -match 'BREAKING CHANGE') {
            $hasMajor = $true
        }
        # Check for feat (minor bump)
        elseif ($cleaned -match '^feat(\(.+\))?:') {
            $hasMinor = $true
        }
        # Check for fix (patch bump)
        elseif ($cleaned -match '^fix(\(.+\))?:') {
            $hasPatch = $true
        }
    }

    # Return highest priority bump type
    if ($hasMajor) { return 'major' }
    if ($hasMinor) { return 'minor' }
    if ($hasPatch) { return 'patch' }
    return 'none'
}

function Get-NextVersion {
    <#
    .SYNOPSIS
        Computes the next semantic version given the current version and bump type.
    .DESCRIPTION
        Applies semver rules: major resets minor+patch, minor resets patch.
        Returns the new version as a string "Major.Minor.Patch".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Version,

        [Parameter(Mandatory)]
        [string]$BumpType
    )

    switch ($BumpType) {
        'major' { return "$([int]$Version.Major + 1).0.0" }
        'minor' { return "$($Version.Major).$([int]$Version.Minor + 1).0" }
        'patch' { return "$($Version.Major).$($Version.Minor).$([int]$Version.Patch + 1)" }
        'none'  { return "$($Version.Major).$($Version.Minor).$($Version.Patch)" }
        default { throw "Invalid bump type '$BumpType'. Expected: major, minor, patch, or none." }
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Generates a markdown changelog entry from conventional commit messages.
    .DESCRIPTION
        Groups commits by type (breaking, features, fixes) and formats them
        as a markdown section under the given version heading.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CommitMessages,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $breaking = @()
    $features = @()
    $fixes = @()

    foreach ($msg in $CommitMessages) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        # Strip sha prefix
        $cleaned = $msg -replace '^\s*[a-zA-Z0-9]+\s+', ''

        if ($cleaned -match '^\w+!:\s*(.+)' -or $cleaned -match 'BREAKING CHANGE:\s*(.+)') {
            # For breaking with !, extract description after the colon
            $desc = $cleaned -replace '^\w+!:\s*', ''
            if ($cleaned -match 'BREAKING CHANGE') {
                $desc = $cleaned -replace '^.*?:\s*', ''
            }
            $breaking += $desc
        }
        elseif ($cleaned -match '^feat(\(.+?\))?:\s*(.+)') {
            $features += $Matches[2]
        }
        elseif ($cleaned -match '^fix(\(.+?\))?:\s*(.+)') {
            $fixes += $Matches[2]
        }
    }

    $lines = @()
    $lines += "## $Version"
    $lines += ""

    $hasContent = $false

    if ($breaking.Count -gt 0) {
        $hasContent = $true
        $lines += "### BREAKING CHANGES"
        foreach ($b in $breaking) { $lines += "- $b" }
        $lines += ""
    }

    if ($features.Count -gt 0) {
        $hasContent = $true
        $lines += "### Features"
        foreach ($f in $features) { $lines += "- $f" }
        $lines += ""
    }

    if ($fixes.Count -gt 0) {
        $hasContent = $true
        $lines += "### Bug Fixes"
        foreach ($x in $fixes) { $lines += "- $x" }
        $lines += ""
    }

    if (-not $hasContent) {
        $lines += "No notable changes."
        $lines += ""
    }

    return ($lines -join "`n")
}

function Write-Version {
    <#
    .SYNOPSIS
        Updates the version string in a version.txt or package.json file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file '$Path' does not exist."
    }

    if ($Path -match '\.json$') {
        # Update the "version" field in JSON while preserving other fields
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -NoNewline
    } else {
        # Plain text: just write the version string
        Set-Content -LiteralPath $Path -Value $NewVersion -NoNewline
    }
}

Export-ModuleMember -Function Read-Version, Get-BumpType, Get-NextVersion, New-ChangelogEntry, Write-Version
