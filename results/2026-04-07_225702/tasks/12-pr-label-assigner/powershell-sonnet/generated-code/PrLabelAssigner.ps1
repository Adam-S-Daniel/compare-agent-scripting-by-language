# PrLabelAssigner.ps1
# Assigns GitHub PR labels based on configurable glob-pattern rules.
#
# Design:
#   - Rules are hashtables with keys: Pattern (string), Labels (string[]),
#     Priority (int, optional, lower = higher priority), and optionally
#     ExclusiveGroup (string) for single-winner label categories.
#   - Glob patterns follow minimatch conventions:
#       *   matches any characters except the path separator (/)
#       **  matches any characters including path separators
#       ?   matches any single character except /
#   - All matching rules contribute their labels to the result set.
#   - ExclusiveGroup: within a group, only the highest-priority matching
#     rule's labels are included (others in the group are suppressed).
#   - The final result is a sorted, deduplicated array of label strings.

# -----------------------------------------------------------------------------
# ConvertTo-GlobRegex
#   Converts a glob pattern string into an anchored regex pattern string.
#   The returned string can be used directly with PowerShell's -match operator.
# -----------------------------------------------------------------------------
function ConvertTo-GlobRegex {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Normalize path separators to forward slash
    $p = $Pattern -replace '\\', '/'

    # We build the regex character by character to handle ** vs * correctly.
    $regex = [System.Text.StringBuilder]::new()
    $null = $regex.Append('^')

    $i = 0
    while ($i -lt $p.Length) {
        $ch = $p[$i]

        if ($ch -eq '*') {
            # Peek ahead: is this ** ?
            if (($i + 1) -lt $p.Length -and $p[$i + 1] -eq '*') {
                # ** matches anything including path separators
                $null = $regex.Append('.*')
                $i += 2
                # Skip optional trailing slash after ** (e.g. "docs/**")
                # already handled by the .* eating the slash
            }
            else {
                # Single * matches anything except /
                $null = $regex.Append('[^/]*')
                $i++
            }
        }
        elseif ($ch -eq '?') {
            # ? matches any single character except /
            $null = $regex.Append('[^/]')
            $i++
        }
        else {
            # Escape all other characters for regex safety (handles . + ( ) etc.)
            $null = $regex.Append([regex]::Escape([string]$ch))
            $i++
        }
    }

    $null = $regex.Append('$')
    return $regex.ToString()
}

# -----------------------------------------------------------------------------
# Test-GlobMatch
#   Returns $true if $Path matches the given glob $Pattern.
# -----------------------------------------------------------------------------
function Test-GlobMatch {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Normalize separators so Windows paths work correctly
    $normalizedPath = $Path -replace '\\', '/'

    # If the pattern contains no path separator, match against the basename only.
    # This lets "*.test.*" match "src/api/users.test.ts" by testing against
    # "users.test.ts" — consistent with common glob tool conventions.
    if ($Pattern -notmatch '/') {
        $baseName = $normalizedPath -replace '^.*/', ''
        $regex = ConvertTo-GlobRegex -Pattern $Pattern
        return $baseName -match $regex
    }

    $regex = ConvertTo-GlobRegex -Pattern $Pattern
    return $normalizedPath -match $regex
}

# -----------------------------------------------------------------------------
# Get-PRLabels
#   Core function. Given a list of changed file paths and a set of rules,
#   returns the sorted, deduplicated array of labels to apply to the PR.
#
#   Parameters:
#     -ChangedFiles  : string[] — paths of files changed in the PR
#     -Rules         : hashtable[] — label rules; each must have:
#                        Pattern  (string)   — glob pattern
#                        Labels   (string[]) — labels to apply on match
#                      optional:
#                        Priority       (int)    — lower wins; defaults to 999
#                        ExclusiveGroup (string) — only the highest-priority
#                                                  matching rule in this group
#                                                  contributes its labels
# -----------------------------------------------------------------------------
function Get-PRLabels {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [hashtable[]]$Rules
    )

    # --- Validation ---
    if ($null -eq $Rules) {
        throw "Rules parameter cannot be null. Provide an empty array if no rules are desired."
    }

    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('Pattern')) {
            throw "Each rule must contain a 'Pattern' key. Found a rule missing 'Pattern'."
        }
        if (-not $rule.ContainsKey('Labels')) {
            throw "Each rule must contain a 'Labels' key. Found a rule missing 'Labels'."
        }
    }

    # Short-circuit: nothing to do
    if ($ChangedFiles.Count -eq 0 -or $Rules.Count -eq 0) {
        return @()
    }

    # --- Normalize rules: assign default Priority ---
    $normalizedRules = $Rules | ForEach-Object {
        $r = $_
        $priority = if ($r.ContainsKey('Priority')) { [int]$r.Priority } else { 999 }
        @{
            Pattern        = $r.Pattern
            Labels         = $r.Labels
            Priority       = $priority
            ExclusiveGroup = if ($r.ContainsKey('ExclusiveGroup')) { $r.ExclusiveGroup } else { $null }
        }
    }

    # Sort rules by Priority ascending (lower number = higher priority)
    $sortedRules = $normalizedRules | Sort-Object { $_.Priority }

    # --- Collect matching labels ---
    # For ExclusiveGroup rules: track the first (highest-priority) match per group
    $exclusiveGroupWinner = @{}   # group name -> $true once a winner is found

    $labelSet = [System.Collections.Generic.SortedSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($rule in $sortedRules) {
        # Check if this rule has an ExclusiveGroup and if the group already has a winner
        if ($null -ne $rule.ExclusiveGroup) {
            if ($exclusiveGroupWinner.ContainsKey($rule.ExclusiveGroup)) {
                # A higher-priority rule in this group already won; skip
                continue
            }
        }

        # Check if ANY changed file matches this rule's pattern
        $matched = $false
        foreach ($file in $ChangedFiles) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                $matched = $true
                break
            }
        }

        if ($matched) {
            # Record exclusive group winner
            if ($null -ne $rule.ExclusiveGroup) {
                $exclusiveGroupWinner[$rule.ExclusiveGroup] = $true
            }

            # Add all labels from this rule to the result set
            foreach ($label in $rule.Labels) {
                $null = $labelSet.Add($label)
            }
        }
    }

    # Return as a plain sorted string array
    return @($labelSet)
}
