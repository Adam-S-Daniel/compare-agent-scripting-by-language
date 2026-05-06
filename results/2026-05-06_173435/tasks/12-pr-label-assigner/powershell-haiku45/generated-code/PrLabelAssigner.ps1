function Test-GlobMatch {
    # Test if a file path matches a glob pattern (case-sensitive)
    param(
        [string]$Path,
        [string]$Pattern
    )

    # Convert glob pattern to regex
    # Use placeholders to avoid replacing already-replaced patterns
    $regexPattern = $Pattern

    # Escape special regex characters except our glob ones
    $regexPattern = $regexPattern -replace '\.', '\.'       # Escape dots

    # Use placeholders for ** and ? to avoid conflicts
    $regexPattern = $regexPattern -replace '\*\*', '__DOUBLESTAR__'
    $regexPattern = $regexPattern -replace '\?', '__QUESTION__'
    $regexPattern = $regexPattern -replace '\*', '[^/]*'    # * matches anything except /

    # Now replace placeholders with their regex equivalents
    $regexPattern = $regexPattern -replace '__DOUBLESTAR__', '.*'       # ** matches anything
    $regexPattern = $regexPattern -replace '__QUESTION__', '.'         # ? matches single char

    # Anchor the pattern
    $regexPattern = "^$regexPattern$"

    # Use [regex] for case-sensitive matching
    return [regex]::IsMatch($Path, $regexPattern)
}

function Get-PrLabels {
    <#
    .SYNOPSIS
    Applies labels to files based on configurable path-to-label mapping rules.

    .DESCRIPTION
    Takes a list of file paths and applies labels based on matching rules.
    Rules can have glob patterns and priority values. When rules with the same
    pattern match the same file, only the highest priority rules' labels are applied.
    Rules with different patterns all apply.

    .PARAMETER Files
    Array of file paths to process.

    .PARAMETER Rules
    Array of rule objects with pattern, labels, and priority properties.
    #>
    param(
        [string[]]$Files,
        [array]$Rules
    )

    $allLabels = @()

    foreach ($file in $Files) {
        # Find all rules that match this file
        $matchingRules = @()

        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.pattern) {
                $matchingRules += $rule
            }
        }

        # If no rules match, skip this file
        if ($matchingRules.Count -eq 0) {
            continue
        }

        # Group matching rules by pattern
        $rulesByPattern = $matchingRules | Group-Object -Property pattern

        # For each pattern group, apply only the highest priority rules
        foreach ($patternGroup in $rulesByPattern) {
            $maxPriority = ($patternGroup.Group | Measure-Object -Property priority -Maximum).Maximum
            foreach ($rule in $patternGroup.Group) {
                if ($rule.priority -eq $maxPriority) {
                    $allLabels += $rule.labels
                }
            }
        }
    }

    # Return unique labels, sorted for consistent output
    return $allLabels | Sort-Object -Unique
}
