# Invoke-PRLabelAssigner.ps1
# Assigns labels to a PR based on changed file paths and configurable rules.
# Supports glob patterns, multiple labels per file, and priority ordering.

param(
    # JSON string or file path containing the mapping rules
    [Parameter(Mandatory = $false)]
    [string]$RulesJson,

    # JSON array of changed file paths
    [Parameter(Mandatory = $false)]
    [string]$ChangedFilesJson
)

<#
.SYNOPSIS
    Converts a glob pattern to a regex pattern for matching file paths.
.DESCRIPTION
    Supports *, **, and ? wildcards commonly used in .gitignore-style globs.
#>
function Convert-GlobToRegex {
    param([string]$Glob)

    # Use a placeholder approach to avoid double-conversion issues.
    # Step 1: Replace ** with placeholders before escaping
    $result = $Glob -replace '\*\*/', '<<DOUBLESTAR_SLASH>>'
    $result = $result -replace '\*\*', '<<DOUBLESTAR>>'
    $result = $result -replace '\*', '<<STAR>>'
    $result = $result -replace '\?', '<<QUESTION>>'

    # Step 2: Escape all regex special characters
    $result = [regex]::Escape($result)

    # Step 3: Replace placeholders with regex equivalents
    # **/ matches zero or more directories
    $result = $result -replace '<<DOUBLESTAR_SLASH>>', '(.+/)?'
    # ** matches anything (including /)
    $result = $result -replace '<<DOUBLESTAR>>', '.*'
    # * matches anything except /
    $result = $result -replace '<<STAR>>', '[^/]*'
    # ? matches any single character except /
    $result = $result -replace '<<QUESTION>>', '[^/]'

    return "^${result}$"
}

<#
.SYNOPSIS
    Tests whether a file path matches a glob pattern.
#>
function Test-GlobMatch {
    param(
        [string]$Path,
        [string]$Pattern
    )

    $regex = Convert-GlobToRegex -Glob $Pattern
    return $Path -match $regex
}

<#
.SYNOPSIS
    Given a list of changed files and label rules, returns the set of labels to apply.
.DESCRIPTION
    Rules are objects with: pattern (glob), label (string), priority (int, lower = higher priority).
    When multiple rules match the same file, all labels are collected.
    Priority is used to order rule evaluation — higher-priority (lower number) rules are evaluated first.
    The final label set is deduplicated and sorted.
#>
function Get-PRLabels {
    param(
        [array]$ChangedFiles,
        [array]$Rules
    )

    if (-not $ChangedFiles -or $ChangedFiles.Count -eq 0) {
        Write-Warning "No changed files provided"
        return @()
    }

    if (-not $Rules -or $Rules.Count -eq 0) {
        Write-Warning "No rules provided"
        return @()
    }

    # Sort rules by priority (lower number = higher priority = evaluated first)
    $sortedRules = $Rules | Sort-Object { if ($null -ne $_.priority) { $_.priority } else { 999 } }

    $labels = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $sortedRules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.pattern) {
                [void]$labels.Add($rule.label)
            }
        }
    }

    return ($labels | Sort-Object)
}

# Main execution: parse inputs and run
if ($RulesJson -and $ChangedFilesJson) {
    try {
        $rules = $RulesJson | ConvertFrom-Json
        $changedFiles = $ChangedFilesJson | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse JSON input: $_"
        exit 1
    }

    $result = Get-PRLabels -ChangedFiles $changedFiles -Rules $rules

    if ($result.Count -gt 0) {
        Write-Output "LABELS_START"
        foreach ($label in $result) {
            Write-Output "LABEL:$label"
        }
        Write-Output "LABELS_END"
        Write-Output "LABEL_CSV:$($result -join ',')"
    }
    else {
        Write-Output "LABELS_START"
        Write-Output "LABELS_END"
        Write-Output "LABEL_CSV:"
    }
}
