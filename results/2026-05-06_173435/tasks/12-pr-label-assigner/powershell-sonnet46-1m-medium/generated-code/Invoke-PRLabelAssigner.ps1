# PR Label Assigner
# Applies labels to PRs based on configurable path-to-label mapping rules.
# Supports glob patterns (*, **, ?), multiple labels per file, priority ordering.
#
# TDD implementation: each function was added to make failing Pester tests pass.
# See Invoke-PRLabelAssigner.Tests.ps1 for the full test suite.

# Converts a glob pattern string into a .NET regex string.
# Glob rules implemented:
#   **/   zero-or-more path components (including none)
#   **    any sequence of characters including /
#   *     any characters within a single path segment (no /)
#   ?     any single character except /
#   All other regex metacharacters are escaped.
function ConvertTo-GlobRegex {
    param([string]$GlobPattern)

    $pattern = $GlobPattern -replace '\\', '/'
    $regex = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $pattern.Length; $i++) {
        $ch = $pattern[$i]

        switch ($ch) {
            '*' {
                $isDoubleStar = ($i + 1 -lt $pattern.Length) -and ($pattern[$i + 1] -eq '*')
                if ($isDoubleStar) {
                    $hasTrailingSlash = ($i + 2 -lt $pattern.Length) -and ($pattern[$i + 2] -eq '/')
                    if ($hasTrailingSlash) {
                        # **/ — match zero-or-more path components (including none)
                        [void]$regex.Append('(.+/)?')
                        $i += 2   # consume second * and /
                    } else {
                        # ** at end — match everything
                        [void]$regex.Append('.*')
                        $i++      # consume second *
                    }
                } else {
                    # * — match within a single segment
                    [void]$regex.Append('[^/]*')
                }
            }
            '?'  { [void]$regex.Append('[^/]') }
            '.'  { [void]$regex.Append('\.') }
            '+'  { [void]$regex.Append('\+') }
            '('  { [void]$regex.Append('\(') }
            ')'  { [void]$regex.Append('\)') }
            '['  { [void]$regex.Append('\[') }
            ']'  { [void]$regex.Append('\]') }
            '{'  { [void]$regex.Append('\{') }
            '}'  { [void]$regex.Append('\}') }
            '^'  { [void]$regex.Append('\^') }
            '$'  { [void]$regex.Append('\$') }
            '|'  { [void]$regex.Append('\|') }
            '\'  { [void]$regex.Append('\\') }
            default { [void]$regex.Append($ch) }
        }
    }

    return "^$($regex.ToString())`$"
}

# Tests whether a file path matches a glob pattern.
# Patterns without a path separator are matched against just the filename
# (so '*.test.*' matches 'src/utils.test.ps1').
function Test-GlobPattern {
    param(
        [string]$Pattern,
        [string]$FilePath
    )

    $FilePath = $FilePath -replace '\\', '/'
    $Pattern  = $Pattern  -replace '\\', '/'

    if ($Pattern -notmatch '/') {
        # No path separator → match against filename only (works at any depth)
        $fileName = [System.IO.Path]::GetFileName($FilePath)
        $regex    = ConvertTo-GlobRegex -GlobPattern $Pattern
        return [bool]($fileName -match $regex)
    }

    $regex = ConvertTo-GlobRegex -GlobPattern $Pattern
    return [bool]($FilePath -match $regex)
}

# Returns the deduplicated, sorted set of labels that apply to a list of changed files
# given an array of label rules.
#
# Each rule is a hashtable with:
#   Pattern  (string, required) — glob pattern
#   Label    (string, required) — label to apply
#   Priority (int,    optional) — lower number = evaluated first; default 999
#
# All matching rules contribute labels (union semantics).
# Priority controls evaluation order; the final label set is sorted alphabetically
# for deterministic output.
function Get-PRLabels {
    param(
        [string[]]  $ChangedFiles,
        [hashtable[]]$LabelRules
    )

    if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) {
        Write-Warning "No changed files provided"
        return @()
    }

    if (-not $LabelRules -or $LabelRules.Count -eq 0) {
        Write-Warning "No label rules provided"
        return @()
    }

    # Sort by priority (lower = higher precedence)
    $sortedRules = $LabelRules | Sort-Object {
        if ($null -ne $_.Priority) { [int]$_.Priority } else { 999 }
    }

    $labelSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $sortedRules) {
            if (Test-GlobPattern -Pattern $rule.Pattern -FilePath $file) {
                [void]$labelSet.Add($rule.Label)
            }
        }
    }

    # Alphabetical sort for deterministic output
    return @($labelSet | Sort-Object)
}

# Entry point: assigns labels and writes human-readable output.
# Returns the label array for downstream consumption.
function Invoke-PRLabelAssigner {
    param(
        [string[]]   $ChangedFiles,
        [hashtable[]]$LabelRules
    )

    $labels = Get-PRLabels -ChangedFiles $ChangedFiles -LabelRules $LabelRules

    if ($labels.Count -eq 0) {
        Write-Host "No labels matched"
    } else {
        Write-Host "Applied labels: $($labels -join ', ')"
    }

    return $labels
}
