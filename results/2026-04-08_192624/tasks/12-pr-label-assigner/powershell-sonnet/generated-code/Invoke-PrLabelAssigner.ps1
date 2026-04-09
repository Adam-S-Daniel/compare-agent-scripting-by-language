# PR Label Assigner
# Assigns labels to pull requests based on changed file paths using configurable glob patterns.
#
# TDD Iteration Log:
#   RED  1: Tests written for ConvertTo-GlobRegex, Test-GlobMatch, Get-PrLabels
#   GREEN 1: Implemented glob regex conversion and core label assignment
#   RED  2: Tests added for priority ordering, edge cases
#   GREEN 2: Added priority-based sorting, null handling, path normalization
#   REFACTOR: param block moved to top (PowerShell requirement); extracted helpers

# param MUST be the very first non-comment statement in the script file.
# When dot-sourced in tests, these params are simply ignored.
param(
    [string]$ChangedFilesJson,
    [string]$RulesFile,
    [string]$ChangedFilesFile
)

# ============================================================
# GLOB PATTERN MATCHING
# ============================================================

function ConvertTo-GlobRegex {
    <#
    .SYNOPSIS
        Converts a glob pattern to a .NET regular expression string.
    .DESCRIPTION
        Supports:
          **  - matches any sequence of characters including path separators
          *   - matches any sequence of characters EXCEPT path separators (/ or \)
          ?   - matches exactly one character EXCEPT path separators
          .   - literal dot (escaped automatically)
        Pattern is anchored at both ends (^ and $).
    .EXAMPLE
        ConvertTo-GlobRegex "docs/**"         -> ^docs/.*$
        ConvertTo-GlobRegex "*.test.*"        -> ^[^/\\]*\.test\.[^/\\]*$
        ConvertTo-GlobRegex "**/*.test.*"     -> ^.*/[^/\\]*\.test\.[^/\\]*$
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Split on ** FIRST to preserve double-star semantics before escaping
    $parts = $Pattern -split '\*\*'

    # For each part: escape regex special chars, then convert remaining glob wildcards
    $escapedParts = $parts | ForEach-Object {
        $escaped = [regex]::Escape($_)
        # Single * -> match any chars except path separators
        $escaped = $escaped -replace '\\\*', '[^/\\]*'
        # ? -> match single char except path separators
        $escaped = $escaped -replace '\\\?', '[^/\\]'
        $escaped
    }

    # Rejoin with .* (the ** expansion - matches anything including path separators)
    $regexBody = $escapedParts -join '.*'

    return "^${regexBody}$"
}

function Test-GlobMatch {
    <#
    .SYNOPSIS
        Tests whether a file path matches a glob pattern.
    .PARAMETER Path
        The file path to test (forward or backward slashes accepted).
    .PARAMETER Pattern
        A glob pattern supporting *, **, and ?.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Normalize path separators to forward slashes for consistent matching
    $normalizedPath = $Path -replace '\\', '/'

    $regex = ConvertTo-GlobRegex -Pattern $Pattern
    return [bool]($normalizedPath -match $regex)
}

# ============================================================
# CORE LABEL ASSIGNMENT
# ============================================================

function Get-PrLabels {
    <#
    .SYNOPSIS
        Assigns labels to a PR based on changed file paths and configurable rules.
    .DESCRIPTION
        Evaluates each changed file path against each rule's glob pattern.
        A label is added to the result set whenever a file matches a rule.
        Labels are deduplicated and sorted by priority (highest first);
        ties are broken alphabetically.
    .PARAMETER Files
        Array of changed file paths (as would appear in a PR diff).
    .PARAMETER Rules
        Array of rule objects. Each rule must have:
          Pattern  - glob string (supports *, **, ?)
          Label    - label string to apply when a file matches
          Priority - integer; higher values appear first in output (optional, default 0)
    .OUTPUTS
        [string[]] Sorted array of unique label strings.
    .EXAMPLE
        $rules = @(
            @{ Pattern = "docs/**";    Label = "documentation"; Priority = 10 }
            @{ Pattern = "src/api/**"; Label = "api";           Priority = 20 }
            @{ Pattern = "**/*.test.*"; Label = "tests";        Priority = 15 }
        )
        Get-PrLabels -Files @("docs/README.md","src/api/routes.js") -Rules $rules
        # Returns: api, documentation  (api has higher priority)
    #>
    param(
        [string[]]$Files,
        [array]$Rules
    )

    # Gracefully handle null/empty inputs
    if (-not $Files -or $Files.Count -eq 0) { return @() }
    if (-not $Rules -or $Rules.Count -eq 0) { return @() }

    # Map each label to its highest matched priority
    $labelPriority = @{}

    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            if (-not $rule.Pattern -or -not $rule.Label) { continue }

            $priority = if ($null -ne $rule.Priority) { [int]$rule.Priority } else { 0 }

            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                $label = $rule.Label
                # Keep the highest priority encountered for this label
                if (-not $labelPriority.ContainsKey($label) -or $labelPriority[$label] -lt $priority) {
                    $labelPriority[$label] = $priority
                }
            }
        }
    }

    if ($labelPriority.Count -eq 0) { return @() }

    # Sort: primary = priority descending, secondary = label name ascending (alphabetical tiebreak)
    $sorted = $labelPriority.Keys |
        Sort-Object { -$labelPriority[$_] }, { $_ }

    # Use unary comma to prevent PowerShell from unrolling the array on return,
    # ensuring callers always receive an array even for single-element results.
    return ,[string[]]$sorted
}

# ============================================================
# MAIN EXECUTION (when run as a script, not dot-sourced)
# ============================================================

# Guard: only execute main block when invoked directly, not dot-sourced in tests.
# When dot-sourced, $MyInvocation.InvocationName is '.'.
# When run with `pwsh -File`, $MyInvocation.ScriptName is empty, so test InvocationName only.
if ($MyInvocation.InvocationName -ne '.') {

    # Resolve defaults for parameters not provided on command line
    if (-not $RulesFile) {
        $RulesFile = Join-Path $PSScriptRoot "label-rules.json"
    }
    if (-not $ChangedFilesFile) {
        $ChangedFilesFile = Join-Path $PSScriptRoot "changed-files.json"
    }

    # Load rules from JSON file
    if (-not (Test-Path $RulesFile)) {
        Write-Error "Rules file not found: $RulesFile"
        exit 1
    }
    $rules = Get-Content $RulesFile | ConvertFrom-Json | ForEach-Object {
        @{ Pattern = $_.pattern; Label = $_.label; Priority = $_.priority }
    }

    # Load changed files (from -ChangedFilesJson parameter or changed-files.json)
    $files = @()
    if ($ChangedFilesJson) {
        $files = $ChangedFilesJson | ConvertFrom-Json
    } elseif (Test-Path $ChangedFilesFile) {
        $files = Get-Content $ChangedFilesFile | ConvertFrom-Json
    } else {
        Write-Warning "No changed files provided. Using empty list."
    }

    Write-Host "PR Label Assigner"
    Write-Host "=================="
    Write-Host "Changed files ($($files.Count)):"
    $files | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""

    $labels = Get-PrLabels -Files $files -Rules $rules

    if ($labels.Count -eq 0) {
        Write-Host "LABELS_RESULT: (none)"
        Write-Host "No labels match the changed files."
    } else {
        Write-Host "LABELS_RESULT: $($labels -join ',')"
        Write-Host ""
        Write-Host "Labels to apply ($($labels.Count)):"
        $labels | ForEach-Object { Write-Host "  LABEL: $_" }
    }
}
