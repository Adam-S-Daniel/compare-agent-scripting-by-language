# SemanticVersionBumper.ps1
# Semantic version bumper — parses, bumps, and generates changelogs from conventional commits.
# Supports VERSION files (plain text) and package.json.

function Get-SemanticVersion {
    # Parse a semantic version (major.minor.patch) from a VERSION file or package.json.
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Version file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw
    if ($content -match '(\d+)\.(\d+)\.(\d+)') {
        return [PSCustomObject]@{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
        }
    }
    throw "No valid semantic version found in: $Path"
}

function Get-BumpType {
    # Determine the bump type from conventional commit messages.
    # Breaking changes (! suffix or BREAKING CHANGE text) -> major
    # feat commits -> minor
    # Everything else -> patch
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CommitMessages
    )

    if ($CommitMessages.Count -eq 0) {
        throw "No commit messages provided"
    }

    $hasBreaking = $false
    $hasFeat = $false

    foreach ($msg in $CommitMessages) {
        if ($msg -match '^\w+!:' -or $msg -match 'BREAKING CHANGE') {
            $hasBreaking = $true
            break
        }
        if ($msg -match '^feat[\(:]') {
            $hasFeat = $true
        }
    }

    if ($hasBreaking) { return 'major' }
    if ($hasFeat)     { return 'minor' }
    return 'patch'
}

function Invoke-VersionBump {
    # Apply a bump type to a parsed version and return the new version string.
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Version,

        [Parameter(Mandatory)]
        [string]$BumpType
    )

    switch ($BumpType) {
        'major' { return "$([int]$Version.Major + 1).0.0" }
        'minor' { return "$($Version.Major).$([int]$Version.Minor + 1).0" }
        'patch' { return "$($Version.Major).$($Version.Minor).$([int]$Version.Patch + 1)" }
        default { throw "Invalid bump type: $BumpType. Must be major, minor, or patch." }
    }
}

function Update-VersionFile {
    # Write the new version back to the file.
    # For package.json, update the "version" field in-place; for plain files, overwrite content.
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if ($Path -match '\.json$') {
        # Update the version field in JSON while preserving other fields
        $json = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $json.version = $NewVersion
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -NoNewline
    }
    else {
        Set-Content -Path $Path -Value $NewVersion -NoNewline
    }
}

function New-ChangelogEntry {
    # Generate a markdown changelog entry from commit messages, grouped by type.
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string[]]$CommitMessages
    )

    # Categorize commits by conventional type
    $features = @()
    $fixes = @()
    $other = @()

    foreach ($msg in $CommitMessages) {
        if ($msg -match '^feat[\(!:]') {
            # Extract the description after "feat: " or "feat!: " or "feat(scope): "
            $desc = $msg -replace '^feat[^:]*:\s*', ''
            $features += $desc
        }
        elseif ($msg -match '^fix[\(!:]') {
            $desc = $msg -replace '^fix[^:]*:\s*', ''
            $fixes += $desc
        }
        else {
            # Strip type prefix if present (e.g., "chore: update deps" -> "update deps")
            $desc = $msg -replace '^\w+[^:]*:\s*', ''
            $other += $desc
        }
    }

    # Build markdown output, only including non-empty sections
    $lines = @("## $Version", "")

    if ($features.Count -gt 0) {
        $lines += '### Features'
        foreach ($f in $features) { $lines += "- $f" }
        $lines += ''
    }

    if ($fixes.Count -gt 0) {
        $lines += '### Bug Fixes'
        foreach ($f in $fixes) { $lines += "- $f" }
        $lines += ''
    }

    if ($other.Count -gt 0) {
        $lines += '### Other'
        foreach ($o in $other) { $lines += "- $o" }
        $lines += ''
    }

    return ($lines -join "`n")
}

function Invoke-SemanticVersionBump {
    # Main orchestrator: reads version, determines bump from commits, updates file, generates changelog.
    param(
        [Parameter(Mandatory)]
        [string]$VersionFilePath,

        [Parameter(Mandatory)]
        [string]$CommitLogPath
    )

    if (-not (Test-Path $CommitLogPath)) {
        throw "Commit log file not found: $CommitLogPath"
    }

    # Read commit messages from file (one per line, skip empty lines)
    $commits = Get-Content -Path $CommitLogPath | Where-Object { $_.Trim() -ne '' }
    if (-not $commits -or $commits.Count -eq 0) {
        throw "No commit messages found in: $CommitLogPath"
    }

    # Step 1: Parse current version
    $currentVersion = Get-SemanticVersion -Path $VersionFilePath
    $oldVersionStr = "$($currentVersion.Major).$($currentVersion.Minor).$($currentVersion.Patch)"

    # Step 2: Determine bump type from commit messages
    $bumpType = Get-BumpType -CommitMessages $commits

    # Step 3: Calculate new version
    $newVersion = Invoke-VersionBump -Version $currentVersion -BumpType $bumpType

    # Step 4: Update the version file
    Update-VersionFile -Path $VersionFilePath -NewVersion $newVersion

    # Step 5: Generate changelog entry
    $changelog = New-ChangelogEntry -Version $newVersion -CommitMessages $commits

    # Output the new version to the console
    Write-Host "Version bumped: $oldVersionStr -> $newVersion ($bumpType)"

    return [PSCustomObject]@{
        OldVersion = $oldVersionStr
        NewVersion = $newVersion
        BumpType   = $bumpType
        Changelog  = $changelog
    }
}
