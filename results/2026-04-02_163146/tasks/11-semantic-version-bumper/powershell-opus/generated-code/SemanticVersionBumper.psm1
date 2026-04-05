# SemanticVersionBumper.psm1
# Module for semantic version bumping based on conventional commit messages.
#
# Approach:
#   1. Parse current version from a VERSION file or package.json
#   2. Parse conventional commit messages from a log
#   3. Classify each commit (feat->minor, fix->patch, breaking->major)
#   4. Determine the highest-priority bump
#   5. Compute the new version
#   6. Update the version file
#   7. Generate a changelog entry
#
# Each function was built via TDD: tests written first, then minimal implementation.

# Regex for validating a semantic version string (major.minor.patch)
$script:SemverPattern = '^\d+\.\d+\.\d+$'

# ---------------------------------------------------------------------------
# TDD Round 1: Get-VersionFromFile
# Reads a semantic version string from a plain text file (e.g., VERSION).
# ---------------------------------------------------------------------------
function Get-VersionFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Version file '$Path' does not exist."
    }

    $raw = (Get-Content -Path $Path -Raw).Trim()

    if ($raw -notmatch $script:SemverPattern) {
        throw "File '$Path' does not contain a valid semantic version. Found: '$raw'"
    }

    return $raw
}

# ---------------------------------------------------------------------------
# TDD Round 2: Get-VersionFromPackageJson
# Reads the "version" field from a package.json file.
# ---------------------------------------------------------------------------
function Get-VersionFromPackageJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Package file '$Path' does not exist."
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json

    if (-not $json.version) {
        throw "No 'version' field found in '$Path'."
    }

    $version = $json.version.Trim()

    if ($version -notmatch $script:SemverPattern) {
        throw "Package '$Path' does not contain a valid semantic version. Found: '$version'"
    }

    return $version
}

# ---------------------------------------------------------------------------
# TDD Round 3: Get-CommitType
# Classifies a single conventional commit message into a bump category.
# Returns: 'major', 'minor', 'patch', or 'none'
# ---------------------------------------------------------------------------
function Get-CommitType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    # Breaking change takes highest priority:
    # 1. Bang syntax: feat!, fix!, refactor!, etc.
    # 2. BREAKING CHANGE footer in the message
    if ($Message -match '^\w+(\(.+\))?!:' -or $Message -match 'BREAKING CHANGE') {
        return 'major'
    }

    # Feature commits -> minor bump
    if ($Message -match '^feat(\(.+\))?:') {
        return 'minor'
    }

    # Fix commits -> patch bump
    if ($Message -match '^fix(\(.+\))?:') {
        return 'patch'
    }

    # Everything else (docs, chore, style, refactor, test, ci, etc.) -> no bump
    return 'none'
}

# ---------------------------------------------------------------------------
# TDD Round 4: ConvertFrom-CommitLog
# Parses a multi-line commit log (format: "<hash> <message>") into objects.
# ---------------------------------------------------------------------------
function ConvertFrom-CommitLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$LogContent
    )

    $commits = @()

    if ([string]::IsNullOrWhiteSpace($LogContent)) {
        return $commits
    }

    # Split on newlines and process each non-empty line
    $lines = $LogContent -split "`n" | Where-Object { $_.Trim() -ne '' }

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        # First token is the hash, the rest is the commit message
        $spaceIndex = $trimmed.IndexOf(' ')
        if ($spaceIndex -gt 0) {
            $hash = $trimmed.Substring(0, $spaceIndex)
            $message = $trimmed.Substring($spaceIndex + 1)
            $commits += [PSCustomObject]@{
                Hash    = $hash
                Message = $message
            }
        }
    }

    return $commits
}

# ---------------------------------------------------------------------------
# TDD Round 5: Get-BumpType
# Determines the highest-priority bump type from a commit log.
# Priority: major > minor > patch > none
# ---------------------------------------------------------------------------
function Get-BumpType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$LogContent
    )

    if ([string]::IsNullOrWhiteSpace($LogContent)) {
        throw 'No commits provided. Cannot determine bump type.'
    }

    $commits = ConvertFrom-CommitLog -LogContent $LogContent

    if ($commits.Count -eq 0) {
        throw 'No commits provided. Cannot determine bump type.'
    }

    # Track the highest bump level seen
    $hasMajor = $false
    $hasMinor = $false
    $hasPatch = $false

    foreach ($commit in $commits) {
        $type = Get-CommitType -Message $commit.Message
        switch ($type) {
            'major' { $hasMajor = $true }
            'minor' { $hasMinor = $true }
            'patch' { $hasPatch = $true }
        }
    }

    # Return the highest priority
    if ($hasMajor) { return 'major' }
    if ($hasMinor) { return 'minor' }
    if ($hasPatch) { return 'patch' }
    return 'none'
}

# ---------------------------------------------------------------------------
# TDD Round 6: Step-SemanticVersion
# Bumps a semantic version string by the given bump type.
# ---------------------------------------------------------------------------
function Step-SemanticVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$BumpType
    )

    if ($Version -notmatch $script:SemverPattern) {
        throw "Not a valid semantic version: '$Version'"
    }

    $validTypes = @('major', 'minor', 'patch', 'none')
    if ($BumpType -notin $validTypes) {
        throw "Invalid bump type: '$BumpType'. Must be one of: $($validTypes -join ', ')"
    }

    $parts = $Version -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    switch ($BumpType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
        'none' {
            # No change
        }
    }

    return "$major.$minor.$patch"
}

# ---------------------------------------------------------------------------
# TDD Round 7: Update-VersionFile / Update-PackageJsonVersion
# Write the new version back to the appropriate file format.
# ---------------------------------------------------------------------------
function Update-VersionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Version file '$Path' does not exist."
    }

    Set-Content -Path $Path -Value $NewVersion -NoNewline
}

function Update-PackageJsonVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Package file '$Path' does not exist."
    }

    $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $json.version = $NewVersion
    $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
}

# ---------------------------------------------------------------------------
# TDD Round 8: New-ChangelogEntry
# Generates a Markdown changelog entry grouped by commit type.
# ---------------------------------------------------------------------------
function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$LogContent
    )

    $date = Get-Date -Format 'yyyy-MM-dd'
    $commits = ConvertFrom-CommitLog -LogContent $LogContent

    # Group commits by type
    $breaking = @()
    $features = @()
    $fixes = @()
    $other = @()

    foreach ($commit in $commits) {
        $type = Get-CommitType -Message $commit.Message
        switch ($type) {
            'major' { $breaking += $commit }
            'minor' { $features += $commit }
            'patch' { $fixes += $commit }
            default { $other += $commit }
        }
    }

    # Build the changelog entry
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $Version ($date)")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        foreach ($c in $breaking) {
            [void]$sb.AppendLine("- $($c.Message) ($($c.Hash))")
        }
        [void]$sb.AppendLine()
    }

    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($c in $features) {
            [void]$sb.AppendLine("- $($c.Message) ($($c.Hash))")
        }
        [void]$sb.AppendLine()
    }

    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        foreach ($c in $fixes) {
            [void]$sb.AppendLine("- $($c.Message) ($($c.Hash))")
        }
        [void]$sb.AppendLine()
    }

    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other')
        foreach ($c in $other) {
            [void]$sb.AppendLine("- $($c.Message) ($($c.Hash))")
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString().TrimEnd()
}

# ---------------------------------------------------------------------------
# TDD Round 9: Invoke-SemanticVersionBump
# Main orchestration function: reads version, analyzes commits, bumps,
# updates the file, generates changelog, and returns a result object.
# ---------------------------------------------------------------------------
function Invoke-SemanticVersionBump {
    [CmdletBinding()]
    param(
        [string]$VersionFilePath,
        [string]$PackageJsonPath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$CommitLog
    )

    # Validate that at least one version source is provided
    if ([string]::IsNullOrWhiteSpace($VersionFilePath) -and [string]::IsNullOrWhiteSpace($PackageJsonPath)) {
        throw 'You must provide either a version file path (-VersionFilePath) or a package.json path (-PackageJsonPath).'
    }

    # Determine bump type from commits (also validates non-empty log)
    $bumpType = Get-BumpType -LogContent $CommitLog

    # Read current version from the appropriate source
    if (-not [string]::IsNullOrWhiteSpace($VersionFilePath)) {
        $oldVersion = Get-VersionFromFile -Path $VersionFilePath
    }
    else {
        $oldVersion = Get-VersionFromPackageJson -Path $PackageJsonPath
    }

    # Compute the new version
    $newVersion = Step-SemanticVersion -Version $oldVersion -BumpType $bumpType

    # Update the file on disk (only if version actually changed)
    if ($bumpType -ne 'none') {
        if (-not [string]::IsNullOrWhiteSpace($VersionFilePath)) {
            Update-VersionFile -Path $VersionFilePath -NewVersion $newVersion
        }
        else {
            Update-PackageJsonVersion -Path $PackageJsonPath -NewVersion $newVersion
        }
    }

    # Generate changelog
    $changelog = New-ChangelogEntry -Version $newVersion -LogContent $CommitLog

    # Log the new version to the host (does not pollute pipeline output)
    Write-Host "New version: $newVersion"

    # Return a structured result object
    return [PSCustomObject]@{
        OldVersion = $oldVersion
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}

# Export all public functions
Export-ModuleMember -Function @(
    'Get-VersionFromFile'
    'Get-VersionFromPackageJson'
    'Get-CommitType'
    'ConvertFrom-CommitLog'
    'Get-BumpType'
    'Step-SemanticVersion'
    'Update-VersionFile'
    'Update-PackageJsonVersion'
    'New-ChangelogEntry'
    'Invoke-SemanticVersionBump'
)
