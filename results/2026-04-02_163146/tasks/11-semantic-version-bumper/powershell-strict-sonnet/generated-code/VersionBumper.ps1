# VersionBumper.ps1
# Semantic version bumper: parse a version file, determine the next version
# from conventional commits, update the file, and generate a changelog entry.
#
# TDD GREEN phase: this file was written after VersionBumper.Tests.ps1 already
# existed and was failing, in order to make every test pass.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Semver validation pattern (major.minor.patch, no pre-release/build metadata)
[string]$script:SEMVER_PATTERN = '^\d+\.\d+\.\d+$'

# ---------------------------------------------------------------------------
# Get-SemanticVersion
# Parse the version string from a package.json or plain-text version file.
# ---------------------------------------------------------------------------
function Get-SemanticVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "Version file not found: '$FilePath'"
    }

    [string]$extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    [string]$version   = ''

    if ($extension -eq '.json') {
        # Parse JSON and extract the "version" property
        [string]$raw = Get-Content -LiteralPath $FilePath -Raw
        $json = $raw | ConvertFrom-Json

        # In strict mode, accessing a missing property still returns $null —
        # check explicitly to give a meaningful error.
        if ($null -eq $json.version) {
            throw "No 'version' field found in JSON file: '$FilePath'"
        }
        $version = [string]$json.version
    }
    else {
        # Plain-text: read only the first line (e.g. version.txt contains "1.2.3")
        [string]$firstLine = (Get-Content -LiteralPath $FilePath -First 1)
        if ([string]::IsNullOrWhiteSpace($firstLine)) {
            throw "Version file is empty or blank: '$FilePath'"
        }
        $version = $firstLine.Trim()
    }

    # Validate the extracted string is a valid semver (MAJOR.MINOR.PATCH)
    if ($version -notmatch $script:SEMVER_PATTERN) {
        throw "Invalid semantic version '$version' in file: '$FilePath'. Expected MAJOR.MINOR.PATCH format."
    }

    return $version
}

# ---------------------------------------------------------------------------
# Get-BumpType
# Analyse conventional commit messages and return 'major', 'minor', or 'patch'.
#
# Rules (highest priority wins):
#   BREAKING CHANGE: footer  OR  <type>!: subject  -> major
#   feat: / feat(<scope>):                          -> minor
#   anything else                                   -> patch
# ---------------------------------------------------------------------------
function Get-BumpType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string[]]$CommitMessages
    )

    # Start at the lowest bump level; escalate as we find higher-priority commits.
    [string]$bumpType = 'patch'

    foreach ($commit in $CommitMessages) {
        # Breaking-change indicator: BREAKING CHANGE: footer, or any type with !
        if ($commit -match 'BREAKING CHANGE:' -or $commit -match '^[a-z]+(\(.+\))?!:') {
            # Early-exit: nothing can override major
            return 'major'
        }

        if ($commit -match '^feat(\(.+\))?:') {
            $bumpType = 'minor'
        }
        # fix, chore, docs, style, refactor, test, perf, build, ci -> patch (default)
    }

    return $bumpType
}

# ---------------------------------------------------------------------------
# Get-NextVersion
# Given a semver string and a bump type, return the next version string.
# ---------------------------------------------------------------------------
function Get-NextVersion {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$CurrentVersion,

        [Parameter(Mandatory)]
        [string]$BumpType
    )

    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: '$CurrentVersion'. Expected MAJOR.MINOR.PATCH."
    }

    [int]$major = [int]$Matches[1]
    [int]$minor = [int]$Matches[2]
    [int]$patch = [int]$Matches[3]

    switch ($BumpType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
        default {
            throw "Invalid bump type: '$BumpType'. Must be 'major', 'minor', or 'patch'."
        }
    }

    return "$major.$minor.$patch"
}

# ---------------------------------------------------------------------------
# Update-VersionFile
# Write the new version back into a package.json or plain-text version file.
# ---------------------------------------------------------------------------
function Update-VersionFile {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "Version file not found: '$FilePath'"
    }

    if ($NewVersion -notmatch $script:SEMVER_PATTERN) {
        throw "Invalid semantic version format: '$NewVersion'"
    }

    [string]$extension = [System.IO.Path]::GetExtension($FilePath).ToLower()

    if ($extension -eq '.json') {
        [string]$raw = Get-Content -LiteralPath $FilePath -Raw
        $json = $raw | ConvertFrom-Json
        $json.version = $NewVersion
        # ConvertTo-Json depth 10 preserves nested objects; -Compress keeps it readable
        $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $FilePath -Encoding UTF8
    }
    else {
        Set-Content -LiteralPath $FilePath -Value $NewVersion -Encoding UTF8
    }
}

# ---------------------------------------------------------------------------
# New-ChangelogEntry
# Build a Markdown changelog section from a list of conventional commits.
# Sections: BREAKING CHANGES, Features, Bug Fixes, Other Changes
# ---------------------------------------------------------------------------
function New-ChangelogEntry {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$NewVersion,

        [Parameter(Mandatory)]
        [string[]]$CommitMessages,

        # Allow callers (and tests) to inject a fixed date instead of today
        [Parameter()]
        [string]$Date = ([datetime]::Now.ToString('yyyy-MM-dd'))
    )

    # Collect commits into buckets
    $breaking = [System.Collections.Generic.List[string]]::new()
    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()
    $other    = [System.Collections.Generic.List[string]]::new()

    foreach ($commit in $CommitMessages) {
        if ($commit -match 'BREAKING CHANGE:\s*(.+)') {
            # Footer-style breaking change
            [void]$breaking.Add([string]$Matches[1].Trim())
        }
        elseif ($commit -match '^[a-z]+(\(.+\))?!:\s*(.+)') {
            # Inline breaking change marker (e.g. feat!: or fix(scope)!:)
            [void]$breaking.Add([string]$Matches[2].Trim())
        }
        elseif ($commit -match '^feat(\(.+\))?:\s*(.+)') {
            [void]$features.Add([string]$Matches[2].Trim())
        }
        elseif ($commit -match '^fix(\(.+\))?:\s*(.+)') {
            [void]$fixes.Add([string]$Matches[2].Trim())
        }
        else {
            [void]$other.Add($commit.Trim())
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$NewVersion] - $Date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        foreach ($item in $breaking) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($item in $features) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        foreach ($item in $fixes) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other Changes')
        foreach ($item in $other) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    return $sb.ToString().TrimEnd()
}

# ---------------------------------------------------------------------------
# Invoke-VersionBump
# Orchestrates the full version-bump workflow:
#   1. Read current version from file
#   2. Determine bump type from commits
#   3. Compute new version
#   4. Update the version file in-place
#   5. Generate a changelog entry
#   6. Optionally prepend the entry to a changelog file
#   7. Return a result hashtable
# ---------------------------------------------------------------------------
function Invoke-VersionBump {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFilePath,

        [Parameter(Mandatory)]
        [string[]]$CommitMessages,

        # Optional path to a CHANGELOG.md — entry is prepended when supplied
        [Parameter()]
        [string]$ChangelogPath = ''
    )

    [string]$currentVersion = Get-SemanticVersion -FilePath $VersionFilePath
    [string]$bumpType       = Get-BumpType        -CommitMessages $CommitMessages
    [string]$newVersion     = Get-NextVersion      -CurrentVersion $currentVersion -BumpType $bumpType

    Update-VersionFile -FilePath $VersionFilePath -NewVersion $newVersion

    [string]$changelogEntry = New-ChangelogEntry -NewVersion $newVersion -CommitMessages $CommitMessages

    if (-not [string]::IsNullOrWhiteSpace($ChangelogPath)) {
        if (Test-Path -LiteralPath $ChangelogPath) {
            [string]$existing = Get-Content -LiteralPath $ChangelogPath -Raw
            Set-Content -LiteralPath $ChangelogPath -Value "$changelogEntry`n`n$existing" -Encoding UTF8
        }
        else {
            Set-Content -LiteralPath $ChangelogPath -Value $changelogEntry -Encoding UTF8
        }
    }

    return @{
        OldVersion     = $currentVersion
        NewVersion     = $newVersion
        BumpType       = $bumpType
        ChangelogEntry = $changelogEntry
    }
}
