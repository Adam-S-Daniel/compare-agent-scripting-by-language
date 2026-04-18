# SemanticVersionBumper.psm1
#
# Core logic for parsing a version file, classifying conventional-commit
# messages, bumping the version, writing the file back, and rendering a
# changelog entry. Kept free of I/O where possible so the pieces are unit
# testable in isolation.
#
# Public cmdlets:
#   Get-SemanticVersion   - read a version from version.txt or package.json
#   Set-SemanticVersion   - write an updated version back to the same file
#   Get-CommitBumpType    - classify a batch of commits as Major/Minor/Patch/None
#   Step-SemanticVersion  - apply a bump to a Major/Minor/Patch triple
#   New-ChangelogEntry    - render a markdown changelog block for a release
#   Invoke-VersionBumper  - one-shot orchestrator used by the workflow and CLI

Set-StrictMode -Version 3.0

# Strict semver regex: three non-negative integer components without leading zeros.
# We intentionally ignore pre-release / build metadata for this exercise.
$script:SemverPattern = '^v?(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*)$'

function Get-SemanticVersion {
    <#
    .SYNOPSIS
        Read a semantic version triple from version.txt or package.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Version file not found: $Path"
    }

    $raw = (Get-Content -LiteralPath $Path -Raw).Trim()
    $versionString = $null

    # package.json-style input: parse JSON and pick the version key. We only
    # special-case files ending in .json; other extensions are treated as
    # plain text so consumers can use version.txt, VERSION, etc.
    if ($Path -match '\.json$') {
        try {
            $json = $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "package.json at '$Path' is not valid JSON: $($_.Exception.Message)"
        }
        if (-not $json.PSObject.Properties.Name -contains 'version') {
            throw "package.json at '$Path' has no 'version' field"
        }
        $versionString = [string]$json.version
    }
    else {
        $versionString = $raw
    }

    if ($versionString -notmatch $script:SemverPattern) {
        throw "'$versionString' is not a valid semantic version (expected MAJOR.MINOR.PATCH)"
    }

    [PSCustomObject]@{
        Major = [int]$Matches['major']
        Minor = [int]$Matches['minor']
        Patch = [int]$Matches['patch']
        Raw   = "$($Matches['major']).$($Matches['minor']).$($Matches['patch'])"
    }
}

function Set-SemanticVersion {
    <#
    .SYNOPSIS
        Write a new version back to version.txt or package.json in place.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$Major,
        [Parameter(Mandatory)][int]$Minor,
        [Parameter(Mandatory)][int]$Patch
    )

    $newVersion = "$Major.$Minor.$Patch"

    if ($Path -match '\.json$') {
        # Re-serialise the JSON object so other keys (name, scripts, …) are
        # preserved verbatim. ConvertTo-Json default depth is 2 which is too
        # shallow for real package.json files.
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $json.version = $newVersion
        $json | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $Path
    }
    else {
        Set-Content -LiteralPath $Path -Value $newVersion -NoNewline
    }
}

function Get-CommitBumpType {
    <#
    .SYNOPSIS
        Classify the highest-precedence bump implied by a set of conventional commits.
    .DESCRIPTION
        Precedence is Major > Minor > Patch > None. A commit is Major if it has a
        `!` before the colon (`feat!:`, `fix!:`) OR if its body contains a line
        starting with `BREAKING CHANGE:`. `feat:` is Minor, `fix:` is Patch, and
        everything else (chore, docs, style, refactor, test, ci, build, perf) is
        ignored by design — we don't want doc-only changes to cut a release.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits
    )

    $bump = 'None'
    foreach ($commit in $Commits) {
        if ([string]::IsNullOrWhiteSpace($commit)) { continue }
        $subject = ($commit -split "`n", 2)[0]

        $isBreaking = $false
        if ($subject -match '^\s*[A-Za-z]+(\([^)]*\))?!\s*:') { $isBreaking = $true }
        if ($commit -match '(?m)^\s*BREAKING[ -]CHANGE\s*:') { $isBreaking = $true }

        if ($isBreaking) { return 'Major' }

        if ($subject -match '^\s*feat(\([^)]*\))?\s*:' -and $bump -ne 'Major') {
            $bump = 'Minor'
        }
        elseif ($subject -match '^\s*fix(\([^)]*\))?\s*:' -and $bump -notin @('Major','Minor')) {
            $bump = 'Patch'
        }
    }
    $bump
}

function Step-SemanticVersion {
    <#
    .SYNOPSIS
        Apply a bump type to a Major/Minor/Patch triple.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Major,
        [Parameter(Mandatory)][int]$Minor,
        [Parameter(Mandatory)][int]$Patch,
        [Parameter(Mandatory)][ValidateSet('Major','Minor','Patch','None')][string]$Bump
    )

    switch ($Bump) {
        'Major' { [PSCustomObject]@{ Major = $Major + 1; Minor = 0;          Patch = 0 } }
        'Minor' { [PSCustomObject]@{ Major = $Major;     Minor = $Minor + 1; Patch = 0 } }
        'Patch' { [PSCustomObject]@{ Major = $Major;     Minor = $Minor;     Patch = $Patch + 1 } }
        'None'  { [PSCustomObject]@{ Major = $Major;     Minor = $Minor;     Patch = $Patch } }
    }
}

function New-ChangelogEntry {
    <#
    .SYNOPSIS
        Render a Keep-a-Changelog style markdown block for a release.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Commits
    )

    $breaking = [System.Collections.Generic.List[string]]::new()
    $features = [System.Collections.Generic.List[string]]::new()
    $fixes    = [System.Collections.Generic.List[string]]::new()

    foreach ($commit in $Commits) {
        if ([string]::IsNullOrWhiteSpace($commit)) { continue }
        $lines = $commit -split "`n"
        $subject = $lines[0]

        # Breaking change body lines first — the rendered bullet uses the
        # BREAKING CHANGE description when present, otherwise the subject.
        $breakingDesc = $null
        foreach ($line in $lines) {
            if ($line -match '^\s*BREAKING[ -]CHANGE\s*:\s*(?<d>.+)$') {
                $breakingDesc = $Matches['d'].Trim()
                break
            }
        }

        $isBangBreaking = $subject -match '^\s*[A-Za-z]+(\([^)]*\))?!\s*:'

        if ($breakingDesc) {
            $breaking.Add($breakingDesc) | Out-Null
        }
        elseif ($isBangBreaking) {
            $cleanSubject = $subject -replace '^\s*([A-Za-z]+(\([^)]*\))?)!\s*:\s*', ''
            $breaking.Add($cleanSubject) | Out-Null
        }

        if ($subject -match '^\s*feat(\([^)]*\))?!?\s*:\s*(?<d>.+)$') {
            $features.Add($Matches['d'].Trim()) | Out-Null
        }
        elseif ($subject -match '^\s*fix(\([^)]*\))?!?\s*:\s*(?<d>.+)$') {
            $fixes.Add($Matches['d'].Trim()) | Out-Null
        }
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("## [$Version] - $Date")
    [void]$sb.AppendLine()

    if ($breaking.Count -gt 0) {
        [void]$sb.AppendLine('### Breaking Changes')
        foreach ($b in $breaking) { [void]$sb.AppendLine("- $b") }
        [void]$sb.AppendLine()
    }
    if ($features.Count -gt 0) {
        [void]$sb.AppendLine('### Features')
        foreach ($f in $features) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }
    if ($fixes.Count -gt 0) {
        [void]$sb.AppendLine('### Fixes')
        foreach ($f in $fixes) { [void]$sb.AppendLine("- $f") }
        [void]$sb.AppendLine()
    }

    $sb.ToString()
}

function Read-CommitLog {
    <#
    .SYNOPSIS
        Read a fixture commit log, splitting on lines containing only `---`.
    .DESCRIPTION
        Test fixtures use `---` as a record separator between commits so we can
        represent multi-line commit bodies (needed for BREAKING CHANGE trailers).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Commit log file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    # Split on lines that contain only --- (with optional whitespace).
    # The regex uses multiline mode so ^ and $ match line boundaries.
    $parts = [System.Text.RegularExpressions.Regex]::Split($raw, '(?m)^\s*---\s*$')
    $parts | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Invoke-VersionBumper {
    <#
    .SYNOPSIS
        Top-level orchestrator. Reads version + commits, writes new version + changelog.
    .OUTPUTS
        A PSCustomObject with NewVersion, PreviousVersion, Bump fields.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$VersionFile,
        [Parameter(Mandatory)][string]$CommitLog,
        [Parameter(Mandatory)][string]$ChangelogFile,
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )

    $current = Get-SemanticVersion -Path $VersionFile
    $commits = Read-CommitLog -Path $CommitLog
    $bump = Get-CommitBumpType -Commits $commits
    $next = Step-SemanticVersion -Major $current.Major -Minor $current.Minor -Patch $current.Patch -Bump $bump
    $newVersionStr = "$($next.Major).$($next.Minor).$($next.Patch)"

    if ($bump -ne 'None') {
        Set-SemanticVersion -Path $VersionFile -Major $next.Major -Minor $next.Minor -Patch $next.Patch
        $entry = New-ChangelogEntry -Version $newVersionStr -Date $Date -Commits $commits
        $existing = ''
        if (Test-Path -LiteralPath $ChangelogFile) {
            $existing = Get-Content -LiteralPath $ChangelogFile -Raw
        }
        else {
            # Seed a new changelog with a standard header.
            $existing = "# Changelog`n`n"
        }
        # Prepend the new entry after the top-level heading block so the
        # newest release sits first.
        if ($existing -match '^(?<head># Changelog\s*\r?\n\s*)') {
            $head = $Matches['head']
            $rest = $existing.Substring($head.Length)
            $combined = $head + $entry + $rest
        }
        else {
            $combined = $entry + $existing
        }
        Set-Content -LiteralPath $ChangelogFile -Value $combined
    }

    [PSCustomObject]@{
        PreviousVersion = $current.Raw
        NewVersion      = $newVersionStr
        Bump            = $bump
    }
}

Export-ModuleMember -Function `
    Get-SemanticVersion, Set-SemanticVersion, Get-CommitBumpType, Step-SemanticVersion,
    New-ChangelogEntry, Read-CommitLog, Invoke-VersionBumper
