Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# SemVerBumper Module
# =============================================================================
# Parses version files (version.txt or package.json), determines the next
# semantic version based on conventional commit messages, updates the version
# file, and generates a changelog entry.
#
# Conventional Commit Rules:
#   - fix: -> patch bump
#   - feat: -> minor bump
#   - feat!: / fix!: / BREAKING CHANGE -> major bump
#   - No feat/fix -> no bump
# =============================================================================

function Get-SemanticVersion {
    <#
    .SYNOPSIS
        Parses a semantic version from a version.txt or package.json file.
    .DESCRIPTION
        Reads the specified file and extracts a semantic version string.
        For .json files, reads the "version" field. For other files, reads
        the first line as the version string.
    .OUTPUTS
        PSCustomObject with Major, Minor, Patch, and Raw properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file '$Path' does not exist."
    }

    [string]$versionString = ''

    # Determine file type and extract version string accordingly
    if ($Path -match '\.json$') {
        # Parse JSON and extract version field
        [string]$rawContent = Get-Content -Path $Path -Raw
        $jsonObj = $rawContent | ConvertFrom-Json
        $versionString = [string]$jsonObj.version
    }
    else {
        # Plain text file: first non-empty line is the version
        [string[]]$lines = Get-Content -Path $Path
        foreach ($line in $lines) {
            [string]$trimmed = $line.Trim()
            if ($trimmed.Length -gt 0) {
                $versionString = $trimmed
                break
            }
        }
    }

    # Validate the version string matches semver pattern
    if ($versionString -notmatch '^\d+\.\d+\.\d+$') {
        throw "File '$Path' does not contain a valid semantic version. Found: '$versionString'"
    }

    # Split into components
    [string[]]$parts = $versionString.Split('.')
    [int]$major = [int]$parts[0]
    [int]$minor = [int]$parts[1]
    [int]$patch = [int]$parts[2]

    return [PSCustomObject]@{
        Major = $major
        Minor = $minor
        Patch = $patch
        Raw   = $versionString
    }
}

function Get-CommitMessages {
    <#
    .SYNOPSIS
        Reads commit messages from a text file (one per line).
    .DESCRIPTION
        Reads the specified file and returns an array of non-empty commit
        message strings, suitable for passing to Get-BumpType.
    .OUTPUTS
        Array of strings representing commit messages.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commit log file '$Path' does not exist."
    }

    [string[]]$allLines = Get-Content -Path $Path
    [System.Collections.Generic.List[string]]$messages = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $allLines) {
        [string]$trimmed = $line.Trim()
        if ($trimmed.Length -gt 0) {
            $messages.Add($trimmed)
        }
    }

    return [string[]]$messages.ToArray()
}

function Get-BumpType {
    <#
    .SYNOPSIS
        Determines the version bump type from conventional commit messages.
    .DESCRIPTION
        Analyzes an array of conventional commit messages and returns the
        highest-priority bump type:
          Major > Minor > Patch > None
        Breaking changes (feat!, fix!, BREAKING CHANGE) -> Major
        feat: -> Minor
        fix: -> Patch
        Anything else -> None
    .OUTPUTS
        A string: 'Major', 'Minor', 'Patch', or 'None'.
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
        [string]$message = $msg.Trim()

        # Check for breaking changes: bang syntax (feat!:, fix!:, etc.) or BREAKING CHANGE footer
        if ($message -match '^[a-zA-Z]+!:' -or $message -match '^BREAKING CHANGE') {
            $hasBreaking = $true
        }

        # Check for feat prefix
        if ($message -match '^feat[\(!:]') {
            $hasFeat = $true
        }

        # Check for fix prefix
        if ($message -match '^fix[\(!:]') {
            $hasFix = $true
        }
    }

    # Return highest priority bump type
    if ($hasBreaking) {
        return 'Major'
    }
    if ($hasFeat) {
        return 'Minor'
    }
    if ($hasFix) {
        return 'Patch'
    }

    return 'None'
}

function Step-SemanticVersion {
    <#
    .SYNOPSIS
        Bumps a semantic version by the specified type.
    .DESCRIPTION
        Given a version object (with Major, Minor, Patch properties) and a
        bump type, returns a new version object with the appropriate fields
        incremented/reset per semver rules.
    .OUTPUTS
        PSCustomObject with Major, Minor, Patch, and Raw properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Version,

        [Parameter(Mandatory)]
        [ValidateSet('Major', 'Minor', 'Patch', 'None')]
        [string]$BumpType
    )

    [int]$major = [int]$Version.Major
    [int]$minor = [int]$Version.Minor
    [int]$patch = [int]$Version.Patch

    switch ($BumpType) {
        'Major' {
            $major = $major + 1
            $minor = 0
            $patch = 0
        }
        'Minor' {
            $minor = $minor + 1
            $patch = 0
        }
        'Patch' {
            $patch = $patch + 1
        }
        'None' {
            # No change
        }
        default {
            throw "Invalid bump type: '$BumpType'. Must be Major, Minor, Patch, or None."
        }
    }

    [string]$raw = '{0}.{1}.{2}' -f $major, $minor, $patch

    return [PSCustomObject]@{
        Major = $major
        Minor = $minor
        Patch = $patch
        Raw   = $raw
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Generates a markdown changelog entry from commit messages.
    .DESCRIPTION
        Creates a formatted markdown changelog entry for the given version,
        categorizing commits into Features, Bug Fixes, and Breaking Changes.
    .OUTPUTS
        A string containing the markdown changelog entry.
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

    [System.Collections.Generic.List[string]]$features = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$fixes = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$breaking = [System.Collections.Generic.List[string]]::new()
    [System.Collections.Generic.List[string]]$other = [System.Collections.Generic.List[string]]::new()

    foreach ($msg in $CommitMessages) {
        [string]$message = $msg.Trim()
        if ($message.Length -eq 0) {
            continue
        }

        # Extract the description part (after the type prefix and colon)
        [string]$description = $message
        if ($message -match '^[a-zA-Z]+!?(\([^)]*\))?:\s*(.+)$') {
            $description = $Matches[2]
        }
        elseif ($message -match '^BREAKING CHANGE:\s*(.+)$') {
            $description = $Matches[1]
        }

        # Categorize the commit
        if ($message -match '^[a-zA-Z]+!:' -or $message -match '^BREAKING CHANGE') {
            $breaking.Add($description)
        }
        elseif ($message -match '^feat[\(!:]') {
            $features.Add($description)
        }
        elseif ($message -match '^fix[\(!:]') {
            $fixes.Add($description)
        }
        else {
            $other.Add($description)
        }
    }

    # Build the changelog markdown
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [string]$dateStr = (Get-Date -Format 'yyyy-MM-dd')
    [void]$sb.AppendLine("## $Version ($dateStr)")
    [void]$sb.AppendLine('')

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        [void]$sb.AppendLine('')
        foreach ($item in $breaking) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine('')
    }

    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        [void]$sb.AppendLine('')
        foreach ($item in $features) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine('')
    }

    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Bug Fixes')
        [void]$sb.AppendLine('')
        foreach ($item in $fixes) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine('')
    }

    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other')
        [void]$sb.AppendLine('')
        foreach ($item in $other) {
            [void]$sb.AppendLine("- $item")
        }
        [void]$sb.AppendLine('')
    }

    return $sb.ToString()
}

function Update-VersionFile {
    <#
    .SYNOPSIS
        Writes a new version string to a version file.
    .DESCRIPTION
        Updates either a plain text version file or a package.json file
        with the new version string.
    .OUTPUTS
        Void.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$NewVersion
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file '$Path' does not exist."
    }

    if ($Path -match '\.json$') {
        # Read, modify, and write back JSON preserving structure
        [string]$rawContent = Get-Content -Path $Path -Raw
        $jsonObj = $rawContent | ConvertFrom-Json

        # Update the version property
        $jsonObj.version = $NewVersion

        # Write back with consistent formatting
        [string]$updatedJson = $jsonObj | ConvertTo-Json -Depth 10
        Set-Content -Path $Path -Value $updatedJson -NoNewline
    }
    else {
        # Plain text: just write the version
        Set-Content -Path $Path -Value $NewVersion -NoNewline
    }
}

function Invoke-VersionBump {
    <#
    .SYNOPSIS
        Full workflow: parse version, determine bump, update file, generate changelog.
    .DESCRIPTION
        Orchestrates the complete version bumping workflow:
        1. Parse current version from the version file
        2. Read commit messages from the commit log file
        3. Determine bump type from conventional commits
        4. Bump the version accordingly
        5. Update the version file
        6. Generate a changelog entry
        7. Return a result object with all details
    .OUTPUTS
        PSCustomObject with OldVersion, NewVersion, BumpType, and Changelog properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$VersionFilePath,

        [Parameter(Mandatory)]
        [string]$CommitLogPath
    )

    # Step 1: Parse the current version
    [PSCustomObject]$currentVersion = Get-SemanticVersion -Path $VersionFilePath

    # Step 2: Read commit messages
    [string[]]$commits = Get-CommitMessages -Path $CommitLogPath

    # Step 3: Determine bump type
    [string]$bumpType = Get-BumpType -CommitMessages $commits

    # Step 4: Calculate new version
    [PSCustomObject]$newVersion = Step-SemanticVersion -Version $currentVersion -BumpType $bumpType

    # Step 5: Update the version file (only if there's an actual change)
    if ($bumpType -ne 'None') {
        Update-VersionFile -Path $VersionFilePath -NewVersion $newVersion.Raw
    }

    # Step 6: Generate changelog entry
    [string]$changelog = New-ChangelogEntry -Version $newVersion.Raw -CommitMessages $commits

    # Step 7: Output the new version to console (use Write-Host to avoid polluting pipeline)
    Write-Host "Version bumped: $($currentVersion.Raw) -> $($newVersion.Raw) ($bumpType)"

    # Return result object
    return [PSCustomObject]@{
        OldVersion = [string]$currentVersion.Raw
        NewVersion = [string]$newVersion.Raw
        BumpType   = [string]$bumpType
        Changelog  = [string]$changelog
    }
}

# Export all public functions
Export-ModuleMember -Function @(
    'Get-SemanticVersion'
    'Get-CommitMessages'
    'Get-BumpType'
    'Step-SemanticVersion'
    'New-ChangelogEntry'
    'Update-VersionFile'
    'Invoke-VersionBump'
)
