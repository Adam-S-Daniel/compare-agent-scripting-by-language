# Invoke-SemanticVersionBump.ps1
# Parses a version file, determines next semver from conventional commits,
# updates the file, and generates a changelog entry.
#
# Usage (direct): ./Invoke-SemanticVersionBump.ps1 -VersionFilePath version.json -CommitsFilePath commits.txt
# Usage (dot-source for functions): . ./Invoke-SemanticVersionBump.ps1 -LoadOnly

param(
    [string]$VersionFilePath = "version.json",
    [string]$CommitsFilePath = "commits.txt",
    [switch]$LoadOnly
)

# Analyze conventional commits and return bump type: "patch", "minor", or "major"
function Get-BumpType {
    param([string[]]$Commits)

    $bumpType = "patch"
    foreach ($commit in $Commits) {
        $trimmed = $commit.Trim()

        # BREAKING CHANGE footer or ! suffix -> major
        if ($trimmed -match "BREAKING CHANGE:" -or
            $trimmed -match "^(feat|fix|refactor|perf|style|test|docs|chore|build|ci)!:") {
            return "major"
        }

        # feat -> at least minor
        if ($trimmed -match "^feat:") {
            $bumpType = "minor"
        }
    }

    return $bumpType
}

# Compute next semantic version given current version and bump type
function Invoke-BumpVersion {
    param(
        [string]$Version,
        [string]$BumpType
    )

    $parts = $Version -split "\."
    if ($parts.Count -ne 3) {
        throw "Invalid semver format: $Version (expected X.Y.Z)"
    }

    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
        default { throw "Unknown bump type: $BumpType" }
    }
}

# Generate a Keep-a-Changelog style entry for the new version
function New-ChangelogEntry {
    param(
        [string]$Version,
        [string[]]$Commits
    )

    $date = Get-Date -Format "yyyy-MM-dd"
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## [$Version] - $date")
    $lines.Add("")

    $breaking = $Commits | Where-Object {
        $_ -match "BREAKING CHANGE:" -or $_ -match "^(feat|fix|refactor|perf|style|test|docs|chore|build|ci)!:"
    } | ForEach-Object {
        $msg = $_ -replace "^[^:]+!?:\s*", ""
        "- $msg (BREAKING)"
    }

    $features = $Commits | Where-Object { $_ -match "^feat:" } | ForEach-Object {
        $msg = $_ -replace "^feat:\s*", ""
        "- $msg"
    }

    $fixes = $Commits | Where-Object { $_ -match "^fix:" } | ForEach-Object {
        $msg = $_ -replace "^fix:\s*", ""
        "- $msg"
    }

    if ($breaking) {
        $lines.Add("### Breaking Changes")
        $breaking | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }
    if ($features) {
        $lines.Add("### Features")
        $features | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }
    if ($fixes) {
        $lines.Add("### Bug Fixes")
        $fixes | ForEach-Object { $lines.Add($_) }
        $lines.Add("")
    }

    return $lines -join "`n"
}

# Read semantic version string from a JSON file (version.json or package.json)
function Get-VersionFromFile {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: $FilePath"
    }

    $content = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    if ($null -eq $content.version -or $content.version -eq "") {
        throw "No 'version' field found in $FilePath"
    }

    return $content.version
}

# Update the version field in a JSON file in-place
function Set-VersionInFile {
    param(
        [string]$FilePath,
        [string]$NewVersion
    )

    $content = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    $content.version = $NewVersion
    $content | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath -Encoding UTF8
}

# Main orchestration: read version, determine bump, update file, return result object
function Invoke-SemanticVersionBump {
    param(
        [string]$VersionFilePath = "version.json",
        [string]$CommitsFilePath = "commits.txt"
    )

    $currentVersion = Get-VersionFromFile -FilePath $VersionFilePath

    if (-not (Test-Path $CommitsFilePath)) {
        throw "Commits file not found: $CommitsFilePath"
    }

    $commits = Get-Content -Path $CommitsFilePath | Where-Object { $_.Trim() -ne "" }

    $bumpType = Get-BumpType -Commits $commits
    $newVersion = Invoke-BumpVersion -Version $currentVersion -BumpType $bumpType
    $changelog = New-ChangelogEntry -Version $newVersion -Commits $commits

    Set-VersionInFile -FilePath $VersionFilePath -NewVersion $newVersion

    return [PSCustomObject]@{
        OldVersion = $currentVersion
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}

# Run main logic only when invoked directly (not dot-sourced for function loading)
if (-not $LoadOnly) {
    try {
        $result = Invoke-SemanticVersionBump -VersionFilePath $VersionFilePath -CommitsFilePath $CommitsFilePath
        Write-Host "Old version: $($result.OldVersion)"
        Write-Host "New version: $($result.NewVersion)"
        Write-Host "Bump type:   $($result.BumpType)"
        Write-Host ""
        Write-Host "=== Changelog Entry ==="
        Write-Host $result.Changelog
    }
    catch {
        Write-Error "Version bump failed: $_"
        exit 1
    }
}
