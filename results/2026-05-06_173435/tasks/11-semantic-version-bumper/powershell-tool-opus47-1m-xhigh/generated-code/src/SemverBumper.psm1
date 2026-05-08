# SemverBumper.psm1
#
# A small semantic-version bumper that consumes conventional-commit messages.
#
# The module is split into composable functions so each piece can be unit-tested
# in isolation:
#
#   Get-CurrentVersion     - reads the current version from VERSION or package.json
#   Get-ConventionalCommits - parses commit messages into typed objects
#   Get-NextBumpType       - decides major/minor/patch/none from the commits
#   Step-Version           - applies the bump to a semver string
#   Set-VersionFile        - writes the new version back, preserving file format
#   New-ChangelogEntry     - renders a Markdown changelog block
#   Invoke-Bumper          - orchestrates the full bump pipeline
#
# Conventional Commits: https://www.conventionalcommits.org/en/v1.0.0/

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Strict semver core regex (no pre-release / build metadata for simplicity).
$script:SemverRegex = '^(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)$'

# A conventional commit subject:  type(scope)?!?: description
$script:ConvCommitRegex = '^(?<type>[a-zA-Z]+)(\((?<scope>[^)]+)\))?(?<bang>!)?:\s*(?<desc>.+)$'


function Test-SemverString {
    <#
    .SYNOPSIS
        Returns $true if the input is a valid major.minor.patch string.
    #>
    param([string]$Version)
    return [bool]($Version -match $script:SemverRegex)
}


function Get-CurrentVersion {
    <#
    .SYNOPSIS
        Reads the current version from a plain VERSION file or a package.json.

    .DESCRIPTION
        If the path ends with .json the file is parsed as JSON and the .version
        field is returned; otherwise the file's trimmed content is treated as
        the version string. Throws a descriptive error if the file is missing
        or the version isn't valid semver.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    if ($Path -like '*.json') {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $obj.PSObject.Properties.Name -contains 'version') {
            throw "package.json at '$Path' has no 'version' field."
        }
        $raw = [string]$obj.version
    } else {
        $raw = (Get-Content -LiteralPath $Path -Raw).Trim()
    }

    if (-not (Test-SemverString $raw)) {
        throw "Value '$raw' from '$Path' is not a valid semantic version (expected MAJOR.MINOR.PATCH)."
    }

    return $raw
}


function Get-ConventionalCommits {
    <#
    .SYNOPSIS
        Parses one or more conventional-commit messages.

    .DESCRIPTION
        Accepts either a -Text string with newline-separated commits or a
        -Path to a file containing them. Returns an array of PSCustomObjects:

            Type        - the commit type (feat / fix / chore / ...)
            Scope       - optional scope, $null if absent
            IsBreaking  - $true if subject has '!' or body has 'BREAKING CHANGE:'
            Description - the human-readable subject (without prefix)
            Raw         - the original line(s) for traceability

        Lines that don't match the conventional-commit pattern are silently
        skipped; the BREAKING CHANGE footer attaches to the most recent commit.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Text')]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Commits file not found: $Path"
        }
        $Text = Get-Content -LiteralPath $Path -Raw
    }

    $commits = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    foreach ($line in ($Text -split "`r?`n")) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }

        # BREAKING CHANGE: footer applies to the most recent commit.
        if ($trimmed -match '^BREAKING[ -]CHANGE:') {
            if ($commits.Count -gt 0) {
                $commits[$commits.Count - 1].IsBreaking = $true
            }
            continue
        }

        if ($trimmed -match $script:ConvCommitRegex) {
            $commits.Add([pscustomobject]@{
                Type        = $Matches['type'].ToLowerInvariant()
                Scope       = if ($Matches.ContainsKey('scope') -and $Matches['scope']) { $Matches['scope'] } else { $null }
                IsBreaking  = [bool]$Matches['bang']
                Description = $Matches['desc']
                Raw         = $trimmed
            }) | Out-Null
        }
    }

    return ,$commits.ToArray()
}


function Get-NextBumpType {
    <#
    .SYNOPSIS
        Picks the strongest bump type implied by a list of commits.

    .DESCRIPTION
        Precedence: any breaking -> 'major', else any 'feat' -> 'minor',
        else any 'fix' -> 'patch', else 'none'. Anything else (chore, docs,
        refactor, ...) does not trigger a release on its own.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Commits
    )

    if (-not $Commits -or $Commits.Count -eq 0) { return 'none' }

    $hasBreaking = $false
    $hasFeat     = $false
    $hasFix      = $false

    foreach ($c in $Commits) {
        if ($c.IsBreaking) { $hasBreaking = $true }
        switch ($c.Type) {
            'feat' { $hasFeat = $true }
            'fix'  { $hasFix  = $true }
        }
    }

    if ($hasBreaking) { return 'major' }
    if ($hasFeat)     { return 'minor' }
    if ($hasFix)      { return 'patch' }
    return 'none'
}


function Step-Version {
    <#
    .SYNOPSIS
        Applies a bump type to a semver string and returns the new version.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Version,
        [Parameter(Mandatory)]
        [ValidateSet('major','minor','patch','none')]
        [string]$BumpType
    )

    if (-not (Test-SemverString $Version)) {
        throw "Value '$Version' is not a valid semantic version."
    }

    if ($BumpType -eq 'none') { return $Version }

    $null = $Version -match $script:SemverRegex
    [int]$maj = [int]$Matches['major']
    [int]$min = [int]$Matches['minor']
    [int]$pat = [int]$Matches['patch']

    switch ($BumpType) {
        'major' { $maj++; $min = 0; $pat = 0 }
        'minor' { $min++; $pat = 0 }
        'patch' { $pat++ }
    }

    return "$maj.$min.$pat"
}


function Set-VersionFile {
    <#
    .SYNOPSIS
        Writes the new version back to disk, preserving the original file format.

    .DESCRIPTION
        For *.json (e.g. package.json) the version field is updated in place
        and the file is rewritten as JSON. For everything else the file is
        rewritten with just the version string + trailing newline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Version
    )

    if (-not (Test-SemverString $Version)) {
        throw "Refusing to write invalid semver '$Version' to '$Path'."
    }

    if ($Path -like '*.json') {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $obj.version = $Version
        # Use a generous depth so nested fields are preserved verbatim.
        $json = $obj | ConvertTo-Json -Depth 64
        Set-Content -LiteralPath $Path -Value $json
    } else {
        Set-Content -LiteralPath $Path -Value $Version
    }
}


function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Renders a Markdown changelog block for the given version + commits.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Version,
        [Parameter(Mandatory)] [string]$Date,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Commits
    )

    $breaking = @($Commits | Where-Object { $_.IsBreaking })
    $feats    = @($Commits | Where-Object { $_.Type -eq 'feat' -and -not $_.IsBreaking })
    $fixes    = @($Commits | Where-Object { $_.Type -eq 'fix'  -and -not $_.IsBreaking })

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()

    function Format-Bullet($c) {
        if ($c.Scope) { return "- **$($c.Scope)**: $($c.Description)" }
        return "- $($c.Description)"
    }

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($c in $breaking) { [void]$sb.AppendLine((Format-Bullet $c)) }
        [void]$sb.AppendLine()
    }
    if ($feats.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($c in $feats) { [void]$sb.AppendLine((Format-Bullet $c)) }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Fixes')
        foreach ($c in $fixes) { [void]$sb.AppendLine((Format-Bullet $c)) }
        [void]$sb.AppendLine()
    }

    return $sb.ToString().TrimEnd() + "`n"
}


function Invoke-Bumper {
    <#
    .SYNOPSIS
        Orchestrates the full bump: read version, parse commits, bump, write,
        update CHANGELOG.

    .DESCRIPTION
        This is the public entry point used by the CLI script and by the
        GitHub Actions workflow. Returns a result object describing what
        happened so callers can act on it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$VersionFile,
        [Parameter(Mandatory)] [string]$CommitsFile,
        [Parameter(Mandatory)] [string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $oldVersion = Get-CurrentVersion -Path $VersionFile
    $commits    = Get-ConventionalCommits -Path $CommitsFile
    $bumpType   = Get-NextBumpType -Commits $commits
    $newVersion = Step-Version -Version $oldVersion -BumpType $bumpType

    if ($bumpType -ne 'none') {
        Set-VersionFile -Path $VersionFile -Version $newVersion

        $entry = New-ChangelogEntry -Version $newVersion -Date $Date -Commits $commits

        if (Test-Path -LiteralPath $ChangelogFile) {
            $existing = Get-Content -LiteralPath $ChangelogFile -Raw
            if ($existing -match '^# Changelog\s*\r?\n') {
                # Insert the new entry right after the top-level header.
                $header   = $Matches[0]
                $body     = $existing.Substring($header.Length)
                $combined = $header + "`n" + $entry + "`n" + $body.TrimStart()
                Set-Content -LiteralPath $ChangelogFile -Value $combined -NoNewline
            } else {
                # No header recognised - prepend the entry above existing content.
                Set-Content -LiteralPath $ChangelogFile `
                    -Value ("# Changelog`n`n" + $entry + "`n" + $existing) -NoNewline
            }
        } else {
            Set-Content -LiteralPath $ChangelogFile `
                -Value ("# Changelog`n`n" + $entry) -NoNewline
        }
    }

    return [pscustomobject]@{
        OldVersion = $oldVersion
        NewVersion = $newVersion
        BumpType   = $bumpType
        Commits    = $commits
    }
}


Export-ModuleMember -Function `
    Get-CurrentVersion,
    Get-ConventionalCommits,
    Get-NextBumpType,
    Step-Version,
    Set-VersionFile,
    New-ChangelogEntry,
    Invoke-Bumper,
    Test-SemverString
