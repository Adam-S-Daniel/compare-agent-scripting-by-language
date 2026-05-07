# Bumper.psm1 - semantic version bumper based on conventional commits.
#
# The module exposes small, single-responsibility functions so each one is
# easy to test in isolation:
#
#   Get-VersionFromFile / Set-VersionInFile  - I/O for VERSION or package.json
#   Read-CommitFixture                        - parse a deterministic test
#                                               fixture file (avoids needing
#                                               a real git repo in tests)
#   Get-BumpType                              - classify commits into
#                                               major / minor / patch
#   Step-SemVer                               - apply that bump to a semver
#                                               string
#   New-ChangelogEntry                        - render Markdown for a release
#   Invoke-VersionBump                        - the end-to-end orchestrator
#
# Conventional Commits rules applied:
#   - "BREAKING CHANGE" anywhere in subject or body -> major
#   - subject "type!:" or "type(scope)!:"            -> major
#   - subject "feat" / "feat(scope):"                -> minor
#   - subject "fix"  / "fix(scope):"                 -> patch
#   - anything else                                  -> patch (still releases,
#                                                     but only as patch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VersionFromFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    if ((Split-Path -Leaf $Path) -ieq 'package.json') {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if (-not $json.PSObject.Properties['version']) {
            throw "package.json has no 'version' field at $Path"
        }
        return [string]$json.version
    }

    return (Get-Content -LiteralPath $Path -Raw).Trim()
}

function Set-VersionInFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version
    )

    if ((Split-Path -Leaf $Path) -ieq 'package.json') {
        # Use a regex replace so we don't reorder JSON keys or change formatting.
        $raw = Get-Content -LiteralPath $Path -Raw
        $new = [regex]::Replace(
            $raw,
            '("version"\s*:\s*")[^"]*(")',
            { param($m) $m.Groups[1].Value + $Version + $m.Groups[2].Value },
            1
        )
        Set-Content -LiteralPath $Path -Value $new -NoNewline
        return
    }

    Set-Content -LiteralPath $Path -Value $Version -NoNewline
}

function Read-CommitFixture {
    # Test fixtures use a clear delimiter ("--SEP--" on its own line) between
    # commits, so test runs are deterministic and don't need a git repo.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commit fixture not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }

    $blocks = [regex]::Split($raw, '(?m)^--SEP--\s*$')
    $commits = @()
    foreach ($b in $blocks) {
        $trimmed = $b.Trim("`r","`n")
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        $lines  = $trimmed -split "`r?`n"
        $subject = $lines[0]
        $body    = if ($lines.Count -gt 1) { ($lines[1..($lines.Count-1)] -join "`n").Trim() } else { '' }
        $commits += [pscustomobject]@{ Subject = $subject; Body = $body }
    }
    return ,$commits
}

function Get-BumpType {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [Parameter(Mandatory)]
        [object[]]$Commits
    )

    if (-not $Commits -or $Commits.Count -eq 0) {
        throw "Cannot determine bump type: no commits provided"
    }

    $hasFeat = $false
    foreach ($c in $Commits) {
        $subject = [string]$c.Subject
        $body    = [string]$c.Body

        # Major: any "BREAKING CHANGE" footer, or "!:" in subject after type/scope.
        if ($body -match 'BREAKING CHANGE' -or $subject -match 'BREAKING CHANGE') {
            return 'major'
        }
        if ($subject -match '^[a-zA-Z]+(\([^)]+\))?!:') {
            return 'major'
        }

        if ($subject -match '^feat(\([^)]+\))?:') {
            $hasFeat = $true
        }
    }

    if ($hasFeat) { return 'minor' }
    return 'patch'
}

function Step-SemVer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][ValidateSet('major','minor','patch')][string]$BumpType
    )

    if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
        throw "'$Version' is not a valid semantic version (expected MAJOR.MINOR.PATCH)"
    }
    $maj = [int]$Matches[1]
    $min = [int]$Matches[2]
    $pat = [int]$Matches[3]

    switch ($BumpType) {
        'major' { $maj++; $min = 0; $pat = 0 }
        'minor' { $min++;          $pat = 0 }
        'patch' { $pat++ }
    }
    return "$maj.$min.$pat"
}

function New-ChangelogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][object[]]$Commits
    )

    $breaking = New-Object System.Collections.Generic.List[string]
    $feats    = New-Object System.Collections.Generic.List[string]
    $fixes    = New-Object System.Collections.Generic.List[string]
    $other    = New-Object System.Collections.Generic.List[string]

    foreach ($c in $Commits) {
        $subject = [string]$c.Subject
        $body    = [string]$c.Body

        $isBreakingSubject = $subject -match '^[a-zA-Z]+(\([^)]+\))?!:'
        if ($isBreakingSubject) { $breaking.Add($subject) }

        if ($body -match 'BREAKING CHANGE:?\s*(.*)') {
            $note = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($note)) { $breaking.Add($note) }
        }

        if ($subject -match '^feat(\([^)]+\))?!?:') {
            if (-not $isBreakingSubject) { $feats.Add($subject) }
        }
        elseif ($subject -match '^fix(\([^)]+\))?!?:') {
            $fixes.Add($subject)
        }
        else {
            $other.Add($subject)
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($x in $breaking) { [void]$sb.AppendLine("- $x") }
        [void]$sb.AppendLine()
    }
    if ($feats.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($x in $feats) { [void]$sb.AppendLine("- $x") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Fixes')
        foreach ($x in $fixes) { [void]$sb.AppendLine("- $x") }
        [void]$sb.AppendLine()
    }
    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other')
        foreach ($x in $other) { [void]$sb.AppendLine("- $x") }
        [void]$sb.AppendLine()
    }

    return $sb.ToString()
}

function Invoke-VersionBump {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [Parameter(Mandatory)][string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $previous = Get-VersionFromFile -Path $VersionFile
    $commits  = Read-CommitFixture  -Path $CommitsFile
    if ($commits.Count -eq 0) {
        throw "No commits found in $CommitsFile - nothing to release"
    }

    $bumpType = Get-BumpType -Commits $commits
    $next     = Step-SemVer  -Version $previous -BumpType $bumpType

    Set-VersionInFile -Path $VersionFile -Version $next

    $entry = New-ChangelogEntry -Version $next -Date $Date -Commits $commits

    if (Test-Path -LiteralPath $ChangelogFile) {
        $existing = Get-Content -LiteralPath $ChangelogFile -Raw
        # Keep an existing "# Changelog" header at the top if present.
        if ($existing -match '^(# Changelog\s*\r?\n)') {
            $header = $Matches[1]
            $rest   = $existing.Substring($header.Length).TrimStart("`r","`n")
            $combined = $header + "`n" + $entry + $rest
        } else {
            $combined = "# Changelog`n`n" + $entry + $existing.TrimStart("`r","`n")
        }
        Set-Content -LiteralPath $ChangelogFile -Value $combined -NoNewline
    } else {
        $combined = "# Changelog`n`n" + $entry
        Set-Content -LiteralPath $ChangelogFile -Value $combined -NoNewline
    }

    return [pscustomobject]@{
        PreviousVersion = $previous
        NextVersion     = $next
        BumpType        = $bumpType
        ChangelogPath   = (Resolve-Path -LiteralPath $ChangelogFile).Path
        VersionFilePath = (Resolve-Path -LiteralPath $VersionFile).Path
    }
}

Export-ModuleMember -Function `
    Get-VersionFromFile,
    Set-VersionInFile,
    Read-CommitFixture,
    Get-BumpType,
    Step-SemVer,
    New-ChangelogEntry,
    Invoke-VersionBump
