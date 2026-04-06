# PRLabelAssigner.ps1
# PR Label Assigner - assigns GitHub-style labels to PRs based on changed file paths.
#
# Design decisions (driven by TDD):
#   - Glob patterns: *, **, ?  (same semantics as gitignore / GitHub labeler action)
#   - Patterns without a '/' automatically match anywhere in the tree (prepend **/)
#   - Rules are sorted by Priority (lower number = higher priority)
#   - All matching rules contribute labels; duplicates are removed in priority order
#   - Label output order reflects rule priority so the caller sees the "most important" labels first

# ---------------------------------------------------------------------------
# ConvertGlobToRegex
# ---------------------------------------------------------------------------
# Translates a glob pattern into an anchored regular expression string.
#
#   *   → matches any characters except '/'
#   **/ → matches zero or more directory components (including the trailing /)
#   **  → matches everything (used at the end of a pattern)
#   ?   → matches a single character except '/'
#
# Patterns that contain no '/' are normalised to "**/<pattern>" so that
# e.g. "*.test.*" matches test files at any depth, not just the root.
function ConvertGlobToRegex {
    param(
        [string]$Pattern
    )

    # Normalise: a pattern with no directory separator should match anywhere in the tree.
    # e.g.  "*.test.*"  →  "**/*.test.*"
    if ($Pattern -notmatch '/') {
        $Pattern = "**/$Pattern"
    }

    $regex = [System.Text.StringBuilder]::new()
    $chars = $Pattern.ToCharArray()
    $len   = $chars.Length
    $i     = 0

    while ($i -lt $len) {
        $c = $chars[$i]

        if ($c -eq '*' -and ($i + 1) -lt $len -and $chars[$i + 1] -eq '*') {
            # --- double star ---
            $i += 2
            if ($i -lt $len -and $chars[$i] -eq '/') {
                # "**/" at a path boundary: match zero or more directory levels
                # "(.+/)?" means "something/", or nothing at all (empty = root)
                [void]$regex.Append('(.+/)?')
                $i++   # consume the '/'
            } else {
                # "**" at the end (or not followed by /): match everything remaining
                [void]$regex.Append('.*')
            }
        } elseif ($c -eq '*') {
            # --- single star: match anything except '/' ---
            [void]$regex.Append('[^/]*')
            $i++
        } elseif ($c -eq '?') {
            # --- question mark: match exactly one character except '/' ---
            [void]$regex.Append('[^/]')
            $i++
        } else {
            # --- literal character: escape for use in a regex ---
            [void]$regex.Append([regex]::Escape([string]$c))
            $i++
        }
    }

    return "^$($regex.ToString())$"
}

# ---------------------------------------------------------------------------
# Test-GlobMatch
# ---------------------------------------------------------------------------
# Returns $true when $Path matches the glob $Pattern.
# Normalises Windows backslash separators to '/' before matching.
function Test-GlobMatch {
    param(
        [string]$Path,
        [string]$Pattern
    )

    # Normalise path separators so Windows paths work correctly.
    $normalizedPath = $Path -replace '\\', '/'

    try {
        $regexPattern = ConvertGlobToRegex -Pattern $Pattern
        return [bool]($normalizedPath -match $regexPattern)
    } catch {
        Write-Warning "Invalid glob pattern '$Pattern': $_"
        return $false
    }
}

# ---------------------------------------------------------------------------
# Get-PRLabels
# ---------------------------------------------------------------------------
# Given a list of changed file paths and a set of labelling rules, returns
# the deduplicated set of labels that apply to this PR, ordered by rule priority.
#
# Parameters:
#   ChangedFiles  – [string[]] list of file paths changed in the PR
#   Rules         – [hashtable[]] array of rule objects with keys:
#                     Pattern  : glob pattern  (string)
#                     Labels   : labels to apply when matched  (string[])
#                     Priority : integer; lower value = higher priority
#
# Returns: [string[]] unique labels in priority order.
function Get-PRLabels {
    param(
        [string[]]  $ChangedFiles,
        [hashtable[]]$Rules
    )

    # Guard: nothing to process.
    if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) { return @() }
    if (-not $Rules        -or $Rules.Count        -eq 0) { return @() }

    # Sort rules: lower Priority number is evaluated first (= higher importance).
    # Rules without a Priority key are pushed to the end.
    $sortedRules = $Rules | Sort-Object {
        if ($null -ne $_.Priority) { [int]$_.Priority } else { [int]::MaxValue }
    }

    # Collect labels in insertion order while avoiding duplicates.
    # Using a List for ordered storage and a HashSet for O(1) membership tests.
    $orderedLabels = [System.Collections.Generic.List[string]]::new()
    $seenLabels    = [System.Collections.Generic.HashSet[string]]::new(
                        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($rule in $sortedRules) {
        # Determine whether any changed file matches this rule.
        $ruleMatched = $false
        foreach ($file in $ChangedFiles) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                $ruleMatched = $true
                break
            }
        }

        if ($ruleMatched) {
            # Add each label from the rule; skip ones already present (dedup).
            foreach ($label in $rule.Labels) {
                if ($seenLabels.Add($label)) {
                    $orderedLabels.Add($label)
                }
            }
        }
    }

    return @($orderedLabels)
}
