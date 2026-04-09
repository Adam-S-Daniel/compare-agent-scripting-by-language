# SemanticVersionBumper.ps1
# Functions for parsing, bumping, and managing semantic versions
# based on conventional commit messages.

# --- Version Parsing ---

function ConvertFrom-SemanticVersion {
    # Parses a semver string (e.g. "1.2.3" or "v1.2.3") into a hashtable
    # with Major, Minor, Patch integer keys.
    param(
        [Parameter(Mandatory)][string]$Version
    )

    if ($Version -match '^v?(\d+)\.(\d+)\.(\d+)$') {
        return @{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
        }
    }
    throw "Invalid semantic version: '$Version'"
}

# --- Commit Classification ---

function Get-ConventionalCommitType {
    # Classifies a single conventional commit message into a bump type:
    # 'major' (breaking), 'minor' (feat), 'patch' (fix), or 'none'.
    param(
        [Parameter(Mandatory)][string]$Message
    )

    # Breaking changes take highest priority
    if ($Message -match '^BREAKING CHANGE:' -or $Message -match '^\w+(\(.+\))?!:') {
        return 'major'
    }
    if ($Message -match '^feat(\(.+\))?:') {
        return 'minor'
    }
    if ($Message -match '^fix(\(.+\))?:') {
        return 'patch'
    }
    return 'none'
}

function Get-BumpTypeFromCommits {
    # Analyzes a list of commit messages and returns the highest-priority bump type.
    # Priority: major > minor > patch > none.
    param(
        [string[]]$Commits
    )

    $highest = 'none'
    foreach ($msg in $Commits) {
        $trimmed = $msg.Trim()
        if (-not $trimmed) { continue }

        $type = Get-ConventionalCommitType $trimmed
        switch ($type) {
            'major' { return 'major' }  # Short-circuit: can't go higher
            'minor' { $highest = 'minor' }
            'patch' { if ($highest -eq 'none') { $highest = 'patch' } }
        }
    }
    return $highest
}

# --- Version Bumping ---

function Step-SemanticVersion {
    # Given a version string and a bump type, returns the new version string.
    # Follows semver rules: major resets minor+patch, minor resets patch.
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$BumpType
    )

    $v = ConvertFrom-SemanticVersion $Version

    switch ($BumpType) {
        'major' {
            $v.Major++
            $v.Minor = 0
            $v.Patch = 0
        }
        'minor' {
            $v.Minor++
            $v.Patch = 0
        }
        'patch' {
            $v.Patch++
        }
        'none' {
            # No change
        }
        default {
            throw "Invalid bump type: '$BumpType'. Must be major, minor, patch, or none."
        }
    }

    return "$($v.Major).$($v.Minor).$($v.Patch)"
}

# --- File I/O ---

function Read-VersionFile {
    # Reads a version string from either a plain text VERSION file
    # or from the "version" field of a package.json file.
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: '$Path'"
    }

    if ($Path -match '\.json$') {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        if (-not $json.version) {
            throw "No 'version' field found in '$Path'"
        }
        return $json.version.Trim()
    }

    # Plain text file — just read and trim
    return (Get-Content $Path -Raw).Trim()
}

function Write-VersionFile {
    # Writes a new version string to a VERSION file or package.json.
    # For package.json, preserves all other fields.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$NewVersion
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: '$Path'"
    }

    if ($Path -match '\.json$') {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content $Path
    } else {
        Set-Content -Path $Path -Value $NewVersion -NoNewline
    }
}

# --- Changelog Generation ---

function New-ChangelogEntry {
    # Generates a markdown changelog entry grouped by conventional commit type.
    # Sections: BREAKING CHANGES, Features, Bug Fixes, Other.
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string[]]$Commits
    )

    $breaking = [System.Collections.Generic.List[string]]::new()
    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()
    $other    = [System.Collections.Generic.List[string]]::new()

    foreach ($msg in $Commits) {
        $trimmed = $msg.Trim()
        if (-not $trimmed) { continue }

        # Extract the description after the type prefix
        $description = $trimmed -replace '^\w+(\(.+?\))?!?:\s*', ''

        if ($trimmed -match '^BREAKING CHANGE:' -or $trimmed -match '^\w+(\(.+\))?!:') {
            $breaking.Add($description)
        } elseif ($trimmed -match '^feat(\(.+\))?:') {
            $features.Add($description)
        } elseif ($trimmed -match '^fix(\(.+\))?:') {
            $fixes.Add($description)
        } else {
            $other.Add($description)
        }
    }

    $date = Get-Date -Format 'yyyy-MM-dd'
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## $Version ($date)")
    $lines.Add('')

    if ($breaking.Count -gt 0) {
        $lines.Add('### BREAKING CHANGES')
        $lines.Add('')
        foreach ($item in $breaking) { $lines.Add("- $item") }
        $lines.Add('')
    }
    if ($features.Count -gt 0) {
        $lines.Add('### Features')
        $lines.Add('')
        foreach ($item in $features) { $lines.Add("- $item") }
        $lines.Add('')
    }
    if ($fixes.Count -gt 0) {
        $lines.Add('### Bug Fixes')
        $lines.Add('')
        foreach ($item in $fixes) { $lines.Add("- $item") }
        $lines.Add('')
    }
    if ($other.Count -gt 0) {
        $lines.Add('### Other')
        $lines.Add('')
        foreach ($item in $other) { $lines.Add("- $item") }
        $lines.Add('')
    }

    return ($lines -join "`n")
}

# --- Integration / Orchestration ---

function Invoke-SemanticVersionBump {
    # Main entry point: reads the current version from a file, analyzes
    # commit messages to determine the bump type, bumps the version,
    # writes it back, and generates a changelog entry.
    # Returns a result object with OldVersion, NewVersion, BumpType, Changelog.
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitLogFile
    )

    if (-not (Test-Path $CommitLogFile)) {
        throw "Commit log file not found: '$CommitLogFile'"
    }

    # Read current version
    $oldVersion = Read-VersionFile -Path $VersionFile

    # Read and analyze commits
    $commits = @(Get-Content $CommitLogFile | Where-Object { $_.Trim() -ne '' })
    $bumpType = Get-BumpTypeFromCommits $commits

    # Bump the version
    $newVersion = Step-SemanticVersion $oldVersion $bumpType

    # Write updated version back (only if it changed)
    if ($newVersion -ne $oldVersion) {
        Write-VersionFile -Path $VersionFile -NewVersion $newVersion
    }

    # Generate changelog
    $changelog = New-ChangelogEntry -Version $newVersion -Commits $commits

    return [PSCustomObject]@{
        OldVersion = $oldVersion
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}
