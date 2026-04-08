# SemanticVersionBumper.ps1
# Semantic version bumper: parses versions, determines bump type from
# conventional commits, updates version files, and generates changelogs.
#
# Approach:
#   1. Get-SemanticVersion   - reads current version from VERSION or package.json
#   2. Get-BumpType          - analyzes conventional commit messages to determine bump type
#   3. Step-Version          - computes the next version given a bump type
#   4. New-ChangelogEntry    - generates markdown changelog from commits
#   5. Update-VersionFile    - writes the new version back to the file
#   6. Invoke-VersionBump    - orchestrates the full pipeline

function Get-SemanticVersion {
    # Reads a semantic version string from a VERSION file or package.json.
    # Supports plain text VERSION files and JSON package.json files.
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw

    # Match semver pattern (major.minor.patch)
    if ($content -match '(\d+\.\d+\.\d+)') {
        return $Matches[1]
    }

    throw "No valid semantic version found in $Path"
}

function Get-BumpType {
    # Analyzes conventional commit messages and returns the appropriate bump type.
    # Priority: major (breaking) > minor (feat) > patch (fix/default)
    param(
        [string[]]$CommitMessages = @()
    )

    $bumpType = 'patch'

    foreach ($msg in $CommitMessages) {
        # Check for breaking changes first (highest priority)
        if ($msg -match 'BREAKING CHANGE' -or $msg -match '\w+!:') {
            return 'major'
        }
        # Check for features (second priority)
        if ($msg -match '^\w+\s+feat[\(:]') {
            $bumpType = 'minor'
        }
    }

    return $bumpType
}

function Step-Version {
    # Bumps a semantic version string by the given type.
    # Resets lower components: minor bump resets patch, major resets both.
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$BumpType
    )

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "Invalid semantic version: $Version"
    }

    [int]$major = $Matches[1]
    [int]$minor = $Matches[2]
    [int]$patch = $Matches[3]

    switch ($BumpType) {
        'major' { $major++; $minor = 0; $patch = 0 }
        'minor' { $minor++; $patch = 0 }
        'patch' { $patch++ }
    }

    return "$major.$minor.$patch"
}

function New-ChangelogEntry {
    # Generates a markdown changelog entry grouped by commit type.
    # Recognizes: feat -> Features, fix -> Bug Fixes, breaking -> BREAKING CHANGES.
    # Other types go into "Other Changes".
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [string[]]$CommitMessages = @()
    )

    $date = Get-Date -Format 'yyyy-MM-dd'
    $lines = @("## $Version ($date)")
    $lines += ''

    if ($CommitMessages.Count -eq 0) {
        $lines += 'No notable changes.'
        return ($lines -join "`n")
    }

    # Categorize commits
    $features = @()
    $fixes = @()
    $breaking = @()
    $other = @()

    foreach ($msg in $CommitMessages) {
        # Strip the short hash prefix (e.g., "abc1234 ")
        $text = $msg -replace '^\w+\s+', ''

        if ($msg -match 'BREAKING CHANGE' -or $msg -match '\w+!:') {
            $breaking += $text
        }
        elseif ($text -match '^feat[\(:]') {
            $features += ($text -replace '^feat[\(:][\)]?\s*:?\s*', '')
        }
        elseif ($text -match '^fix[\(:]') {
            $fixes += ($text -replace '^fix[\(:][\)]?\s*:?\s*', '')
        }
        else {
            $other += $text
        }
    }

    if ($breaking.Count -gt 0) {
        $lines += '### BREAKING CHANGES'
        foreach ($item in $breaking) { $lines += "- $item" }
        $lines += ''
    }

    if ($features.Count -gt 0) {
        $lines += '### Features'
        foreach ($item in $features) { $lines += "- $item" }
        $lines += ''
    }

    if ($fixes.Count -gt 0) {
        $lines += '### Bug Fixes'
        foreach ($item in $fixes) { $lines += "- $item" }
        $lines += ''
    }

    if ($other.Count -gt 0) {
        $lines += '### Other Changes'
        foreach ($item in $other) { $lines += "- $item" }
        $lines += ''
    }

    return ($lines -join "`n")
}

function Update-VersionFile {
    # Writes a new version to a VERSION file or package.json.
    # For package.json, updates the "version" field in-place.
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    $fileName = Split-Path -Leaf $Path

    if ($fileName -eq 'package.json') {
        # Update version in JSON while preserving other fields
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -NoNewline
    }
    else {
        # Plain text VERSION file
        Set-Content -Path $Path -Value $NewVersion -NoNewline
    }
}

function Invoke-VersionBump {
    # Full integration: reads version, determines bump, updates file, generates changelog.
    # Returns the new version string.
    param(
        [Parameter(Mandatory)]
        [string]$VersionFilePath,

        [string[]]$CommitMessages = @(),

        [string]$ChangelogPath = ''
    )

    # 1. Read current version
    $currentVersion = Get-SemanticVersion -Path $VersionFilePath

    # 2. Determine bump type from commits
    $bumpType = Get-BumpType -CommitMessages $CommitMessages

    # 3. Compute new version
    $newVersion = Step-Version -Version $currentVersion -BumpType $bumpType

    # 4. Update the version file
    Update-VersionFile -Path $VersionFilePath -NewVersion $newVersion

    # 5. Generate changelog entry
    if ($ChangelogPath) {
        $entry = New-ChangelogEntry -Version $newVersion -CommitMessages $CommitMessages

        if (Test-Path $ChangelogPath) {
            # Insert new entry after the "# Changelog" header
            $existing = Get-Content -Path $ChangelogPath -Raw
            $newContent = $existing -replace '(# Changelog\s*\n)', "`$1`n$entry`n"
            # If there was no header, just prepend
            if ($newContent -eq $existing) {
                $newContent = "# Changelog`n`n$entry`n`n$existing"
            }
            Set-Content -Path $ChangelogPath -Value $newContent -NoNewline
        }
        else {
            $content = "# Changelog`n`n$entry`n"
            Set-Content -Path $ChangelogPath -Value $content -NoNewline
        }
    }

    Write-Host "Bumped version: $currentVersion -> $newVersion ($bumpType)"
    return $newVersion
}
