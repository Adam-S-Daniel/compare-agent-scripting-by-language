# Semantic Version Bumper
# Reads a version file, analyzes conventional commits to determine the bump type,
# updates the version file, and generates a changelog entry.
#
# Usage: ./Invoke-SemanticVersionBump.ps1 -VersionFile version.json -CommitsFile commits.json
#
# TDD: tests in SemanticVersionBumper.Tests.ps1 were written first.
# Each function below was added incrementally to satisfy failing tests.

param(
    [string]$VersionFile,
    [string]$CommitsFile
)

# ---------------------------------------------------------------------------
# FUNCTION: Read-VersionFile
# ---------------------------------------------------------------------------
function Read-VersionFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Cannot find version file: '$Path'"
    }

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json

    if ($null -eq $content.version) {
        throw "Version file '$Path' has no 'version' field"
    }

    return $content.version
}

# ---------------------------------------------------------------------------
# FUNCTION: Get-BumpType
# Conventional commits: feat! or BREAKING CHANGE -> major, feat -> minor, fix -> patch.
# Highest severity wins.
# ---------------------------------------------------------------------------
function Get-BumpType {
    param([Parameter(Mandatory)][array]$Commits)

    $hasMajor = $false
    $hasMinor = $false
    $hasPatch = $false

    foreach ($commit in $Commits) {
        $subject = $commit.subject
        $body    = $commit.body

        # Breaking change: subject has ! before colon, or body has BREAKING CHANGE
        if ($subject -match '^[a-zA-Z]+!:' -or $body -match 'BREAKING CHANGE') {
            $hasMajor = $true
        }
        elseif ($subject -match '^feat:') {
            $hasMinor = $true
        }
        elseif ($subject -match '^fix:') {
            $hasPatch = $true
        }
    }

    if ($hasMajor) { return "major" }
    if ($hasMinor) { return "minor" }
    return "patch"
}

# ---------------------------------------------------------------------------
# FUNCTION: Get-NextVersion
# ---------------------------------------------------------------------------
function Get-NextVersion {
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][ValidateSet("major","minor","patch")][string]$BumpType
    )

    $parts = $CurrentVersion -split '\.'
    [int]$major = $parts[0]
    [int]$minor = $parts[1]
    [int]$patch = $parts[2]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
    }
}

# ---------------------------------------------------------------------------
# FUNCTION: Update-VersionFile
# Writes the new version back, preserving all other fields.
# ---------------------------------------------------------------------------
function Update-VersionFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $content.version = $NewVersion
    $content | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
}

# ---------------------------------------------------------------------------
# FUNCTION: New-ChangelogEntry
# Generates a Keep-a-Changelog-style entry grouped by commit type.
# ---------------------------------------------------------------------------
function New-ChangelogEntry {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][array]$Commits
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## [$Version] - $date")
    $lines.Add("")

    $breaking = $Commits | Where-Object { $_.subject -match '^[a-zA-Z]+!:' -or $_.body -match 'BREAKING CHANGE' }
    $features = $Commits | Where-Object { $_.subject -match '^feat:' -and $_ -notin $breaking }
    $fixes    = $Commits | Where-Object { $_.subject -match '^fix:' }

    if ($breaking.Count -gt 0) {
        $lines.Add("### Breaking Changes")
        $breaking | ForEach-Object { $lines.Add("- $($_.subject)") }
        $lines.Add("")
    }
    if ($features.Count -gt 0) {
        $lines.Add("### Features")
        $features | ForEach-Object { $lines.Add("- $($_.subject)") }
        $lines.Add("")
    }
    if ($fixes.Count -gt 0) {
        $lines.Add("### Bug Fixes")
        $fixes | ForEach-Object { $lines.Add("- $($_.subject)") }
        $lines.Add("")
    }

    return $lines -join "`n"
}

# ---------------------------------------------------------------------------
# MAIN LOGIC
# Guard: only execute when run directly (not dot-sourced in tests).
# $MyInvocation.InvocationName is '.' when dot-sourced.
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.' -and $VersionFile -and $CommitsFile) {
    if (-not (Test-Path $CommitsFile)) {
        Write-Error "Cannot find commits file: '$CommitsFile'"
        exit 1
    }

    $currentVersion = Read-VersionFile -Path $VersionFile
    $commits        = Get-Content -Path $CommitsFile -Raw | ConvertFrom-Json
    $bumpType       = Get-BumpType -Commits $commits
    $newVersion     = Get-NextVersion -CurrentVersion $currentVersion -BumpType $bumpType

    Update-VersionFile -Path $VersionFile -NewVersion $newVersion
    $changelog = New-ChangelogEntry -Version $newVersion -Commits $commits

    Write-Output "NEW_VERSION: $newVersion"
    Write-Output "BUMP_TYPE: $bumpType"
    Write-Output ""
    Write-Output $changelog
}
