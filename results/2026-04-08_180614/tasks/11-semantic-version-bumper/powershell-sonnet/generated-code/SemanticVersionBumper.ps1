# SemanticVersionBumper.ps1
# Implements semantic versioning based on conventional commits.
#
# Conventional Commits spec (simplified):
#   fix:        -> patch bump
#   feat:       -> minor bump
#   <type>!:    -> major bump   (e.g. feat!:)
#   BREAKING CHANGE: footer -> major bump
#
# Dot-source this file to use the functions in tests or other scripts.
# For direct execution use Run-SemanticVersionBumper.ps1.

# ─────────────────────────────────────────────────────────────
# Get-CurrentVersion
# Reads the current version from a plain text file or package.json.
# ─────────────────────────────────────────────────────────────
function Get-CurrentVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFile
    )

    if (-not (Test-Path $VersionFile)) {
        throw "Version file not found: $VersionFile"
    }

    $content = Get-Content $VersionFile -Raw
    $trimmed = $content.Trim()

    # Detect JSON (package.json or any JSON with a "version" key)
    if ($trimmed.StartsWith("{")) {
        $json = $trimmed | ConvertFrom-Json
        if (-not $json.version) {
            throw "No 'version' field found in JSON file: $VersionFile"
        }
        return $json.version
    }

    # Plain text: just the version string
    return $trimmed
}

# ─────────────────────────────────────────────────────────────
# Get-BumpType
# Analyzes an array of conventional commit messages and returns
# the required semver bump: "major", "minor", or "patch".
# ─────────────────────────────────────────────────────────────
function Get-BumpType {
    [CmdletBinding()]
    param(
        [string[]]$Commits
    )

    $bump = "patch"   # default

    foreach ($commit in $Commits) {
        # Breaking change: ! shorthand or BREAKING CHANGE footer
        if ($commit -match '^[a-zA-Z]+(\([^)]*\))?!:' -or
            $commit -match 'BREAKING CHANGE:') {
            return "major"   # can't go higher — return immediately
        }

        # Feature: at least minor
        if ($commit -match '^feat(\([^)]*\))?:') {
            $bump = "minor"
        }
    }

    return $bump
}

# ─────────────────────────────────────────────────────────────
# Invoke-VersionBump
# Takes a semver string and a bump type, returns the new version.
# ─────────────────────────────────────────────────────────────
function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [ValidateSet("major","minor","patch")]
        [string]$BumpType
    )

    if ($Version -notmatch '^\d+\.\d+\.\d+') {
        throw "Invalid semantic version: '$Version'. Expected format: X.Y.Z"
    }

    $parts = $Version -split '\.'
    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = ($parts[2] -replace '[^0-9].*', '')

    switch ($BumpType) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }

    return "$major.$minor.$patch"
}

# ─────────────────────────────────────────────────────────────
# Set-Version
# Writes the new version back to the file (plain text or JSON).
# ─────────────────────────────────────────────────────────────
function Set-Version {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFile,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    $content = Get-Content $VersionFile -Raw
    $trimmed = $content.Trim()

    if ($trimmed.StartsWith("{")) {
        $json = $trimmed | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content $VersionFile -NoNewline
    } else {
        $NewVersion | Set-Content $VersionFile -NoNewline
    }
}

# ─────────────────────────────────────────────────────────────
# New-ChangelogEntry
# Creates a markdown-formatted changelog section for the release.
# ─────────────────────────────────────────────────────────────
function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [string[]]$Commits,

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## [$Version] - $Date")
    $lines.Add("")

    $breaking = [System.Collections.Generic.List[string]]::new()
    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()
    $other    = [System.Collections.Generic.List[string]]::new()

    foreach ($c in $Commits) {
        if ($c -match '^[a-zA-Z]+(\([^)]*\))?!:' -or $c -match 'BREAKING CHANGE:') {
            $breaking.Add("- $c")
        } elseif ($c -match '^feat(\([^)]*\))?:') {
            $msg = [regex]::Replace($c, '^feat(\([^)]*\))?:\s*', '')
            $features.Add("- $msg")
        } elseif ($c -match '^fix(\([^)]*\))?:') {
            $msg = [regex]::Replace($c, '^fix(\([^)]*\))?:\s*', '')
            $fixes.Add("- $msg")
        } else {
            $other.Add("- $c")
        }
    }

    if ($breaking.Count -gt 0) {
        $lines.Add("### Breaking Changes")
        $breaking | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }
    if ($features.Count -gt 0) {
        $lines.Add("### Features")
        $features | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }
    if ($fixes.Count -gt 0) {
        $lines.Add("### Bug Fixes")
        $fixes | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }
    if ($other.Count -gt 0) {
        $lines.Add("### Other")
        $other | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }

    return $lines -join "`n"
}

# ─────────────────────────────────────────────────────────────
# Invoke-SemanticVersionBump  (orchestrator / end-to-end)
# Reads the version file, determines bump, updates the file,
# generates a changelog, and returns a result object.
# ─────────────────────────────────────────────────────────────
function Invoke-SemanticVersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFile,

        [string[]]$Commits = @(),

        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $current   = Get-CurrentVersion -VersionFile $VersionFile
    $bumpType  = Get-BumpType -Commits $Commits
    $newVer    = Invoke-VersionBump -Version $current -BumpType $bumpType
    Set-Version -VersionFile $VersionFile -NewVersion $newVer
    $changelog = New-ChangelogEntry -Version $newVer -Commits $Commits -Date $Date

    return [PSCustomObject]@{
        OldVersion = $current
        NewVersion = $newVer
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}
