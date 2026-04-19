# Semantic Version Bumper
# Parses version, determines next version based on conventional commits, updates files, generates changelog

function Get-CurrentVersion {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return $content.version
}

function Get-NextVersion {
    param(
        [string]$CurrentVersion,
        [string[]]$Commits
    )

    # Parse current version
    $versionParts = $CurrentVersion -split '\.'
    [int]$major = $versionParts[0]
    [int]$minor = $versionParts[1]
    [int]$patch = $versionParts[2]

    # Determine bump type from commits
    $bumpType = "none"
    foreach ($commit in $Commits) {
        if ($commit -match "^breaking|BREAKING\s+CHANGE") {
            $bumpType = "major"
            break
        }
    }

    if ($bumpType -ne "major") {
        foreach ($commit in $Commits) {
            if ($commit -match "^feat") {
                $bumpType = "minor"
                break
            }
        }
    }

    if ($bumpType -eq "none") {
        foreach ($commit in $Commits) {
            if ($commit -match "^fix") {
                $bumpType = "patch"
                break
            }
        }
    }

    # Apply bump
    switch ($bumpType) {
        "major" {
            $major++
            $minor = 0
            $patch = 0
        }
        "minor" {
            $minor++
            $patch = 0
        }
        "patch" {
            $patch++
        }
    }

    return "$major.$minor.$patch"
}

function Update-VersionFile {
    param(
        [string]$Path,
        [string]$NewVersion
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $content.version = $NewVersion
    $content | ConvertTo-Json | Set-Content -Path $Path
}

function Get-Changelog {
    param(
        [string]$Version,
        [string[]]$Commits
    )

    $changelogLines = @("## [$Version] - $(Get-Date -Format 'yyyy-MM-dd')")

    $features = $Commits | Where-Object { $_ -match "^feat:" } | ForEach-Object { $_ -replace "^feat:\s*", "" }
    $fixes = $Commits | Where-Object { $_ -match "^fix:" } | ForEach-Object { $_ -replace "^fix:\s*", "" }
    $breaking = $Commits | Where-Object { $_ -match "BREAKING\s+CHANGE" }

    if ($breaking.Count -gt 0) {
        $changelogLines += ""
        $changelogLines += "### ⚠️ BREAKING CHANGES"
        foreach ($b in $breaking) {
            $changelogLines += "- $b"
        }
    }

    if ($features.Count -gt 0) {
        $changelogLines += ""
        $changelogLines += "### Features"
        foreach ($f in $features) {
            $changelogLines += "- $f"
        }
    }

    if ($fixes.Count -gt 0) {
        $changelogLines += ""
        $changelogLines += "### Bug Fixes"
        foreach ($fix in $fixes) {
            $changelogLines += "- $fix"
        }
    }

    return $changelogLines -join "`n"
}

function Update-SemanticVersion {
    param(
        [string]$PackagePath,
        [string]$ChangelogPath,
        [string[]]$Commits
    )

    # Get current version
    $currentVersion = Get-CurrentVersion -Path $PackagePath

    # Calculate next version
    $nextVersion = Get-NextVersion -CurrentVersion $currentVersion -Commits $Commits

    # Update package file
    Update-VersionFile -Path $PackagePath -NewVersion $nextVersion

    # Generate and save changelog
    $changelog = Get-Changelog -Version $nextVersion -Commits $Commits
    if (Test-Path $ChangelogPath) {
        $existing = Get-Content -Path $ChangelogPath -Raw
        $changelog = "$changelog`n`n$existing"
    }
    Set-Content -Path $ChangelogPath -Value $changelog

    return @{
        PreviousVersion = $currentVersion
        NewVersion = $nextVersion
        Changelog = $changelog
    }
}
