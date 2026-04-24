# PR Label Assigner
# Assigns labels to a PR based on configurable glob-pattern-to-label mapping rules.
# Supports ** (any path depth), * (single segment wildcard), ? (single char wildcard).

function ConvertGlobToRegex {
    <#
    .SYNOPSIS
    Converts a glob pattern to a .NET regex string.
    Supports: ** (multi-segment), * (single-segment), ? (single char).
    Patterns without a directory separator are matched against the basename
    (i.e., the filename can appear at any depth).
    #>
    param([string]$Glob)

    $escaped = [System.Text.RegularExpressions.Regex]::Escape($Glob)

    # Replace escaped wildcards with regex equivalents (order matters)
    # ** -> match anything including path separators
    $escaped = $escaped -replace '\\\*\\\*', '@@DOUBLESTAR@@'
    # * -> match anything except path separators
    $escaped = $escaped -replace '\\\*', '[^/\\]*'
    # ? -> match any single character except path separator
    $escaped = $escaped -replace '\\\?', '[^/\\]'
    # Restore ** -> match any characters including slashes
    $escaped = $escaped -replace '@@DOUBLESTAR@@', '.*'

    # Patterns with no directory separator match basename at any depth
    if ($Glob -notmatch '[/\\]') {
        return "^(.*[/\\])?$escaped$"
    }

    return "^$escaped"
}

function Get-MatchingLabels {
    <#
    .SYNOPSIS
    Given a list of file paths and label rules, returns the deduplicated,
    priority-sorted set of labels that apply to those files.
    #>
    param(
        [string[]]$FilePaths,
        [hashtable[]]$Rules
    )

    # Track label -> max priority seen, and matched label set
    $labelPriority = @{}

    foreach ($file in $FilePaths) {
        foreach ($rule in $Rules) {
            $regex = ConvertGlobToRegex -Glob $rule.Pattern
            if ($file -match $regex) {
                $label = $rule.Label
                $priority = $rule.Priority
                if (-not $labelPriority.ContainsKey($label) -or $priority -gt $labelPriority[$label]) {
                    $labelPriority[$label] = $priority
                }
            }
        }
    }

    if ($labelPriority.Count -eq 0) { return @() }

    # Return labels sorted by priority descending
    return $labelPriority.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        Select-Object -ExpandProperty Key
}

function ConvertFrom-LabelRulesJson {
    <#
    .SYNOPSIS
    Parses a JSON string into an array of rule hashtables.
    Each object must have Pattern, Label, and Priority fields.
    #>
    param([string]$Json)

    $parsed = $Json | ConvertFrom-Json
    return @($parsed | ForEach-Object {
        @{ Pattern = $_.Pattern; Label = $_.Label; Priority = [int]$_.Priority }
    })
}

function Invoke-PrLabelAssigner {
    <#
    .SYNOPSIS
    Main entry point. Given PR file paths and label rules, returns a result object
    with the final label set and per-file label mappings.

    .OUTPUTS
    PSCustomObject with:
      Labels       - string[] sorted by priority descending
      MatchedFiles - hashtable mapping file path -> string[] of matching labels
    #>
    param(
        [string[]]$FilePaths,
        [hashtable[]]$Rules
    )

    if ($null -eq $FilePaths) {
        throw "FilePaths parameter must not be null."
    }
    if ($null -eq $Rules) {
        throw "Rules parameter must not be null."
    }

    # Build per-file label mapping
    $matchedFiles = @{}
    foreach ($file in $FilePaths) {
        $fileLabels = @()
        foreach ($rule in $Rules) {
            $regex = ConvertGlobToRegex -Glob $rule.Pattern
            if ($file -match $regex) {
                $fileLabels += $rule.Label
            }
        }
        if ($fileLabels.Count -gt 0) {
            $matchedFiles[$file] = $fileLabels | Select-Object -Unique
        }
    }

    $labels = Get-MatchingLabels -FilePaths $FilePaths -Rules $Rules

    return [PSCustomObject]@{
        Labels       = $labels
        MatchedFiles = $matchedFiles
    }
}
