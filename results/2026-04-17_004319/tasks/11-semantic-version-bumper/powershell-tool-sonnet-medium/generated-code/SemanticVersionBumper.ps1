# Semantic Version Bumper
# Parses version files, determines next version from conventional commits,
# updates the version file, and generates a CHANGELOG entry.

function Get-CurrentVersion {
    param(
        [Parameter(Mandatory)][string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Version file not found: $FilePath"
    }

    $content = Get-Content $FilePath -Raw

    if ($FilePath -match '\.json$') {
        try {
            $json = $content | ConvertFrom-Json
        } catch {
            throw "Failed to parse JSON from: $FilePath"
        }
        if (-not $json.version) {
            throw "No 'version' field found in $FilePath"
        }
        $version = $json.version
    } else {
        $version = $content.Trim()
    }

    if ($version -notmatch '^\d+\.\d+\.\d+') {
        throw "Invalid version format '$version' in $FilePath"
    }

    return $version
}

function Get-BumpType {
    param(
        [string[]]$Commits
    )

    $bumpType = 'patch'

    foreach ($commit in $Commits) {
        # BREAKING CHANGE: footer or ! after type indicates major
        if ($commit -match '(?m)^BREAKING CHANGE:' -or $commit -match '^[a-z]+(\(.+\))?!:') {
            return 'major'
        }
        # feat commits indicate minor (unless overridden to major)
        if ($commit -match '^feat(\(.+\))?:') {
            $bumpType = 'minor'
        }
    }

    return $bumpType
}

function Get-NextVersion {
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][string]$BumpType
    )

    if ($CurrentVersion -notmatch '^(\d+)\.(\d+)\.(\d+)') {
        throw "Invalid version format: $CurrentVersion"
    }

    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]

    switch ($BumpType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
        default { throw "Invalid bump type: $BumpType. Must be major, minor, or patch." }
    }

    return "$major.$minor.$patch"
}

function New-ChangelogEntry {
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string[]]$Commits,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $lines = @("## [$Version] - $Date", "")

    $breaking = $Commits | Where-Object { $_ -match '(?m)^BREAKING CHANGE:' -or $_ -match '^[a-z]+(\(.+\))?!:' }
    $features = $Commits | Where-Object { $_ -match '^feat(\(.+\))?:' -and $_ -notmatch '^[a-z]+(\(.+\))?!:' }
    $fixes    = $Commits | Where-Object { $_ -match '^fix(\(.+\))?:'  -and $_ -notmatch '^[a-z]+(\(.+\))?!:' }

    if ($breaking) {
        $lines += "### Breaking Changes"
        $breaking | ForEach-Object { $lines += "- $_" }
        $lines += ""
    }
    if ($features) {
        $lines += "### Features"
        $features | ForEach-Object { $lines += "- $_" }
        $lines += ""
    }
    if ($fixes) {
        $lines += "### Bug Fixes"
        $fixes | ForEach-Object { $lines += "- $_" }
        $lines += ""
    }

    return $lines -join "`n"
}

function Update-VersionFile {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string]$Version
    )

    if ($FilePath -match '\.json$') {
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json
        $json.version = $Version
        # Preserve formatting with depth and indentation
        $json | ConvertTo-Json -Depth 10 | Set-Content $FilePath -NoNewline
    } else {
        Set-Content $FilePath $Version -NoNewline
    }
}

function Invoke-SemanticVersionBump {
    <#
    .SYNOPSIS
        Bumps the version in a version file based on conventional commit messages.
    .PARAMETER VersionFile
        Path to version.txt or package.json.
    .PARAMETER Commits
        Array of conventional commit message strings.
    .OUTPUTS
        The new version string (also writes back to VersionFile and creates CHANGELOG.md).
    #>
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string[]]$Commits
    )

    $currentVersion = Get-CurrentVersion -FilePath $VersionFile
    $bumpType       = Get-BumpType -Commits $Commits
    $newVersion     = Get-NextVersion -CurrentVersion $currentVersion -BumpType $bumpType

    Update-VersionFile -FilePath $VersionFile -Version $newVersion

    $changelogEntry = New-ChangelogEntry -Version $newVersion -Commits $Commits
    $changelogPath  = Join-Path (Split-Path $VersionFile -Parent) "CHANGELOG.md"

    if (Test-Path $changelogPath) {
        $existing = Get-Content $changelogPath -Raw
        Set-Content $changelogPath "$changelogEntry`n$existing" -NoNewline
    } else {
        Set-Content $changelogPath "# Changelog`n`n$changelogEntry" -NoNewline
    }

    return $newVersion
}
