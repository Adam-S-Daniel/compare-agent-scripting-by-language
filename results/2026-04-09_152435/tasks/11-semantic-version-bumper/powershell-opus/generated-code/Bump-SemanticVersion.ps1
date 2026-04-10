#!/usr/bin/env pwsh
# Bump-SemanticVersion.ps1
#
# Parses a VERSION file containing a semantic version string, analyzes
# conventional commit messages to determine the bump type (major/minor/patch),
# updates the VERSION file, generates a changelog entry, and outputs the
# new version.
#
# Conventional commit format: type(scope)!: description
#   - fix  -> patch bump
#   - feat -> minor bump
#   - !    -> major bump (breaking change)

param(
    [string]$VersionFile = "VERSION",
    [string]$ChangelogFile = "CHANGELOG.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Parse a semantic version string "X.Y.Z" into a hashtable
function Parse-SemanticVersion {
    param([string]$Version)

    $v = $Version.Trim()
    if ($v -match '^v?(\d+)\.(\d+)\.(\d+)$') {
        return @{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
        }
    }
    throw "Invalid semantic version: '$v'"
}

# Retrieve and parse conventional commits from git log
function Get-ConventionalCommits {
    # Get all commit subject lines
    $messages = git log --format="%s" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git log failed: $messages"
        return @()
    }

    $commits = @()
    foreach ($msg in $messages) {
        # Match conventional commit pattern: type(scope)!: description
        if ($msg -match '^(\w+)(\([^)]*\))?(!)?\s*:\s*(.+)$') {
            $commits += [PSCustomObject]@{
                Type        = $Matches[1].ToLower()
                Scope       = if ($Matches[2]) { $Matches[2].Trim('(', ')') } else { $null }
                Breaking    = [bool]$Matches[3]
                Description = $Matches[4].Trim()
                Raw         = $msg
            }
        }
    }

    return $commits
}

# Determine the bump type from an array of conventional commits
# Priority: breaking (major) > feat (minor) > fix (patch) > none
function Get-BumpType {
    param([array]$Commits)

    if (-not $Commits -or $Commits.Count -eq 0) {
        return "none"
    }

    $hasBreaking = $false
    $hasFeature = $false
    $hasFix = $false

    foreach ($c in $Commits) {
        if ($c.Breaking) { $hasBreaking = $true }
        if ($c.Type -eq 'feat') { $hasFeature = $true }
        if ($c.Type -eq 'fix') { $hasFix = $true }
    }

    if ($hasBreaking) { return "major" }
    if ($hasFeature) { return "minor" }
    if ($hasFix) { return "patch" }
    return "none"
}

# Apply the bump to a version hashtable, returning a new version hashtable
function Invoke-VersionBump {
    param(
        [hashtable]$Version,
        [string]$BumpType
    )

    switch ($BumpType) {
        "major" { return @{ Major = $Version.Major + 1; Minor = 0; Patch = 0 } }
        "minor" { return @{ Major = $Version.Major; Minor = $Version.Minor + 1; Patch = 0 } }
        "patch" { return @{ Major = $Version.Major; Minor = $Version.Minor; Patch = $Version.Patch + 1 } }
        default { return $Version.Clone() }
    }
}

# Format a version hashtable as "X.Y.Z"
function Format-Version {
    param([hashtable]$Version)
    return "$($Version.Major).$($Version.Minor).$($Version.Patch)"
}

# Build a markdown changelog entry from the new version and commits
function New-ChangelogEntry {
    param(
        [string]$NewVersion,
        [array]$Commits
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $lines = @("## [$NewVersion] - $date", "")

    # Group commits by category
    $breaking = @($Commits | Where-Object { $_.Breaking })
    $features = @($Commits | Where-Object { $_.Type -eq 'feat' -and -not $_.Breaking })
    $fixes    = @($Commits | Where-Object { $_.Type -eq 'fix' -and -not $_.Breaking })
    $other    = @($Commits | Where-Object { $_.Type -notin @('feat', 'fix') -and -not $_.Breaking })

    if ($breaking.Count -gt 0) {
        $lines += "### Breaking Changes"
        foreach ($c in $breaking) { $lines += "- $($c.Description)" }
        $lines += ""
    }
    if ($features.Count -gt 0) {
        $lines += "### Features"
        foreach ($c in $features) { $lines += "- $($c.Description)" }
        $lines += ""
    }
    if ($fixes.Count -gt 0) {
        $lines += "### Bug Fixes"
        foreach ($c in $fixes) { $lines += "- $($c.Description)" }
        $lines += ""
    }
    if ($other.Count -gt 0) {
        $lines += "### Other"
        foreach ($c in $other) { $lines += "- $($c.Description)" }
        $lines += ""
    }

    return ($lines -join "`n")
}

# --- Main execution ---

try {
    if (-not (Test-Path $VersionFile)) {
        throw "Version file '$VersionFile' not found"
    }

    $currentVersionStr = (Get-Content $VersionFile -Raw).Trim()
    Write-Host "Current version: $currentVersionStr"

    $currentVersion = Parse-SemanticVersion $currentVersionStr

    # Analyze commits
    $commits = Get-ConventionalCommits
    if ($commits.Count -eq 0) {
        Write-Host "No conventional commits found. Version unchanged."
        Write-Host "NEW_VERSION=$currentVersionStr"
        exit 0
    }

    Write-Host "Found $($commits.Count) conventional commit(s)"

    $bumpType = Get-BumpType $commits
    if ($bumpType -eq "none") {
        Write-Host "No version-relevant commits found. Version unchanged."
        Write-Host "NEW_VERSION=$currentVersionStr"
        exit 0
    }

    Write-Host "BUMP_TYPE=$bumpType"

    # Compute new version
    $newVersion = Invoke-VersionBump $currentVersion $bumpType
    $newVersionStr = Format-Version $newVersion
    Write-Host "NEW_VERSION=$newVersionStr"

    # Update version file
    Set-Content -Path $VersionFile -Value $newVersionStr -NoNewline
    Write-Host "Updated $VersionFile to $newVersionStr"

    # Generate and write changelog
    $changelog = New-ChangelogEntry $newVersionStr $commits
    if (Test-Path $ChangelogFile) {
        $existing = Get-Content $ChangelogFile -Raw
        $content = "# Changelog`n`n$changelog`n$($existing -replace '^#\s*Changelog\s*\n*', '')"
    } else {
        $content = "# Changelog`n`n$changelog"
    }
    Set-Content -Path $ChangelogFile -Value $content
    Write-Host "Generated changelog entry"

} catch {
    Write-Error "Version bump failed: $_"
    exit 1
}
