# SemanticVersionBumper.psm1
#
# Semantic version bumper driven by Conventional Commits.
#
# Exposed functions:
#   Get-CurrentVersion   - Read + validate a version from VERSION or package.json.
#   Get-BumpType         - Classify a list of commit messages as major/minor/patch (or $null).
#   Get-NextVersion      - Apply a bump type to a semantic version string.
#   Set-VersionInFile    - Persist a new version, keeping surrounding file content intact.
#   New-ChangelogEntry   - Render a Keep-a-Changelog style section for a set of commits.
#   Invoke-VersionBump   - Orchestrator that ties the above together.
#
# Design notes:
# - All parsing is regex-based rather than pulling in external modules, so the
#   script stays portable and easy to run inside act's Docker container.
# - The module is deliberately side-effect free except for Set-VersionInFile and
#   Invoke-VersionBump, which touch disk. Everything else is pure, which keeps
#   the unit tests fast and independent of the filesystem.

$script:SemVerPattern = '^v?(\d+)\.(\d+)\.(\d+)$'

# Normalize a single commit message into its "summary" plus detected metadata.
# Commit messages may be multi-line (subject + body + footers). We only look
# at the subject line to classify the type, but the full body is scanned for
# a BREAKING CHANGE footer so merge commits with proper footers still work.
function ConvertTo-CommitInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Commit)

    $lines = $Commit -split "`n", 2
    $subject = $lines[0].Trim()
    $body = if ($lines.Count -gt 1) { $lines[1] } else { '' }

    # Conventional Commits subject pattern: type(scope)!: description
    # We permit leading whitespace and case-insensitive match on the type.
    $subjectPattern = '^(?<type>[A-Za-z]+)(?:\((?<scope>[^)]+)\))?(?<breaking>!)?:\s*(?<desc>.+)$'
    $match = [regex]::Match($subject, $subjectPattern)
    if (-not $match.Success) {
        return [pscustomobject]@{
            Type        = $null
            Scope       = $null
            Breaking    = $false
            Description = $subject
            Raw         = $Commit
        }
    }

    $breaking = $match.Groups['breaking'].Success -or ($body -match '(?m)^\s*BREAKING[ -]CHANGE:')
    [pscustomobject]@{
        Type        = $match.Groups['type'].Value.ToLowerInvariant()
        Scope       = if ($match.Groups['scope'].Success) { $match.Groups['scope'].Value } else { $null }
        Breaking    = [bool]$breaking
        Description = $match.Groups['desc'].Value.Trim()
        Raw         = $Commit
    }
}

function Test-SemanticVersion {
    param([string]$Version)
    return ($null -ne $Version) -and ($Version -match $script:SemVerPattern)
}

function Get-CurrentVersion {
    <#
    .SYNOPSIS
        Read the current semantic version from a VERSION file or package.json.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version source not found: $Path"
    }

    $fileName = [IO.Path]::GetFileName($Path)
    $raw = Get-Content -LiteralPath $Path -Raw

    if ($fileName -ieq 'package.json') {
        try {
            $json = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to parse $Path as JSON: $($_.Exception.Message)"
        }
        if (-not $json.PSObject.Properties.Name -contains 'version') {
            throw "package.json at $Path is missing a 'version' field."
        }
        $candidate = [string]$json.version
    } else {
        $candidate = $raw.Trim()
    }

    $candidate = $candidate.Trim()
    if ($candidate.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) {
        $candidate = $candidate.Substring(1)
    }

    if (-not (Test-SemanticVersion $candidate)) {
        throw "Value '$candidate' in $Path is not a valid semantic version (expected MAJOR.MINOR.PATCH)."
    }
    return $candidate
}

function Get-BumpType {
    <#
    .SYNOPSIS
        Given a list of conventional commit messages, return the most-severe
        bump warranted: 'major', 'minor', 'patch', or $null when nothing
        user-visible has changed.
    #>
    [CmdletBinding()]
    param([string[]]$Commits)

    if (-not $Commits -or $Commits.Count -eq 0) { return $null }

    $severity = 0   # 0 = none, 1 = patch, 2 = minor, 3 = major
    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $info = ConvertTo-CommitInfo -Commit $c
        if ($info.Breaking) {
            $severity = [math]::Max($severity, 3)
            continue
        }
        switch ($info.Type) {
            'feat' { $severity = [math]::Max($severity, 2) }
            'fix'  { $severity = [math]::Max($severity, 1) }
            'perf' { $severity = [math]::Max($severity, 1) }
            default { }
        }
    }

    switch ($severity) {
        3 { return 'major' }
        2 { return 'minor' }
        1 { return 'patch' }
        default { return $null }
    }
}

function Get-NextVersion {
    <#
    .SYNOPSIS
        Apply a bump type to an existing semantic version string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Current,
        [Parameter(Mandatory)][string]$BumpType
    )

    if (-not (Test-SemanticVersion $Current)) {
        throw "Cannot bump '$Current': not a valid semantic version (expected MAJOR.MINOR.PATCH)."
    }
    $m = [regex]::Match($Current, $script:SemVerPattern)
    [int]$major = $m.Groups[1].Value
    [int]$minor = $m.Groups[2].Value
    [int]$patch = $m.Groups[3].Value

    switch ($BumpType.ToLowerInvariant()) {
        'major' { return "$($major + 1).0.0" }
        'minor' { return "$major.$($minor + 1).0" }
        'patch' { return "$major.$minor.$($patch + 1)" }
        default { throw "Unknown bump type: '$BumpType' (expected major/minor/patch)." }
    }
}

function Set-VersionInFile {
    <#
    .SYNOPSIS
        Persist the new version back to disk while preserving surrounding content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Version
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version target not found: $Path"
    }

    $fileName = [IO.Path]::GetFileName($Path)
    if ($fileName -ieq 'package.json') {
        $raw = Get-Content -LiteralPath $Path -Raw
        # Mutate only the version field so we don't reorder other keys or
        # reformat the file. A regex replacement is sufficient for the
        # conventional "version": "x.y.z" syntax, and survives round-tripping
        # fields PowerShell's JSON deserializer would otherwise lose.
        $pattern = '("version"\s*:\s*")[^"]*(")'
        if ($raw -notmatch $pattern) {
            throw "package.json at $Path does not contain a recognizable version field."
        }
        $updated = [regex]::Replace($raw, $pattern, "`${1}$Version`${2}", 1)
        Set-Content -LiteralPath $Path -Value $updated -NoNewline
    } else {
        Set-Content -LiteralPath $Path -Value "$Version`n" -NoNewline
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Build a Keep-a-Changelog section summarizing the supplied commits.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string[]]$Commits
    )

    $breaking = New-Object System.Collections.Generic.List[string]
    $added = New-Object System.Collections.Generic.List[string]
    $fixed = New-Object System.Collections.Generic.List[string]
    $other = New-Object System.Collections.Generic.List[string]

    foreach ($c in $Commits) {
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $info = ConvertTo-CommitInfo -Commit $c
        $desc = if ($info.Scope) { "**$($info.Scope):** $($info.Description)" } else { $info.Description }
        if ($info.Breaking) { $breaking.Add($desc); continue }
        switch ($info.Type) {
            'feat' { $added.Add($desc) }
            'fix'  { $fixed.Add($desc) }
            'perf' { $fixed.Add($desc) }
            default { $other.Add($desc) }
        }
    }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()
    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### BREAKING CHANGES')
        foreach ($item in $breaking) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }
    if ($added.Count -gt 0) {
        [void]$sb.AppendLine('### Added')
        foreach ($item in $added) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }
    if ($fixed.Count -gt 0) {
        [void]$sb.AppendLine('### Fixed')
        foreach ($item in $fixed) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }
    if ($other.Count -gt 0) {
        [void]$sb.AppendLine('### Other')
        foreach ($item in $other) { [void]$sb.AppendLine("- $item") }
        [void]$sb.AppendLine()
    }
    return $sb.ToString().TrimEnd() + "`n"
}

# Commit log parser: a single file where commits are separated by a line
# containing only "---". This matches what git log --format='%B%n---'
# would emit and is trivial to hand-write as a fixture.
function Read-CommitsFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commits file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $parts = $raw -split "(?m)^\s*---\s*$"
    $commits = foreach ($p in $parts) {
        $trimmed = $p.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmed)) { $trimmed }
    }
    # If no --- separators were present, fall back to one commit per line so
    # simple fixtures "just work".
    if ($commits.Count -eq 1 -and $raw -notmatch "(?m)^\s*---\s*$") {
        $lines = $raw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($lines.Count -gt 1) { return @($lines) }
    }
    return @($commits)
}

function Invoke-VersionBump {
    <#
    .SYNOPSIS
        End-to-end: read version, classify commits, write version + changelog,
        return a summary object.
    .OUTPUTS
        [pscustomobject] with OldVersion, NewVersion, BumpType, ChangelogEntry.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitsFile,
        [Parameter(Mandatory)][string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $current = Get-CurrentVersion -Path $VersionFile
    $commits = Read-CommitsFile -Path $CommitsFile
    $bump = Get-BumpType -Commits $commits
    if (-not $bump) {
        throw "No version bump warranted: commits contain no feat/fix/breaking changes."
    }
    $next = Get-NextVersion -Current $current -BumpType $bump
    Set-VersionInFile -Path $VersionFile -Version $next

    $entry = New-ChangelogEntry -Version $next -Date $Date -Commits $commits

    # Prepend the new entry to the changelog, preserving prior content. If the
    # file doesn't exist yet, include a top-level heading so the result is
    # valid Keep-a-Changelog.
    if (Test-Path -LiteralPath $ChangelogFile) {
        $existing = Get-Content -LiteralPath $ChangelogFile -Raw
        if ($existing -match '^#\s') {
            # Split off the top heading so new entries are inserted below it.
            $headingMatch = [regex]::Match($existing, '^(#\s[^\r\n]*\r?\n\r?\n?)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($headingMatch.Success) {
                $heading = $headingMatch.Value
                $rest = $existing.Substring($heading.Length)
                $final = $heading + $entry + "`n" + $rest
            } else {
                $final = $entry + "`n" + $existing
            }
        } else {
            $final = "# Changelog`n`n" + $entry + "`n" + $existing
        }
        Set-Content -LiteralPath $ChangelogFile -Value $final -NoNewline
    } else {
        $final = "# Changelog`n`n" + $entry
        Set-Content -LiteralPath $ChangelogFile -Value $final -NoNewline
    }

    return [pscustomobject]@{
        OldVersion     = $current
        NewVersion     = $next
        BumpType       = $bump
        ChangelogEntry = $entry
    }
}

Export-ModuleMember -Function @(
    'Get-CurrentVersion',
    'Get-BumpType',
    'Get-NextVersion',
    'Set-VersionInFile',
    'New-ChangelogEntry',
    'Read-CommitsFile',
    'Invoke-VersionBump'
)
