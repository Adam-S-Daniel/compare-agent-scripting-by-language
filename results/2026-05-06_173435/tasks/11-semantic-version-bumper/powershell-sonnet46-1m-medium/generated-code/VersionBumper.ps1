# Semantic Version Bumper
# Reads a version file (version.json or package.json), analyzes conventional commits
# to determine bump type (patch/minor/major), updates the file, and generates a
# CHANGELOG entry. Follows TDD: tests in VersionBumper.Tests.ps1 were written first.
#
# Conventional commit rules:
#   fix:   → patch bump
#   feat:  → minor bump
#   *!: or BREAKING CHANGE → major bump
#   Major > Minor > Patch in priority

param(
    [string]$VersionFile = "version.json",
    [string]$CommitsFile = "commits.txt",
    [string]$ChangelogFile = "CHANGELOG.md",
    [switch]$NoExecute  # When set, only define functions (used by tests via dot-source)
)

function Get-CurrentVersion {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: $FilePath"
    }

    $content = Get-Content $FilePath -Raw | ConvertFrom-Json

    if (-not $content.PSObject.Properties['version']) {
        throw "No 'version' field found in $FilePath"
    }

    return $content.version
}

function Get-BumpType {
    param([string[]]$Commits)

    $bumpType = "none"

    foreach ($commit in $Commits) {
        $trimmed = $commit.Trim()
        if (-not $trimmed) { continue }

        # Breaking change: any type with ! before colon, or BREAKING CHANGE anywhere
        if ($trimmed -match '^\w+[\w()]*!:' -or $trimmed -match '\bBREAKING CHANGE\b') {
            return "major"
        }

        # Parse the commit type prefix (e.g., "feat", "feat(scope)")
        if ($trimmed -match '^(\w+)(?:\([^)]*\))?:') {
            $type = $Matches[1]
            if ($type -eq "feat") {
                if ($bumpType -ne "major") { $bumpType = "minor" }
            } elseif ($type -eq "fix") {
                if ($bumpType -eq "none") { $bumpType = "patch" }
            }
        }
    }

    return $bumpType
}

function Invoke-BumpVersion {
    param(
        [string]$Version,
        [string]$BumpType
    )

    $parts = $Version -split '\.'
    if ($parts.Count -ne 3) {
        throw "Invalid semver format: '$Version' (expected x.y.z)"
    }

    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = $parts[2]

    switch ($BumpType) {
        "major" { $major++; $minor = 0; $patch = 0 }
        "minor" { $minor++; $patch = 0 }
        "patch" { $patch++ }
        "none"  { }
        default { throw "Unknown bump type: $BumpType" }
    }

    return "$major.$minor.$patch"
}

function Update-VersionFile {
    param(
        [string]$FilePath,
        [string]$NewVersion
    )

    $content = Get-Content $FilePath -Raw | ConvertFrom-Json
    $content.version = $NewVersion
    # Use -Depth to preserve nested objects; Compress=false keeps formatting readable
    $content | ConvertTo-Json -Depth 10 | Set-Content $FilePath -Encoding UTF8
}

function New-ChangelogEntry {
    param(
        [string]$Version,
        [string[]]$Commits,
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $breaking = [System.Collections.Generic.List[string]]::new()
    $features  = [System.Collections.Generic.List[string]]::new()
    $fixes     = [System.Collections.Generic.List[string]]::new()

    foreach ($commit in $Commits) {
        $trimmed = $commit.Trim()
        if (-not $trimmed) { continue }

        if ($trimmed -match '^\w+[\w()]*!:' -or $trimmed -match '\bBREAKING CHANGE\b') {
            $breaking.Add("- $trimmed")
        } elseif ($trimmed -match '^feat') {
            $features.Add("- $trimmed")
        } elseif ($trimmed -match '^fix') {
            $fixes.Add("- $trimmed")
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## [$Version] - $Date")
    $lines.Add("")

    if ($breaking.Count -gt 0) {
        $lines.Add("### BREAKING CHANGES")
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

    return $lines -join "`n"
}

function Invoke-VersionBumper {
    param(
        [string]$VersionFile = "version.json",
        [string]$CommitsFile = "commits.txt",
        [string]$ChangelogFile = "CHANGELOG.md"
    )

    if (-not (Test-Path $CommitsFile)) {
        throw "Commits file not found: $CommitsFile"
    }

    $commits = Get-Content $CommitsFile | Where-Object { $_.Trim() -ne "" }
    $currentVersion = Get-CurrentVersion -FilePath $VersionFile
    $bumpType = Get-BumpType -Commits $commits
    $newVersion = Invoke-BumpVersion -Version $currentVersion -BumpType $bumpType

    if ($bumpType -ne "none") {
        Update-VersionFile -FilePath $VersionFile -NewVersion $newVersion

        $changelogEntry = New-ChangelogEntry -Version $newVersion -Commits $commits

        if (Test-Path $ChangelogFile) {
            $existing = Get-Content $ChangelogFile -Raw
            ($changelogEntry + $existing) | Set-Content $ChangelogFile -Encoding UTF8
        } else {
            $changelogEntry | Set-Content $ChangelogFile -Encoding UTF8
        }
    }

    return [PSCustomObject]@{
        PreviousVersion = $currentVersion
        NewVersion      = $newVersion
        BumpType        = $bumpType
    }
}

# Main execution — only runs when script is called directly (not dot-sourced with -NoExecute)
if (-not $NoExecute) {
    $result = Invoke-VersionBumper `
        -VersionFile $VersionFile `
        -CommitsFile $CommitsFile `
        -ChangelogFile $ChangelogFile

    Write-Output "NEW_VERSION: $($result.NewVersion)"
    Write-Output "BUMP_TYPE: $($result.BumpType)"
    Write-Output "PREVIOUS_VERSION: $($result.PreviousVersion)"
}
