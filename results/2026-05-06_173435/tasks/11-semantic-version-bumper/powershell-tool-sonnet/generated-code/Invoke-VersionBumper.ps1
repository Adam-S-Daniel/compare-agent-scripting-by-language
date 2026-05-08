# Invoke-VersionBumper.ps1
#
# Semantic Version Bumper
# -----------------------
# Reads the current version from version.txt, VERSION, or package.json,
# analyses conventional commit messages to determine the bump type
# (feat -> minor, fix/perf -> patch, breaking -> major), updates the
# version file, and appends a CHANGELOG.md entry.
#
# TDD GREEN: this file makes the Pester tests in VersionBumper.Tests.ps1 pass.
#
# Usage:
#   ./Invoke-VersionBumper.ps1                          # auto-detect files, use git log
#   ./Invoke-VersionBumper.ps1 -CommitFile commits.txt  # read commits from file (testing)
#   ./Invoke-VersionBumper.ps1 -DryRun                  # print new version, skip writes

#Requires -Version 5.1

param(
    # Explicit path to version file; auto-detected when omitted.
    [string]$VersionFile  = "",

    # Path to a plain-text file with one commit message per line.
    # When omitted the script reads from `git log`.
    [string]$CommitFile   = "",

    # Number of git log entries to inspect when CommitFile is not supplied.
    [int]$CommitCount     = 20,

    # Skip writing version file and CHANGELOG; just print the new version.
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Find-VersionFile: locate version.txt, VERSION, or package.json in $Dir.
# ---------------------------------------------------------------------------
function Find-VersionFile {
    param([string]$Dir = ".")

    $candidates = @("version.txt", "VERSION", "package.json")
    foreach ($name in $candidates) {
        $path = Join-Path $Dir $name
        if (Test-Path $path) { return $path }
    }
    throw "No version file found in '$Dir'. Expected one of: $($candidates -join ', ')"
}

# ---------------------------------------------------------------------------
# Read-Version: extract semver string from the version file.
# ---------------------------------------------------------------------------
function Read-Version {
    param([string]$Path)

    $leaf = Split-Path $Path -Leaf
    if ($leaf -eq "package.json") {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        if (-not $json.version) {
            throw "package.json at '$Path' is missing a 'version' field"
        }
        return $json.version.ToString().Trim()
    }

    # version.txt / VERSION — single line
    return (Get-Content $Path -Raw).Trim()
}

# ---------------------------------------------------------------------------
# Write-Version: update the version file in place.
# ---------------------------------------------------------------------------
function Write-Version {
    param([string]$Path, [string]$NewVersion)

    $leaf = Split-Path $Path -Leaf
    if ($leaf -eq "package.json") {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        # Preserve readable JSON formatting.
        $json | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8
    }
    else {
        Set-Content $Path -Value $NewVersion -NoNewline -Encoding UTF8
    }
}

# ---------------------------------------------------------------------------
# Get-CommitMessages: return an array of commit subject lines.
#   - If $File points to an existing file, read it (one message per line).
#   - Otherwise call `git log`.
# ---------------------------------------------------------------------------
function Get-CommitMessages {
    param([string]$File = "", [int]$Count = 20)

    if ($File -and (Test-Path $File)) {
        return @(Get-Content $File | Where-Object { $_ -ne "" })
    }

    $msgs = git log --pretty=format:"%s" -n $Count 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git log failed; continuing with empty commit list."
        return @()
    }
    return @($msgs | Where-Object { $_ -ne "" })
}

# ---------------------------------------------------------------------------
# Get-BumpType: inspect commit messages and return "major", "minor", "patch",
# or "none".
#
# Conventional commit rules applied:
#   BREAKING (type!: or body BREAKING CHANGE) -> major  (immediate, highest)
#   feat: / feat(scope):                       -> minor
#   fix: / fix(scope): / perf:                 -> patch
#   anything else                              -> none (no bump)
# ---------------------------------------------------------------------------
function Get-BumpType {
    param([string[]]$Messages)

    $bump = "none"

    foreach ($msg in $Messages) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        # Breaking change: type!: ... OR message body contains BREAKING CHANGE
        if ($msg -match '^[a-zA-Z]+(\([^)]+\))?!:' -or $msg -match 'BREAKING[- ]CHANGE') {
            return "major"   # highest precedence — exit immediately
        }

        # Feature -> minor
        if ($msg -match '^feat(\([^)]+\))?:') {
            if ($bump -ne "minor") { $bump = "minor" }
            continue
        }

        # Fix / perf -> patch (only if we haven't found something higher)
        if ($msg -match '^(fix|perf)(\([^)]+\))?:' -and $bump -eq "none") {
            $bump = "patch"
        }
    }

    return $bump
}

# ---------------------------------------------------------------------------
# Invoke-BumpVersion: increment the appropriate semver component.
# ---------------------------------------------------------------------------
function Invoke-BumpVersion {
    param([string]$Version, [string]$BumpType)

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)') {
        throw "Invalid semantic version '$Version'. Expected X.Y.Z format."
    }

    [int]$maj = $Matches[1]
    [int]$min = $Matches[2]
    [int]$pat = $Matches[3]

    switch ($BumpType) {
        "major" { $maj++; $min = 0; $pat = 0 }
        "minor" { $min++; $pat = 0 }
        "patch" { $pat++ }
        default { throw "Unknown bump type '$BumpType'." }
    }

    return "$maj.$min.$pat"
}

# ---------------------------------------------------------------------------
# New-ChangelogEntry: build a Markdown changelog block for the new version.
# ---------------------------------------------------------------------------
function New-ChangelogEntry {
    param([string]$Version, [string[]]$Messages)

    $date  = Get-Date -Format "yyyy-MM-dd"
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## [$Version] - $date")
    $lines.Add("")

    $breaking = [System.Collections.Generic.List[string]]::new()
    $features  = [System.Collections.Generic.List[string]]::new()
    $fixes     = [System.Collections.Generic.List[string]]::new()

    foreach ($msg in $Messages) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        if ($msg -match '^[a-zA-Z]+(\([^)]+\))?!:(.*)$') {
            $breaking.Add("- **BREAKING**: $($Matches[2].Trim())")
        }
        elseif ($msg -match 'BREAKING[- ]CHANGE:(.*)$') {
            $breaking.Add("- **BREAKING**: $($Matches[1].Trim())")
        }
        elseif ($msg -match '^feat(\([^)]+\))?:(.*)$') {
            $features.Add("- $($Matches[2].Trim())")
        }
        elseif ($msg -match '^(fix|perf)(\([^)]+\))?:(.*)$') {
            $fixes.Add("- $($Matches[3].Trim())")
        }
    }

    if ($breaking.Count -gt 0) {
        $lines.Add("### Breaking Changes")
        $lines.AddRange($breaking)
        $lines.Add("")
    }
    if ($features.Count -gt 0) {
        $lines.Add("### Features")
        $lines.AddRange($features)
        $lines.Add("")
    }
    if ($fixes.Count -gt 0) {
        $lines.Add("### Bug Fixes")
        $lines.AddRange($fixes)
        $lines.Add("")
    }

    return $lines -join "`n"
}

# ===========================================================================
# Main
# ===========================================================================

try {
    # 1. Locate the version file.
    $vf = if ($VersionFile) { $VersionFile } else { Find-VersionFile -Dir "." }
    Write-Output "Reading version from: $vf"

    # 2. Read current version.
    $current = Read-Version -Path $vf
    Write-Output "Current version: $current"

    # 3. Collect commit messages.
    # Wrap in @() to ensure an array even when the file has a single line.
    $commits = @(Get-CommitMessages -File $CommitFile -Count $CommitCount)
    Write-Output "Found $($commits.Count) commit message(s)"

    # 4. Determine bump type.
    $bumpType = Get-BumpType -Messages $commits
    Write-Output "Bump type: $bumpType"

    if ($bumpType -eq "none") {
        Write-Output "No conventional commits found — no version bump needed."
        Write-Output "NEW_VERSION=$current"
        exit 0
    }

    # 5. Calculate new version.
    $newVersion = Invoke-BumpVersion -Version $current -BumpType $bumpType

    # Output the new version in a machine-parseable format so act tests can grep it.
    Write-Output "NEW_VERSION=$newVersion"

    if (-not $DryRun) {
        # 6. Update version file.
        Write-Version -Path $vf -Version $newVersion
        Write-Output "Updated $vf -> $newVersion"

        # 7. Append changelog entry.
        $entry = New-ChangelogEntry -Version $newVersion -Messages $commits
        $vfDir = Split-Path $vf -Parent
        $changelogPath = if ($vfDir) { Join-Path $vfDir "CHANGELOG.md" } else { "CHANGELOG.md" }

        if (Test-Path $changelogPath) {
            $existing = Get-Content $changelogPath -Raw
            Set-Content $changelogPath -Value "$entry`n`n$existing" -Encoding UTF8 -NoNewline
        }
        else {
            Set-Content $changelogPath -Value $entry -Encoding UTF8 -NoNewline
        }
        Write-Output "Updated CHANGELOG.md"
    }
}
catch {
    Write-Error "Version bumper failed: $_"
    exit 1
}
