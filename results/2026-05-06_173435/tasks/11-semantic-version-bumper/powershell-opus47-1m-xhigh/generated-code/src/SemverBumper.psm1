# SemverBumper.psm1
# ----------------------------------------------------------------------------
# Pure PowerShell implementation of a Conventional-Commits-driven semver
# bumper. Functions are kept small + side-effect free where practical so
# Pester can drive them without touching git or the filesystem. The two
# functions that DO touch disk (Read/Write/Find-VersionFile, Invoke-VersionBump)
# accept explicit paths so tests can run inside isolated temp directories.
# ----------------------------------------------------------------------------

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Conventional Commit type token + optional scope, e.g.:  feat(api)!: ...
# Captures: 1 = type, 2 = scope (incl. parens, optional), 3 = bang (optional),
# 4 = subject. The (?i) inline flag keeps Get-BumpKind case-insensitive on
# the type token (FEAT / Feat / feat all parse the same).
$Script:CommitHeaderRegex = '(?i)^(?<type>[a-z]+)(?<scope>\([^)]+\))?(?<bang>!)?:\s*(?<subject>.+)$'

function ConvertTo-SemVer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Version)

    # Strip optional leading 'v' (e.g. 'v1.2.3' as seen on git tags).
    if ($Version -notmatch '^v?(\d+)\.(\d+)\.(\d+)\b') {
        throw "Invalid semantic version: '$Version'. Expected MAJOR.MINOR.PATCH (optional 'v' prefix)."
    }
    [pscustomobject]@{
        Major = [int]$Matches[1]
        Minor = [int]$Matches[2]
        Patch = [int]$Matches[3]
    }
}

function ConvertFrom-SemVer {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)]$SemVer)
    "{0}.{1}.{2}" -f $SemVer.Major, $SemVer.Minor, $SemVer.Patch
}

function Get-BumpKind {
    <#
    .SYNOPSIS
    Decide which version component to bump given a list of commit messages.
    Returns 'major' / 'minor' / 'patch' / 'none' (the highest of any commit).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$CommitMessages)

    $kind = 'none'
    foreach ($msg in $CommitMessages) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }
        $firstLine = ($msg -split "`r?`n")[0]

        # Breaking change: '!' marker on header OR 'BREAKING CHANGE:' / 'BREAKING-CHANGE:' anywhere in body.
        $isBreaking = ($firstLine -match '(?i)^[a-z]+(\([^)]+\))?!:') -or
                      ($msg -match '(?im)^BREAKING[ -]CHANGE:')
        if ($isBreaking) { return 'major' }

        if ($firstLine -match '(?i)^feat(\([^)]+\))?:') {
            $kind = 'minor'
        }
        elseif ($firstLine -match '(?i)^fix(\([^)]+\))?:' -and $kind -ne 'minor') {
            $kind = 'patch'
        }
    }
    $kind
}

function Step-SemVer {
    <#
    .SYNOPSIS
    Apply a bump kind to a parsed SemVer, resetting lower components per spec.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SemVer,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch','none')][string]$Kind
    )

    switch ($Kind) {
        'major' { [pscustomobject]@{ Major = $SemVer.Major + 1; Minor = 0;               Patch = 0 } }
        'minor' { [pscustomobject]@{ Major = $SemVer.Major;     Minor = $SemVer.Minor+1; Patch = 0 } }
        'patch' { [pscustomobject]@{ Major = $SemVer.Major;     Minor = $SemVer.Minor;   Patch = $SemVer.Patch + 1 } }
        'none'  { [pscustomobject]@{ Major = $SemVer.Major;     Minor = $SemVer.Minor;   Patch = $SemVer.Patch } }
    }
}

function Read-VersionFile {
    <#
    .SYNOPSIS
    Read a version string out of either a plain VERSION file or a package.json.
    Returns @{ Version, Format, Path }. Format = 'plain' | 'package.json'.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    if ([IO.Path]::GetFileName($Path) -ieq 'package.json') {
        $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $obj.PSObject.Properties['version']) {
            throw "package.json at '$Path' has no 'version' field."
        }
        return [pscustomobject]@{ Version = $obj.version; Format = 'package.json'; Path = $Path }
    }

    $raw = (Get-Content -LiteralPath $Path -Raw).Trim()
    [pscustomobject]@{ Version = $raw; Format = 'plain'; Path = $Path }
}

function Write-VersionFile {
    <#
    .SYNOPSIS
    Persist a new version string back to disk.
    For package.json we do a regex replace on the existing version field
    instead of re-serialising, so unrelated fields, key order, and trailing
    whitespace stay byte-identical to what the user committed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('plain','package.json')][string]$Format,
        [Parameter(Mandatory)][string]$Version
    )

    if ($Format -eq 'package.json') {
        $raw = Get-Content -LiteralPath $Path -Raw
        $new = [regex]::Replace($raw, '("version"\s*:\s*")[^"]+(")', "`${1}$Version`${2}", 1)
        Set-Content -LiteralPath $Path -Value $new -NoNewline
    }
    else {
        Set-Content -LiteralPath $Path -Value $Version -NoNewline
    }
}

function Find-VersionFile {
    <#
    .SYNOPSIS
    Locate a version file inside a repo. Prefer package.json (the more
    structured option) when both are present.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $pkg = Join-Path $RepoRoot 'package.json'
    if (Test-Path -LiteralPath $pkg) {
        return [pscustomobject]@{ Path = $pkg; Format = 'package.json' }
    }
    $ver = Join-Path $RepoRoot 'VERSION'
    if (Test-Path -LiteralPath $ver) {
        return [pscustomobject]@{ Path = $ver; Format = 'plain' }
    }
    throw "No version file found in '$RepoRoot' (looked for package.json and VERSION)."
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
    Render a Keep-A-Changelog-style entry for a single release.
    Sections: BREAKING CHANGES, Features, Bug Fixes (only the ones that
    actually have entries are emitted, in that fixed order).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$NewVersion,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits,
        [Parameter(Mandatory)][string]$Date
    )

    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()
    $breaks   = [System.Collections.Generic.List[string]]::new()

    foreach ($msg in $Commits) {
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }
        $firstLine = ($msg -split "`r?`n")[0]

        $isBreaking = ($firstLine -match '(?i)^[a-z]+(\([^)]+\))?!:') -or
                      ($msg -match '(?im)^BREAKING[ -]CHANGE:')

        if ($firstLine -match $Script:CommitHeaderRegex) {
            $type    = $Matches['type'].ToLowerInvariant()
            $subject = $Matches['subject']

            if ($isBreaking) {
                # Breaking changes shadow the type bucket — they only show
                # under BREAKING CHANGES so we don't double-list a single commit.
                $breaks.Add($subject)
            }
            elseif ($type -eq 'feat') {
                $features.Add($subject)
            }
            elseif ($type -eq 'fix') {
                $fixes.Add($subject)
            }
            # chore/docs/style/refactor/perf/test/build/ci -> intentionally omitted
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$NewVersion] - $Date")
    [void]$sb.AppendLine()

    if ($breaks.Count -gt 0) {
        [void]$sb.AppendLine("### BREAKING CHANGES")
        foreach ($b in $breaks) { [void]$sb.AppendLine("- $b") }
        [void]$sb.AppendLine()
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine("### Features")
        foreach ($f in $features) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine("### Bug Fixes")
        foreach ($x in $fixes) { [void]$sb.AppendLine("- $x") }
        [void]$sb.AppendLine()
    }

    $sb.ToString()
}

function Invoke-VersionBump {
    <#
    .SYNOPSIS
    Top-level orchestrator: locate version file, parse current version,
    decide bump kind, write new version + changelog entry. Returns a
    summary object the CLI/workflow surfaces to the user.

    .PARAMETER CommitMessages
    Already-collected commit messages (oldest -> newest doesn't matter
    since we take the highest bump). Passing them in keeps the function
    pure for tests; the CLI script wraps `git log` and forwards here.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$CommitMessages,
        [string]$Date
    )

    if (-not $Date) { $Date = (Get-Date -Format 'yyyy-MM-dd') }

    $vf = Find-VersionFile -RepoRoot $RepoRoot
    $current = Read-VersionFile -Path $vf.Path
    $oldVersion = $current.Version
    $semver = ConvertTo-SemVer $oldVersion

    $kind = Get-BumpKind $CommitMessages
    $next = Step-SemVer -SemVer $semver -Kind $kind
    $newVersion = ConvertFrom-SemVer $next

    if ($kind -ne 'none') {
        Write-VersionFile -Path $vf.Path -Format $vf.Format -Version $newVersion

        $entry = New-ChangelogEntry -NewVersion $newVersion -Commits $CommitMessages -Date $Date
        $changelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
        if (Test-Path -LiteralPath $changelogPath) {
            # Prepend new entry above the existing one (newest at top).
            $existing = Get-Content -LiteralPath $changelogPath -Raw
            Set-Content -LiteralPath $changelogPath -Value ($entry + "`n" + $existing) -NoNewline
        }
        else {
            $header = "# Changelog`n`nAll notable changes are documented here.`n`n"
            Set-Content -LiteralPath $changelogPath -Value ($header + $entry) -NoNewline
        }
    }

    [pscustomobject]@{
        OldVersion  = $oldVersion
        NewVersion  = $newVersion
        BumpKind    = $kind
        VersionFile = $vf.Path
        Format      = $vf.Format
    }
}

Export-ModuleMember -Function `
    ConvertTo-SemVer, ConvertFrom-SemVer, Get-BumpKind, Step-SemVer,
    Read-VersionFile, Write-VersionFile, Find-VersionFile,
    New-ChangelogEntry, Invoke-VersionBump
