# PR Label Assigner
# Assigns labels to a PR based on changed file paths and configurable glob-to-label rules.
# Supports glob patterns (**, *, ?), multiple labels per file, and priority ordering.

function Convert-GlobToRegex {
    <#
    .SYNOPSIS
        Converts a glob pattern to a regex pattern for file path matching.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Escape regex special chars first, then convert glob tokens
    $regex = [regex]::Escape($GlobPattern)

    # Convert escaped glob tokens back to regex equivalents
    # Order matters: handle ** before *
    $regex = $regex -replace '\\\*\\\*', '##DOUBLESTAR##'  # placeholder
    $regex = $regex -replace '\\\*', '[^/]*'               # * matches within a single path segment
    $regex = $regex -replace '##DOUBLESTAR##', '.*'        # ** matches across path segments
    $regex = $regex -replace '\\\?', '.'                   # ? matches single character

    return "^${regex}$"
}

function Get-PrLabels {
    <#
    .SYNOPSIS
        Determines which labels to apply based on changed files and path-to-label rules.
    .PARAMETER ChangedFiles
        Array of file paths changed in the PR.
    .PARAMETER Rules
        Array of hashtables with Pattern (glob), Label (string), and optional Priority (int).
        Lower priority number = higher precedence. Default priority is 0.
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [hashtable[]]$Rules
    )

    # Per-file tracking: for each file, record the best (lowest) priority and matching labels
    # This enables conflict resolution: when multiple rules match a file,
    # only the highest-priority (lowest number) rule's label is kept for that file.
    $fileBestPriority = @{}   # file -> lowest priority seen
    $fileLabelsByPriority = @{} # file -> hashtable of priority -> list of labels

    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('Pattern') -or -not $rule.ContainsKey('Label')) {
            Write-Warning "Skipping invalid rule: missing Pattern or Label key."
            continue
        }

        $pattern = $rule.Pattern
        $priority = if ($rule.ContainsKey('Priority')) { $rule.Priority } else { 0 }
        $regex = Convert-GlobToRegex -GlobPattern $pattern
        # If pattern has no path separator, match against filename only
        $matchBasename = -not $pattern.Contains('/')

        foreach ($file in $ChangedFiles) {
            $target = if ($matchBasename) { Split-Path -Leaf $file } else { $file }
            if ($target -match $regex) {
                if (-not $fileBestPriority.ContainsKey($file)) {
                    $fileBestPriority[$file] = $priority
                    $fileLabelsByPriority[$file] = @{ $priority = [System.Collections.Generic.List[string]]::new() }
                }

                if ($priority -lt $fileBestPriority[$file]) {
                    $fileBestPriority[$file] = $priority
                }

                if (-not $fileLabelsByPriority[$file].ContainsKey($priority)) {
                    $fileLabelsByPriority[$file][$priority] = [System.Collections.Generic.List[string]]::new()
                }
                $fileLabelsByPriority[$file][$priority].Add($rule.Label)
            }
        }
    }

    # Collect labels: for each file, only include labels from the best (lowest) priority tier
    $labels = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($file in $fileBestPriority.Keys) {
        $best = $fileBestPriority[$file]
        foreach ($label in $fileLabelsByPriority[$file][$best]) {
            [void]$labels.Add($label)
        }
    }

    return [string[]]@($labels)
}
