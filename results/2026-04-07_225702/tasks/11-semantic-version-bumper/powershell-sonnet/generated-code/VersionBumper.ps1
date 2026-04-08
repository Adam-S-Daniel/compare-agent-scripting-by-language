# VersionBumper.ps1
# Semantic Version Bumper — implementation module
# Determines the next semver from conventional commit messages and updates
# a version file (package.json or plain VERSION file), then generates a
# CHANGELOG entry.

# ---------------------------------------------------------------------------
# Get-CurrentVersion
#   Reads the current semantic version from a package.json or VERSION file.
# ---------------------------------------------------------------------------
function Get-CurrentVersion {
    param(
        [string]$VersionFilePath
    )

    if (-not (Test-Path $VersionFilePath)) {
        throw "Version file not found: '$VersionFilePath'"
    }

    $extension = [System.IO.Path]::GetExtension($VersionFilePath)
    $filename   = [System.IO.Path]::GetFileName($VersionFilePath)

    if ($filename -eq "package.json") {
        $json = Get-Content $VersionFilePath -Raw | ConvertFrom-Json
        if ($null -eq $json.version -or $json.version -eq '') {
            throw "No 'version' field found in '$VersionFilePath'"
        }
        return $json.version
    }
    else {
        # Treat as a plain text file containing only the version string
        $raw = (Get-Content $VersionFilePath -Raw).Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) {
            throw "Version file '$VersionFilePath' is empty"
        }
        return $raw
    }
}

# ---------------------------------------------------------------------------
# Get-BumpType
#   Analyses an array of conventional commit message strings and returns the
#   highest-priority bump type: 'major', 'minor', or 'patch'.
#
#   Rules (from the Conventional Commits spec):
#     • Any commit with '!' after the type, or a 'BREAKING CHANGE:' footer
#       → major
#     • A 'feat:' commit (no breaking marker) → minor
#     • Anything else (fix, chore, docs, …)   → patch
# ---------------------------------------------------------------------------
function Get-BumpType {
    param(
        [string[]]$Commits
    )

    $bump = "patch"   # default / lowest priority

    foreach ($commit in $Commits) {
        # Breaking change indicators take highest priority
        if ($commit -match '^[a-z]+!:' -or $commit -match 'BREAKING CHANGE:') {
            return "major"   # Can't go higher — short-circuit
        }

        if ($commit -match '^feat(\([^)]*\))?:') {
            $bump = "minor"  # Upgrade to minor if not already major
        }
    }

    return $bump
}

# ---------------------------------------------------------------------------
# Invoke-VersionBump
#   Applies a bump type to an existing semver string and returns the new
#   version string.
# ---------------------------------------------------------------------------
function Invoke-VersionBump {
    param(
        [string]$Version,
        [string]$BumpType
    )

    # Validate bump type
    if ($BumpType -notin @("major", "minor", "patch")) {
        throw "Invalid bump type '$BumpType'. Must be 'major', 'minor', or 'patch'."
    }

    # Validate semver format (major.minor.patch with optional leading 'v')
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version format '$Version'. Expected format: MAJOR.MINOR.PATCH"
    }

    $parts = $Version -split '\.'
    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = $parts[2]

    switch ($BumpType) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
    }

    return "$major.$minor.$patch"
}

# ---------------------------------------------------------------------------
# New-ChangelogEntry
#   Builds a markdown changelog section for the given version and commits.
#   Commits are grouped by type: Breaking Changes, Features, Bug Fixes, Other.
# ---------------------------------------------------------------------------
function New-ChangelogEntry {
    param(
        [string]$NewVersion,
        [string[]]$Commits,
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $breaking = [System.Collections.Generic.List[string]]::new()
    $features  = [System.Collections.Generic.List[string]]::new()
    $fixes     = [System.Collections.Generic.List[string]]::new()
    $others    = [System.Collections.Generic.List[string]]::new()

    foreach ($commit in $Commits) {
        if ($commit -match '^([a-z]+)(!)?(\([^)]*\))?:\s*(.+)') {
            $type        = $Matches[1]
            $isBreaking  = $Matches[2] -eq '!'
            $description = ($Matches[4] -split "`n")[0].Trim()

            if ($isBreaking -or $commit -match 'BREAKING CHANGE:') {
                $breaking.Add($description)
            }
            elseif ($type -eq 'feat') {
                $features.Add($description)
            }
            elseif ($type -eq 'fix') {
                $fixes.Add($description)
            }
            else {
                $others.Add("[$type] $description")
            }
        }
        else {
            # Non-conventional commit — include verbatim
            $others.Add($commit.Trim())
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$NewVersion] - $Date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine("### Breaking Changes")
        [void]$sb.AppendLine()
        foreach ($item in $breaking) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    if ($features.Count -gt 0) {
        [void]$sb.AppendLine("### Features")
        [void]$sb.AppendLine()
        foreach ($item in $features) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine("### Bug Fixes")
        [void]$sb.AppendLine()
        foreach ($item in $fixes) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    if ($others.Count -gt 0) {
        [void]$sb.AppendLine("### Other Changes")
        [void]$sb.AppendLine()
        foreach ($item in $others) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Set-VersionInFile
#   Writes the new version back to the file (package.json or VERSION file),
#   preserving all other content in package.json.
# ---------------------------------------------------------------------------
function Set-VersionInFile {
    param(
        [string]$VersionFilePath,
        [string]$NewVersion
    )

    $filename = [System.IO.Path]::GetFileName($VersionFilePath)

    if ($filename -eq "package.json") {
        $json = Get-Content $VersionFilePath -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content $VersionFilePath
    }
    else {
        $NewVersion | Set-Content $VersionFilePath
    }
}

# ---------------------------------------------------------------------------
# Invoke-SemanticVersionBump  (integration / orchestration)
#   Main entry point: reads current version, determines bump, updates file,
#   creates/appends changelog entry, and returns the new version string.
# ---------------------------------------------------------------------------
function Invoke-SemanticVersionBump {
    param(
        [string]$VersionFilePath,
        [string[]]$Commits,
        [string]$ChangelogPath = "CHANGELOG.md",
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    # 1. Read current version
    $currentVersion = Get-CurrentVersion -VersionFilePath $VersionFilePath

    # 2. Determine bump type from commits
    $bumpType = Get-BumpType -Commits $Commits

    # 3. Calculate new version
    $newVersion = Invoke-VersionBump -Version $currentVersion -BumpType $bumpType

    # 4. Update the version file
    Set-VersionInFile -VersionFilePath $VersionFilePath -NewVersion $newVersion

    # 5. Generate changelog entry
    $entry = New-ChangelogEntry -NewVersion $newVersion -Commits $Commits -Date $Date

    # 6. Prepend entry to changelog (create file if needed)
    if (Test-Path $ChangelogPath) {
        $existing = Get-Content $ChangelogPath -Raw

        # If file starts with a top-level heading, insert after it
        if ($existing -match '^(#[^#][^\r\n]*[\r\n]+)(.*)$') {
            $header  = $Matches[1]
            $rest    = $Matches[2]
            $updated = "$header`n$entry$rest"
        }
        else {
            $updated = "$entry$existing"
        }
        $updated | Set-Content $ChangelogPath
    }
    else {
        "# Changelog`n`n$entry" | Set-Content $ChangelogPath
    }

    # 7. Output the new version
    return $newVersion
}
