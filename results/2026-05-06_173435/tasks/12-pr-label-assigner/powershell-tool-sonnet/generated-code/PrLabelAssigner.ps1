# PrLabelAssigner.ps1
# Library: assign labels to a PR based on configurable glob-pattern rules.
#
# Public surface:
#   ConvertTo-GlobRegex  - glob string -> .NET regex string
#   Test-GlobMatch       - test one file path against one glob pattern
#   New-LabelRule        - construct a rule object
#   Get-PrLabels         - return the deduplicated, sorted label set for a file list
#   $DefaultLabelRules   - ready-to-use default rule set

#region --- Glob pattern matching ---

function ConvertTo-GlobRegex {
    <#
    .SYNOPSIS
        Converts a glob pattern to a .NET regex anchored at both ends.
    .NOTES
        Conversion order matters: replace '**' before '*' to avoid double-replacement.
        Handles: ** (any path), * (non-separator chars), ? (single non-separator char).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Escape all regex metacharacters first so we only deal with our three wildcards
    $regex = [System.Text.RegularExpressions.Regex]::Escape($GlobPattern)

    # Order is critical: replace escaped '**' before escaped '*'
    $regex = $regex -replace '\\\*\\\*', '.*'    # ** -> any path (including '/')
    $regex = $regex -replace '\\\*', '[^/]*'     # *  -> any chars except '/'
    $regex = $regex -replace '\\\?', '[^/]'      # ?  -> one char, not '/'

    return "^${regex}$"
}

function Test-GlobMatch {
    <#
    .SYNOPSIS
        Tests whether a file path matches a glob pattern.
    .NOTES
        Convention (matches GitHub Actions labeler behaviour):
        - Patterns containing '/' are matched against the full (forward-slash) path.
        - Patterns without '/' are matched against the filename (basename) only,
          so '*.test.*' picks up test files at any depth without needing '**/' prefix.
        Windows backslashes are normalised to '/' before comparison.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Normalise to forward slashes so callers don't need to care about OS
    $normalizedPath = $Path -replace '\\', '/'

    if ($GlobPattern -notmatch '/') {
        # No separator in pattern -> match against filename only
        $filename = Split-Path -Leaf $normalizedPath
        $regex    = ConvertTo-GlobRegex -GlobPattern $GlobPattern
        return $filename -match $regex
    }
    else {
        # Pattern has a separator -> match against full path
        $regex = ConvertTo-GlobRegex -GlobPattern $GlobPattern
        return $normalizedPath -match $regex
    }
}

#endregion

#region --- Rule construction ---

function New-LabelRule {
    <#
    .SYNOPSIS
        Constructs a label-rule object with Pattern, Label, and Priority.
    .NOTES
        Higher Priority values are evaluated first in Get-PrLabels.
        Default Priority is 0.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Label,

        [int]$Priority = 0
    )

    return [PSCustomObject]@{
        Pattern  = $Pattern
        Label    = $Label
        Priority = $Priority
    }
}

#endregion

#region --- Label assignment ---

function Get-PrLabels {
    <#
    .SYNOPSIS
        Returns the deduplicated, sorted set of labels for a list of changed files.
    .DESCRIPTION
        Rules are evaluated in descending Priority order.  Every matching rule
        contributes its label; labels from multiple rules or files are merged and
        deduplicated (case-insensitive).  The returned array is sorted alphabetically
        for deterministic output.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        # Changed file paths (relative to repo root, forward or backward slashes)
        [string[]]$ChangedFiles = @(),

        # Label rules to evaluate; each needs .Pattern, .Label, .Priority
        [PSCustomObject[]]$LabelRules = @()
    )

    if ($ChangedFiles.Count -eq 0 -or $LabelRules.Count -eq 0) {
        return [string[]]@()
    }

    # Higher priority -> evaluated first (all matches still accumulate)
    $sortedRules = $LabelRules | Sort-Object -Property Priority -Descending

    $labelSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $sortedRules) {
            if (Test-GlobMatch -Path $file -GlobPattern $rule.Pattern) {
                [void]$labelSet.Add($rule.Label)
            }
        }
    }

    return [string[]]@($labelSet | Sort-Object)
}

#endregion

#region --- Default configuration ---

# Ready-to-use rule set covering common PR label categories.
# Callers may pass their own rules to Get-PrLabels instead.
[PSCustomObject[]]$DefaultLabelRules = @(
    New-LabelRule -Pattern 'docs/**'      -Label 'documentation' -Priority 10
    New-LabelRule -Pattern 'src/api/**'   -Label 'api'           -Priority 8
    New-LabelRule -Pattern '*.test.*'     -Label 'tests'         -Priority 6
    New-LabelRule -Pattern '*.spec.*'     -Label 'tests'         -Priority 6
    New-LabelRule -Pattern '.github/**'   -Label 'ci/cd'         -Priority 5
    New-LabelRule -Pattern 'src/**'       -Label 'source'        -Priority 4
    New-LabelRule -Pattern '*.md'         -Label 'documentation' -Priority 2
)

#endregion
