Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Semantic Version Bumper
# Parses version files, determines bump type from conventional commits,
# updates the version, and generates changelog entries.

function Get-SemanticVersion {
    <#
    .SYNOPSIS
        Parses a semantic version from a VERSION file or package.json.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File not found: $FilePath"
    }

    [string]$raw = Get-Content -LiteralPath $FilePath -Raw

    # Detect package.json by extension
    if ($FilePath -match '\.json$') {
        [PSCustomObject]$json = $raw | ConvertFrom-Json
        [string]$versionString = [string]$json.version
    }
    else {
        [string]$versionString = $raw.Trim()
    }

    # Validate semantic version pattern: MAJOR.MINOR.PATCH
    if ($versionString -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semantic version: '$versionString'"
    }

    [string[]]$parts = $versionString -split '\.'
    [hashtable]$result = @{
        Major = [int]$parts[0]
        Minor = [int]$parts[1]
        Patch = [int]$parts[2]
    }
    return $result
}

function Get-BumpType {
    <#
    .SYNOPSIS
        Analyzes conventional commit messages and returns the bump type:
        'major', 'minor', 'patch', or 'none'.
    .DESCRIPTION
        Conventional commit rules:
        - "BREAKING CHANGE:" footer or "!" after type  -> major
        - "feat:" or "feat(scope):"                    -> minor
        - "fix:" or "fix(scope):"                      -> patch
        The highest-priority bump wins.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CommitMessages
    )

    [bool]$hasBreaking = $false
    [bool]$hasFeat = $false
    [bool]$hasFix = $false

    foreach ($msg in $CommitMessages) {
        [string]$line = $msg.Trim()
        if ($line -eq '') { continue }

        # Check for BREAKING CHANGE footer anywhere in the message
        if ($line -match 'BREAKING CHANGE:') {
            $hasBreaking = $true
            continue
        }

        # Check for breaking change indicator: type! or type(scope)!
        if ($line -match '^\w+(\(.+\))?!:') {
            $hasBreaking = $true
            continue
        }

        # Check for feat commits
        if ($line -match '^feat(\(.+\))?:') {
            $hasFeat = $true
            continue
        }

        # Check for fix commits
        if ($line -match '^fix(\(.+\))?:') {
            $hasFix = $true
            continue
        }
    }

    # Return highest priority bump
    if ($hasBreaking) { return 'major' }
    if ($hasFeat)     { return 'minor' }
    if ($hasFix)      { return 'patch' }
    return 'none'
}

function Update-SemanticVersion {
    <#
    .SYNOPSIS
        Applies a bump type to a version hashtable and returns the new version.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Version,

        [Parameter(Mandatory)]
        [string]$BumpType
    )

    [hashtable]$new = @{
        Major = [int]$Version.Major
        Minor = [int]$Version.Minor
        Patch = [int]$Version.Patch
    }

    switch ($BumpType) {
        'major' {
            $new.Major = [int]$new.Major + 1
            $new.Minor = [int]0
            $new.Patch = [int]0
        }
        'minor' {
            $new.Minor = [int]$new.Minor + 1
            $new.Patch = [int]0
        }
        'patch' {
            $new.Patch = [int]$new.Patch + 1
        }
        'none' {
            # No change
        }
        default {
            throw "Invalid bump type: '$BumpType'. Expected major, minor, patch, or none."
        }
    }

    return $new
}

function Set-SemanticVersion {
    <#
    .SYNOPSIS
        Writes a version hashtable back to a VERSION file or package.json.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [hashtable]$Version
    )

    [string]$versionString = "$([int]$Version.Major).$([int]$Version.Minor).$([int]$Version.Patch)"

    if ($FilePath -match '\.json$') {
        # Preserve existing JSON fields; only update version
        [string]$raw = Get-Content -LiteralPath $FilePath -Raw
        [PSCustomObject]$json = $raw | ConvertFrom-Json
        $json.version = $versionString
        [string]$output = $json | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $FilePath -Value $output -NoNewline
    }
    else {
        Set-Content -LiteralPath $FilePath -Value $versionString -NoNewline
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Generates a markdown changelog entry grouped by commit type.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$CommitMessages
    )

    # Filter out blank lines
    [string[]]$filtered = @($CommitMessages | Where-Object { $_.Trim() -ne '' })
    if ($filtered.Count -eq 0) {
        return [string]''
    }

    # Categorize commits into sections
    [System.Collections.ArrayList]$breaking = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$features = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$fixes    = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$other    = [System.Collections.ArrayList]::new()

    foreach ($msg in $filtered) {
        [string]$line = $msg.Trim()

        # Breaking change via ! marker
        if ($line -match '^\w+(\(.+\))?!:\s*(.+)$') {
            [void]$breaking.Add([string]$Matches[2])
            continue
        }

        # BREAKING CHANGE footer line (not a commit subject — add as-is)
        if ($line -match '^BREAKING CHANGE:\s*(.+)$') {
            [void]$breaking.Add([string]$Matches[1])
            continue
        }

        # feat commits
        if ($line -match '^feat(\(.+\))?:\s*(.+)$') {
            [void]$features.Add([string]$Matches[2])
            continue
        }

        # fix commits
        if ($line -match '^fix(\(.+\))?:\s*(.+)$') {
            [void]$fixes.Add([string]$Matches[2])
            continue
        }

        # Everything else (docs, chore, etc.)
        if ($line -match '^\w+(\(.+\))?:\s*(.+)$') {
            [void]$other.Add([string]$Matches[2])
            continue
        }
        else {
            [void]$other.Add($line)
        }
    }

    # Build the markdown entry
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## $Version")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($item in $breaking) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine()
    }

    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($item in $features) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine()
    }

    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        foreach ($item in $fixes) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine()
    }

    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other')
        foreach ($item in $other) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString().TrimEnd()
}

function Invoke-VersionBump {
    <#
    .SYNOPSIS
        Orchestrates the full version bump workflow:
        read version, analyze commits, bump, write back, generate changelog.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFilePath,

        [Parameter(Mandatory)]
        [string]$CommitLogPath
    )

    # 1. Read current version
    [hashtable]$currentVersion = Get-SemanticVersion -FilePath $VersionFilePath
    [string]$oldVersionStr = "$([int]$currentVersion.Major).$([int]$currentVersion.Minor).$([int]$currentVersion.Patch)"

    # 2. Read commit messages from the log file
    [string[]]$allLines = Get-Content -LiteralPath $CommitLogPath
    [string[]]$commitMessages = @($allLines | Where-Object { $_.Trim() -ne '' })

    # 3. Determine bump type
    [string]$bumpType = Get-BumpType -CommitMessages $commitMessages

    # 4. Compute new version
    [hashtable]$newVersion = Update-SemanticVersion -Version $currentVersion -BumpType $bumpType
    [string]$newVersionStr = "$([int]$newVersion.Major).$([int]$newVersion.Minor).$([int]$newVersion.Patch)"

    # 5. Write updated version back to file (only if there's an actual change)
    if ($bumpType -ne 'none') {
        Set-SemanticVersion -FilePath $VersionFilePath -Version $newVersion
    }

    # 6. Generate changelog entry
    [string]$changelog = New-ChangelogEntry -Version $newVersionStr -CommitMessages $commitMessages

    # 7. Output summary
    Write-Host "Version bump: $oldVersionStr -> $newVersionStr ($bumpType)"

    [hashtable]$result = @{
        OldVersion = [string]$oldVersionStr
        NewVersion = [string]$newVersionStr
        BumpType   = [string]$bumpType
        Changelog  = [string]$changelog
    }
    return $result
}
