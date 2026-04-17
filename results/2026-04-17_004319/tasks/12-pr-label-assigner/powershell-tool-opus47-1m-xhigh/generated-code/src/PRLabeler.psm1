# PRLabeler.psm1
# A small PR-label-assignment engine.
# Given a list of changed file paths and a set of rules (pattern -> labels),
# returns the deduplicated label set, ordered by descending rule priority.
#
# Patterns are glob-style:
#   **    matches any characters including '/'
#   *     matches any characters except '/'
#   ?     matches a single non-'/' character
#   Other regex metacharacters are escaped.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Convert-GlobToRegex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Glob
    )
    # Tokenize to sidestep ordering issues between '**/', '**', '*', and '?'.
    # '**/' -> zero-or-more directory segments (so **/x matches both 'x' and 'a/b/x').
    $GLOBSTAR_SLASH = [char]0x0001  # **/
    $GLOBSTAR       = [char]0x0002  # **
    $STAR           = [char]0x0003  # *
    $QMARK          = [char]0x0004  # ?

    $work = $Glob `
        -replace '\*\*/', $GLOBSTAR_SLASH `
        -replace '\*\*',  $GLOBSTAR `
        -replace '\*',    $STAR `
        -replace '\?',    $QMARK

    $escaped = [regex]::Escape($work)

    $regex = $escaped `
        -replace [regex]::Escape([string]$GLOBSTAR_SLASH), '(?:.*/)?' `
        -replace [regex]::Escape([string]$GLOBSTAR),       '.*' `
        -replace [regex]::Escape([string]$STAR),           '[^/]*' `
        -replace [regex]::Escape([string]$QMARK),          '[^/]'

    return '^' + $regex + '$'
}

function Test-GlobMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Pattern
    )
    $rx = Convert-GlobToRegex -Glob $Pattern
    return [bool]([regex]::IsMatch($Path, $rx))
}

function Get-PRLabels {
    <#
    .SYNOPSIS
      Compute the label set for a list of changed files based on configurable rules.

    .PARAMETER Files
      Array of changed file paths (forward-slash separated).

    .PARAMETER Rules
      Array of rule hashtables/PSObjects. Each rule must have 'pattern' (string)
      and 'labels' (array of strings). Optional 'priority' (int, default 0).

    .PARAMETER ConfigPath
      Path to a JSON file that contains { "rules": [ ... ] }. Either Rules or
      ConfigPath must be supplied (not both).

    .OUTPUTS
      [string[]] - deduplicated label set, sorted descending by max rule priority.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Files,

        [Parameter()]
        [object[]] $Rules,

        [Parameter()]
        [string] $ConfigPath
    )

    if (-not $Rules -and -not $ConfigPath) {
        throw "Either -Rules or -ConfigPath must be provided."
    }

    if ($ConfigPath) {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Config file not found: $ConfigPath"
        }
        $raw = Get-Content -LiteralPath $ConfigPath -Raw
        try {
            $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Failed to parse JSON config '$ConfigPath': $($_.Exception.Message)"
        }
        if (-not $parsed.PSObject.Properties.Name -contains 'rules') {
            throw "Config file must contain a top-level 'rules' array."
        }
        $Rules = @($parsed.rules)
    }

    # Normalize rules and validate required fields.
    $normalized = foreach ($rule in $Rules) {
        $pattern  = $null
        $labels   = $null
        $priority = 0

        if ($rule -is [hashtable] -or $rule -is [System.Collections.IDictionary]) {
            if ($rule.ContainsKey('pattern'))  { $pattern  = [string]$rule['pattern'] }
            if ($rule.ContainsKey('labels'))   { $labels   = @($rule['labels']) }
            if ($rule.ContainsKey('priority')) { $priority = [int]$rule['priority'] }
        } else {
            # PSCustomObject (e.g. from ConvertFrom-Json)
            $props = $rule.PSObject.Properties
            if ($props['pattern'])  { $pattern  = [string]$props['pattern'].Value }
            if ($props['labels'])   { $labels   = @($props['labels'].Value) }
            if ($props['priority']) { $priority = [int]$props['priority'].Value }
        }

        if ([string]::IsNullOrWhiteSpace($pattern)) {
            throw "Invalid rule: missing or empty 'pattern' field."
        }
        if ($null -eq $labels -or $labels.Count -eq 0) {
            throw "Invalid rule for pattern '$pattern': missing or empty 'labels' field."
        }

        [pscustomobject]@{
            Pattern  = $pattern
            Labels   = $labels
            Priority = $priority
            Regex    = Convert-GlobToRegex -Glob $pattern
        }
    }

    # For each label, track the highest priority from any rule that matched any file.
    $labelPriority = @{}   # label -> max priority
    $labelFirstSeen = @{}  # label -> insertion counter (for stable tiebreak)
    $counter = 0

    foreach ($file in $Files) {
        foreach ($rule in $normalized) {
            if ([regex]::IsMatch($file, $rule.Regex)) {
                foreach ($label in $rule.Labels) {
                    if (-not $labelPriority.ContainsKey($label)) {
                        $labelPriority[$label]  = $rule.Priority
                        $labelFirstSeen[$label] = $counter
                        $counter++
                    } elseif ($rule.Priority -gt $labelPriority[$label]) {
                        $labelPriority[$label] = $rule.Priority
                    }
                }
            }
        }
    }

    # Sort: descending priority, then by first-seen order for stable output.
    $ordered = $labelPriority.Keys |
        Sort-Object @{Expression = { $labelPriority[$_] }; Descending = $true}, `
                    @{Expression = { $labelFirstSeen[$_] }; Descending = $false}

    # Force array return (avoid collapsing to scalar on single-item result).
    return ,@($ordered)
}

Export-ModuleMember -Function Convert-GlobToRegex, Test-GlobMatch, Get-PRLabels
