#Requires -Version 7.0
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    PR Label Assigner — maps changed file paths to PR labels using configurable glob rules.

.DESCRIPTION
    This module implements TDD-driven label assignment for pull requests.
    Approach:
      1. Rules are defined as hashtables: Pattern (glob), Label (string), Priority (int).
      2. Each file path is tested against every rule using PowerShell wildcard matching
         after translating '**' glob syntax to the equivalent '*' wildcard.
      3. All matching rules contribute their labels to a result set.
      4. Labels are deduplicated and ordered by descending rule priority so that
         the highest-priority labels appear first in the output array.
#>

# ---------------------------------------------------------------------------
# Convert-GlobToWildcard
# ---------------------------------------------------------------------------
function Convert-GlobToWildcard {
    <#
    .SYNOPSIS
        Translates a glob pattern containing '**' into a PowerShell wildcard pattern.
    .DESCRIPTION
        PowerShell's -like operator supports '*' (any chars) and '?' (single char).
        The glob '**' means "zero or more path segments". Because PowerShell's '*'
        already matches path separator characters, replacing '**' with '*' produces
        the correct behaviour.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Replace every occurrence of '**' with '*'.
    # A simple string replacement suffices; no regex needed.
    return $GlobPattern -replace '\*\*', '*'
}

# ---------------------------------------------------------------------------
# Test-FileMatchesPattern
# ---------------------------------------------------------------------------
function Test-FileMatchesPattern {
    <#
    .SYNOPSIS
        Returns $true if the supplied file path matches the glob pattern.
    .DESCRIPTION
        Converts the glob pattern to a PowerShell wildcard (via Convert-GlobToWildcard)
        then uses the -like operator for case-insensitive matching.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    [string]$wildcardPattern = Convert-GlobToWildcard -GlobPattern $GlobPattern
    # -like is case-insensitive on all platforms in PowerShell 7
    return [bool]($FilePath -like $wildcardPattern)
}

# ---------------------------------------------------------------------------
# Get-PRLabels  (primary public function)
# ---------------------------------------------------------------------------
function Get-PRLabels {
    <#
    .SYNOPSIS
        Returns the set of labels to apply to a PR given its changed file paths.
    .DESCRIPTION
        Algorithm:
          1. Validate that every rule hashtable contains Pattern, Label, and Priority keys.
          2. Sort rules by Priority descending (highest priority evaluated first).
          3. For each rule, check whether any file in the list matches the rule's pattern.
          4. If at least one file matches, add the rule's label to the result set (if not
             already present, preserving first-seen / priority order).
          5. Return the ordered, deduplicated label array.

        Priority ordering:
          Higher Priority values are evaluated first, so their labels appear earlier in
          the output array. When two rules share the same priority, tie-breaking follows
          the order they appear in the input Rules array.

        Conflict resolution:
          "Conflict" here means two rules producing the same label string. Because we
          deduplicate by label value, only the highest-priority rule's occurrence is kept
          in the output — but since the label is the same string, the net effect is that
          the label appears exactly once at the position determined by priority.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        # The list of file paths changed in the PR (can be empty).
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$FilePaths,

        # Ordered collection of label rules.  Each entry must be a hashtable with:
        #   Pattern  [string] — glob pattern (supports ** for recursive matching)
        #   Label    [string] — label to apply when pattern matches
        #   Priority [int]    — higher value = higher priority
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Rules
    )

    # --- Validate rules -------------------------------------------------------
    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('Pattern')) {
            throw "Invalid rule: missing required key 'Pattern'. Rule keys: $($rule.Keys -join ', ')"
        }
        if (-not $rule.ContainsKey('Label')) {
            throw "Invalid rule: missing required key 'Label'. Rule keys: $($rule.Keys -join ', ')"
        }
        if (-not $rule.ContainsKey('Priority')) {
            throw "Invalid rule: missing required key 'Priority'. Rule keys: $($rule.Keys -join ', ')"
        }
    }

    # --- Short-circuit: nothing to do -----------------------------------------
    if ($FilePaths.Count -eq 0 -or $Rules.Count -eq 0) {
        return [string[]]@()
    }

    # --- Sort rules by priority descending ------------------------------------
    # Use pipeline + Sort-Object; result is an array of hashtables.
    [hashtable[]]$sortedRules = @($Rules | Sort-Object -Property { [int]$_['Priority'] } -Descending)

    # Ordered, deduplicated label list (preserves insertion order = priority order)
    [System.Collections.Generic.List[string]]$labelSet = [System.Collections.Generic.List[string]]::new()

    foreach ($rule in $sortedRules) {
        [string]$pattern = [string]$rule['Pattern']
        [string]$label   = [string]$rule['Label']

        # Check whether any file matches this rule's pattern
        [bool]$anyMatch = $false
        foreach ($filePath in $FilePaths) {
            if (Test-FileMatchesPattern -FilePath $filePath -GlobPattern $pattern) {
                $anyMatch = $true
                break
            }
        }

        if ($anyMatch -and -not $labelSet.Contains($label)) {
            $labelSet.Add($label)
        }
    }

    return [string[]]$labelSet.ToArray()
}

# Export public functions only; internal helpers are exported for testability
Export-ModuleMember -Function 'Convert-GlobToWildcard', 'Test-FileMatchesPattern', 'Get-PRLabels'
