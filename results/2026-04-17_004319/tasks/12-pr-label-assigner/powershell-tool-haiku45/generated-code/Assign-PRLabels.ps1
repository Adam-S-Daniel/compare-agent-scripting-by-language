# PR Label Assigner - Assigns labels to PR files based on configurable path-to-label mapping rules
# Supports glob patterns, multiple labels per file, and priority ordering

function ConvertGlobToRegex {
    # Converts glob patterns to regex patterns for matching
    # Handles ** (matches any number of directories) and * (matches within a single path segment)
    param(
        [string]$Pattern
    )

    # Escape regex special chars except * and ?
    $escaped = [regex]::Escape($Pattern) -replace '\\\*', '__GLOB_STAR__' -replace '\\\?', '__GLOB_QUESTION__'

    # Replace ** with regex that matches any path
    $escaped = $escaped -replace '__GLOB_STAR____GLOB_STAR__', '.*'

    # Replace remaining * with regex that matches any chars except path separator
    $escaped = $escaped -replace '__GLOB_STAR__', '[^/\\]*'
    $escaped = $escaped -replace '__GLOB_QUESTION__', '.'

    # Anchor the pattern
    return "^$escaped$"
}

function Test-GlobMatch {
    # Tests if a file path matches a glob pattern
    param(
        [string]$FilePath,
        [string]$Pattern
    )

    # Normalize paths for comparison (case-insensitive, forward slashes)
    $normalizedFile = ($FilePath -replace '\\', '/').ToLower()
    $normalizedPattern = ($Pattern -replace '\\', '/').ToLower()

    $regex = ConvertGlobToRegex -Pattern $normalizedPattern
    return $normalizedFile -match $regex
}

function Get-PRLabels {
    # Assigns labels to PR files based on configurable rules
    # Parameters:
    #   Files: array of file paths
    #   Rules: hash table mapping patterns to labels, or array of rule objects with pattern/labels/priority
    #   UsePriority: whether to use priority ordering (default: $false)
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Files,

        [Parameter(Mandatory = $true)]
        $Rules,

        [bool]$UsePriority = $false
    )

    # Validate inputs
    if ($null -eq $Files -or $Files.Count -eq 0) {
        throw "Files parameter cannot be null or empty"
    }

    if ($null -eq $Rules) {
        throw "Rules parameter cannot be null"
    }

    # Check if any file is null
    foreach ($file in $Files) {
        if ($null -eq $file -or [string]::IsNullOrWhiteSpace($file)) {
            throw "Invalid file path: null or whitespace not allowed"
        }
    }

    $labels = @()
    $labelSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Handle Rules as array of priority objects
    if ($Rules -is [array] -and $Rules.Count -gt 0 -and $Rules[0] -is [hashtable] -and $Rules[0].ContainsKey('pattern')) {
        # Sort by priority if UsePriority is true
        if ($UsePriority) {
            $sortedRules = $Rules | Sort-Object -Property priority
        }
        else {
            $sortedRules = $Rules
        }

        foreach ($file in $Files) {
            foreach ($rule in $sortedRules) {
                $pattern = $rule.pattern
                $ruleLabels = $rule.labels

                if (Test-GlobMatch -FilePath $file -Pattern $pattern) {
                    foreach ($label in $ruleLabels) {
                        [void]$labelSet.Add($label)
                    }
                    # With priority, take first match and move to next file
                    if ($UsePriority) {
                        break
                    }
                }
            }
        }
    }
    # Handle Rules as simple hash table (pattern -> labels)
    else {
        if ($Rules.Count -eq 0) {
            throw "Rules cannot be empty"
        }

        foreach ($file in $Files) {
            foreach ($pattern in $Rules.Keys) {
                if (Test-GlobMatch -FilePath $file -Pattern $pattern) {
                    $ruleLabels = $Rules[$pattern]

                    # Handle both single label (string) and multiple labels (array)
                    if ($ruleLabels -is [array]) {
                        foreach ($label in $ruleLabels) {
                            [void]$labelSet.Add($label)
                        }
                    }
                    else {
                        [void]$labelSet.Add($ruleLabels)
                    }
                }
            }
        }
    }

    # Return sorted labels for consistent output
    return $labelSet | Sort-Object
}
