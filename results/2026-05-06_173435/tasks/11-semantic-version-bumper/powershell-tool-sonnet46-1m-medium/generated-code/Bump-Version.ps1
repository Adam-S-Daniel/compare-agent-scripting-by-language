# Semantic Version Bumper
# Determines next version from conventional commits and updates version files.
# Conventional Commits spec: feat -> minor, fix -> patch, feat!/BREAKING CHANGE -> major

function Get-CurrentVersion {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $versionFile = Join-Path $Path "version.txt"
    $packageFile = Join-Path $Path "package.json"

    if (Test-Path $versionFile) {
        $version = (Get-Content $versionFile -Raw).Trim()
        return $version
    }
    elseif (Test-Path $packageFile) {
        $pkg = Get-Content $packageFile -Raw | ConvertFrom-Json
        return $pkg.version
    }
    else {
        throw "No version file found in '$Path'. Expected version.txt or package.json."
    }
}

function Get-BumpType {
    param(
        [Parameter(Mandatory)][string[]]$Commits
    )

    $bumpType = "patch"

    foreach ($commit in $Commits) {
        # Check for breaking change: either ! after type or BREAKING CHANGE footer
        if ($commit -match '^[a-z]+(\([^)]+\))?!:' -or $commit -match 'BREAKING CHANGE:') {
            return "major"
        }

        if ($commit -match '^feat(\([^)]+\))?:') {
            $bumpType = "minor"
        }
        # fix stays at patch unless minor/major overrides
    }

    return $bumpType
}

function Invoke-VersionBump {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][ValidateSet("major","minor","patch")][string]$BumpType
    )

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semver '$Version'. Expected format: MAJOR.MINOR.PATCH"
    }

    [int]$major = $Matches[1]
    [int]$minor = $Matches[2]
    [int]$patch = $Matches[3]

    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
    }
}

function New-ChangelogEntry {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string[]]$Commits,
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $breaking = @()
    $features = @()
    $fixes = @()
    $others = @()

    foreach ($commit in $Commits) {
        if ($commit -match '^([a-z]+(\([^)]+\))?!):(.+)') {
            $breaking += $Matches[3].Trim()
        }
        elseif ($commit -match '^feat(\([^)]+\))?:(.+)') {
            $features += $Matches[2].Trim()
        }
        elseif ($commit -match '^fix(\([^)]+\))?:(.+)') {
            $fixes += $Matches[2].Trim()
        }
        else {
            # Strip conventional commit type prefix if present, otherwise use full message
            if ($commit -match '^[a-z]+(\([^)]+\))?:(.+)') {
                $others += $Matches[2].Trim()
            }
            else {
                $others += $commit.Trim()
            }
        }

        # Also check BREAKING CHANGE footer
        if ($commit -match 'BREAKING CHANGE:(.+)') {
            $breaking += $Matches[1].Trim()
        }
    }

    $lines = @("## [$Version] - $Date")

    if ($breaking.Count -gt 0) {
        $lines += ""
        $lines += "### Breaking Changes"
        foreach ($item in $breaking) { $lines += "- $item" }
    }

    if ($features.Count -gt 0) {
        $lines += ""
        $lines += "### Features"
        foreach ($item in $features) { $lines += "- $item" }
    }

    if ($fixes.Count -gt 0) {
        $lines += ""
        $lines += "### Bug Fixes"
        foreach ($item in $fixes) { $lines += "- $item" }
    }

    if ($others.Count -gt 0) {
        $lines += ""
        $lines += "### Other Changes"
        foreach ($item in $others) { $lines += "- $item" }
    }

    return $lines -join "`n"
}

function Set-VersionFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )

    $versionFile = Join-Path $Path "version.txt"
    $packageFile = Join-Path $Path "package.json"

    if (Test-Path $versionFile) {
        Set-Content -Path $versionFile -Value $NewVersion -NoNewline
    }
    elseif (Test-Path $packageFile) {
        $pkg = Get-Content $packageFile -Raw | ConvertFrom-Json
        $pkg.version = $NewVersion
        $pkg | ConvertTo-Json -Depth 10 | Set-Content -Path $packageFile
    }
    else {
        throw "No version file found in '$Path'. Expected version.txt or package.json."
    }
}

function Invoke-SemanticVersionBump {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Commits,
        [string]$Date = (Get-Date -Format "yyyy-MM-dd")
    )

    $currentVersion = Get-CurrentVersion -Path $Path
    $bumpType = Get-BumpType -Commits $Commits
    $newVersion = Invoke-VersionBump -Version $currentVersion -BumpType $bumpType
    $changelog = New-ChangelogEntry -Version $newVersion -Commits $Commits -Date $Date

    Set-VersionFile -Path $Path -NewVersion $newVersion

    return [PSCustomObject]@{
        OldVersion = $currentVersion
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}

