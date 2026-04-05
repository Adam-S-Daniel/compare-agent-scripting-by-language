# VersionBumper.ps1
# Semantic Version Bumper — implementation
# Parses a version file, determines bump type from conventional commits,
# updates the file, and generates a changelog entry.
#
# TDD approach: tests were written first in VersionBumper.Tests.ps1,
# then this implementation was written to make them pass.

# ─────────────────────────────────────────────────────────────
# Helper: detect whether file content looks like JSON
# We check for a leading '{' rather than attempting to parse,
# because ConvertFrom-Json throws a RuntimeException subclass
# (PSInvalidOperationException) for invalid input — the same base
# type we'd use to distinguish our own errors.
# ─────────────────────────────────────────────────────────────
function Test-LooksLikeJson {
    param([string]$Content)
    return $Content.Trim().StartsWith('{')
}

# ─────────────────────────────────────────────────────────────
# 1. Get-CurrentVersion
#    Reads the semver string from either a plain text version file
#    or a package.json (looks for "version" key).
# ─────────────────────────────────────────────────────────────
function Get-CurrentVersion {
    param([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        throw "Version file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw

    # Try as JSON when content looks like a JSON object
    if (Test-LooksLikeJson -Content $content) {
        $json = $content | ConvertFrom-Json
        if ($null -eq $json.version) {
            throw "No 'version' field found in JSON file: $Path"
        }
        return [string]$json.version
    }

    # Plain text: extract the first semver pattern found
    $semverPattern = '\d+\.\d+\.\d+'
    if ($content -match $semverPattern) {
        return $Matches[0].Trim()
    }

    throw "No semantic version found in file: $Path"
}

# ─────────────────────────────────────────────────────────────
# 2. Get-BumpType
#    Analyses an array of conventional commit message strings and
#    returns 'major', 'minor', 'patch', or 'none'.
#
#    Rules (highest precedence first):
#      major  — subject type ends with '!' (e.g. "feat!: …") OR
#               message contains "BREAKING CHANGE"
#      minor  — any "feat:" commit
#      patch  — any "fix:" commit
#      none   — only docs/chore/style/etc.
# ─────────────────────────────────────────────────────────────
function Get-BumpType {
    param([string[]]$Commits)

    $bump = "none"

    foreach ($commit in $Commits) {
        # Breaking change: type! or BREAKING CHANGE in body
        if ($commit -match '^[a-z]+!:' -or $commit -match 'BREAKING CHANGE') {
            return "major"
        }

        if ($commit -match '^feat:') {
            # minor is higher than patch but lower than major
            if ($bump -ne "major") { $bump = "minor" }
        } elseif ($commit -match '^fix:') {
            if ($bump -eq "none") { $bump = "patch" }
        }
    }

    return $bump
}

# ─────────────────────────────────────────────────────────────
# 3. Get-NextVersion
#    Given the current semver string and a bump type, returns the
#    next version string.
# ─────────────────────────────────────────────────────────────
function Get-NextVersion {
    param(
        [string]$CurrentVersion,
        [string]$BumpType
    )

    $semverPattern = '^(\d+)\.(\d+)\.(\d+)$'
    if ($CurrentVersion -notmatch $semverPattern) {
        throw "Invalid semantic version: '$CurrentVersion'. Expected format: MAJOR.MINOR.PATCH"
    }

    [int]$major = [int]$Matches[1]
    [int]$minor = [int]$Matches[2]
    [int]$patch = [int]$Matches[3]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
        "none"  { return $CurrentVersion }
        default { throw "Unknown bump type: '$BumpType'. Expected: major, minor, patch, or none" }
    }
}

# ─────────────────────────────────────────────────────────────
# 4. Set-Version
#    Writes the new version back into the version file.
#    Handles both plain text and package.json.
# ─────────────────────────────────────────────────────────────
function Set-Version {
    param(
        [string]$Path,
        [string]$NewVersion
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Version file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw

    # Handle JSON files (update the "version" key)
    if (Test-LooksLikeJson -Content $content) {
        $json = $content | ConvertFrom-Json
        $json.version = $NewVersion
        # Depth 10 preserves nested objects; produces readable output
        Set-Content -Path $Path -Value ($json | ConvertTo-Json -Depth 10)
        return
    }

    # Plain text: replace the first semver match in place
    $semverPattern = '\d+\.\d+\.\d+'
    if ($content -notmatch $semverPattern) {
        throw "No semantic version found in file to replace: $Path"
    }

    $newContent = ($content -replace $semverPattern, $NewVersion).Trim()
    Set-Content -Path $Path -Value $newContent
}

# ─────────────────────────────────────────────────────────────
# 5. New-ChangelogEntry
#    Generates a Markdown changelog section for a new release.
#    Groups commits into Breaking Changes, Features, Bug Fixes.
#    Non-releasable types (docs, chore, style, …) are omitted.
# ─────────────────────────────────────────────────────────────
function New-ChangelogEntry {
    param(
        [string]$Version,
        [string[]]$Commits,
        [string]$Date
    )

    $features = [System.Collections.Generic.List[string]]::new()
    $fixes     = [System.Collections.Generic.List[string]]::new()
    $breaking  = [System.Collections.Generic.List[string]]::new()

    foreach ($commit in $Commits) {
        # Match "type[!]: description" — subject line only (`.` doesn't match `\n`)
        if ($commit -match '^([a-z]+)(!)?:\s*(.+)') {
            $type        = $Matches[1]
            $isBreaking  = ($null -ne $Matches[2] -and $Matches[2] -eq '!')
            # Take only the first line of the description
            $description = $Matches[3].Split("`n")[0].Trim()

            # Also detect "BREAKING CHANGE" footer in commit body
            if ($isBreaking -or $commit -match 'BREAKING CHANGE') {
                $breaking.Add($description)
            } elseif ($type -eq 'feat') {
                $features.Add($description)
            } elseif ($type -eq 'fix') {
                $fixes.Add($description)
            }
            # docs/chore/style/refactor/etc. intentionally omitted
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## [$Version] - $Date")
    $lines.Add("")

    if ($breaking.Count -gt 0) {
        $lines.Add("### Breaking Changes")
        foreach ($item in $breaking) { $lines.Add("- $item") }
        $lines.Add("")
    }

    if ($features.Count -gt 0) {
        $lines.Add("### Features")
        foreach ($item in $features) { $lines.Add("- $item") }
        $lines.Add("")
    }

    if ($fixes.Count -gt 0) {
        $lines.Add("### Bug Fixes")
        foreach ($item in $fixes) { $lines.Add("- $item") }
        $lines.Add("")
    }

    return $lines -join "`n"
}

# ─────────────────────────────────────────────────────────────
# 6. Update-Changelog
#    Prepends a changelog entry to a CHANGELOG.md file,
#    creating the file if it doesn't exist.
# ─────────────────────────────────────────────────────────────
function Update-Changelog {
    param(
        [string]$Path,
        [string]$Entry
    )

    if (Test-Path -Path $Path) {
        $existing = Get-Content -Path $Path -Raw
        Set-Content -Path $Path -Value "$Entry`n$existing"
    } else {
        Set-Content -Path $Path -Value $Entry
    }
}

# ─────────────────────────────────────────────────────────────
# 7. Invoke-VersionBump  (orchestrator / integration entry point)
#    Ties everything together: read → bump → write → changelog.
#    Returns a hashtable: { OldVersion, NewVersion, BumpType }
# ─────────────────────────────────────────────────────────────
function Invoke-VersionBump {
    param(
        [string]$VersionFile,
        [string[]]$Commits,
        [string]$ChangelogFile,
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $oldVersion = Get-CurrentVersion -Path $VersionFile
    $bumpType   = Get-BumpType -Commits $Commits
    $newVersion = Get-NextVersion -CurrentVersion $oldVersion -BumpType $bumpType

    if ($bumpType -ne "none") {
        Set-Version    -Path $VersionFile -NewVersion $newVersion
        $entry = New-ChangelogEntry -Version $newVersion -Commits $Commits -Date $Date
        Update-Changelog -Path $ChangelogFile -Entry $entry
    }

    return @{
        OldVersion = $oldVersion
        NewVersion = $newVersion
        BumpType   = $bumpType
    }
}
