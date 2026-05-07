<#
.SYNOPSIS
  PR label assigner: maps changed files to a deduplicated label set using
  glob patterns and priority-based conflict resolution.

.DESCRIPTION
  Library + CLI. When dot-sourced, exposes `Get-PRLabels` and
  `Import-LabelRules` for Pester tests. When invoked as a script, reads a
  JSON rules file and a newline-delimited list of changed paths, then
  prints the matched label set (one per line by default, or JSON).

  Glob semantics:
    *  matches any run of characters except `/`
    ** matches any run of characters including `/`
    ?  matches any single character except `/`

  Conflict resolution:
    - Union (default): every matching rule contributes its label.
    - Priority:        for each file, only the highest-priority rule
                       (lowest Priority number) is allowed to assign a label.
                       Ties keep all tied labels.
#>
[CmdletBinding()]
param(
    [string] $ConfigPath,
    [string] $ChangedFilesPath,
    [ValidateSet('lines', 'json')]
    [string] $OutputFormat = 'lines',
    [ValidateSet('Union', 'Priority')]
    [string] $ConflictResolution = 'Union'
)

# Convert a glob pattern (with **, *, ?) into a .NET regex anchored to the full path.
function ConvertTo-GlobRegex {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Pattern)

    # Substitute glob tokens with placeholder sentinels first so we can
    # safely Regex.Escape the rest of the literal characters without
    # mangling the wildcards. Sentinels are characters that cannot appear
    # in path names.
    $doubleStarSlash = [char]0x0001 + [char]0x0001 + '/'
    $doubleStar      = [char]0x0001 + [char]0x0001
    $singleStar      = [char]0x0001
    $questionMark    = [char]0x0002

    $work = $Pattern -replace '\\', '/'  # normalize separators in the pattern itself

    # Order matters: handle ** before * so the longer token wins.
    $work = $work -replace '\*\*/', $doubleStarSlash
    $work = $work -replace '\*\*',  $doubleStar
    $work = $work -replace '\*',    $singleStar
    $work = $work -replace '\?',    $questionMark

    $escaped = [regex]::Escape($work)

    # Re-substitute sentinels with regex equivalents.
    $escaped = $escaped.Replace([regex]::Escape($doubleStarSlash), '(?:.*/)?')
    $escaped = $escaped.Replace([regex]::Escape($doubleStar),      '.*')
    $escaped = $escaped.Replace([regex]::Escape($singleStar),      '[^/]*')
    $escaped = $escaped.Replace([regex]::Escape($questionMark),    '[^/]')

    return "^$escaped$"
}

function Test-GlobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Pattern
    )
    $normalized = $Path -replace '\\', '/'
    $regex = ConvertTo-GlobRegex -Pattern $Pattern
    if ([regex]::IsMatch($normalized, $regex)) { return $true }

    # Convention: a pattern with no path separator (e.g. `*.test.*`) is
    # treated as a basename match. This matches the intuition users have
    # from .gitignore / actions/labeler — `*.md` should hit any markdown
    # file regardless of directory depth.
    if ($Pattern -notmatch '/') {
        $basename = Split-Path -Leaf $normalized
        return [regex]::IsMatch($basename, $regex)
    }
    return $false
}

function Get-PRLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $ChangedFiles,
        [Parameter(Mandatory)][object[]] $Rules,
        [ValidateSet('Union', 'Priority')]
        [string] $ConflictResolution = 'Union'
    )

    $labels = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($file in $ChangedFiles) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }

        # Find every rule whose glob matches this file.
        $matchingRules = foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) { $rule }
        }

        if (-not $matchingRules) { continue }

        if ($ConflictResolution -eq 'Priority') {
            # Lower Priority wins. Rules without a priority sort last.
            $withPriority = $matchingRules | ForEach-Object {
                $p = if ($null -ne $_.Priority) { [int]$_.Priority } else { [int]::MaxValue }
                [pscustomobject]@{ Rule = $_; Priority = $p }
            }
            $top = ($withPriority | Measure-Object -Property Priority -Minimum).Minimum
            $matchingRules = $withPriority |
                Where-Object { $_.Priority -eq $top } |
                ForEach-Object { $_.Rule }
        }

        foreach ($rule in $matchingRules) {
            [void]$labels.Add([string]$rule.Label)
        }
    }

    # Always return a sorted array for deterministic output. ,@() guards
    # against PowerShell unrolling a single-element collection to a scalar.
    return ,@($labels | Sort-Object)
}

function Import-LabelRules {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Config file is invalid JSON ($Path): $($_.Exception.Message)"
    }

    if ($null -eq $config.rules) {
        throw "Config file is missing the top-level 'rules' array: $Path"
    }

    $rules = foreach ($r in $config.rules) {
        if ([string]::IsNullOrWhiteSpace($r.pattern)) {
            throw "Rule is missing required 'pattern' field in $Path"
        }
        if ([string]::IsNullOrWhiteSpace($r.label)) {
            throw "Rule for pattern '$($r.pattern)' is missing required 'label' field in $Path"
        }
        $priority = if ($null -ne $r.priority) { [int]$r.priority } else { 100 }
        [pscustomobject]@{
            Pattern  = [string]$r.pattern
            Label    = [string]$r.label
            Priority = $priority
        }
    }

    return ,@($rules)
}

# CLI entry point — only fires when the script is run directly (not dot-sourced).
if ($MyInvocation.InvocationName -ne '.' -and $PSCommandPath -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    if (-not $ConfigPath) {
        Write-Error "Missing required parameter: -ConfigPath"
        exit 2
    }
    if (-not $ChangedFilesPath) {
        Write-Error "Missing required parameter: -ChangedFilesPath"
        exit 2
    }

    try {
        $rules = Import-LabelRules -Path $ConfigPath
    } catch {
        Write-Error $_.Exception.Message
        exit 3
    }

    if (-not (Test-Path -LiteralPath $ChangedFilesPath)) {
        Write-Error "Changed-files list not found: $ChangedFilesPath"
        exit 4
    }

    # @(...) collapses a possibly-null Get-Content result (empty file) to
    # an empty array so Get-PRLabels can still bind the parameter.
    $files = @(
        Get-Content -LiteralPath $ChangedFilesPath |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' }
    )

    $labels = Get-PRLabels -ChangedFiles $files -Rules $rules -ConflictResolution $ConflictResolution

    if ($OutputFormat -eq 'json') {
        # Force array semantics even for 0 or 1 labels.
        ,@($labels) | ConvertTo-Json -Compress
    } else {
        $labels | ForEach-Object { Write-Output $_ }
    }

    exit 0
}
