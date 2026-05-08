# Invoke-PRLabelAssigner.ps1
# Assigns labels to a PR based on changed file paths and configurable glob rules.
#
# Rule format (PSCustomObject or hashtable):
#   Pattern  - Glob pattern string (e.g. "docs/**", "**/*.test.*")
#   Label    - Label string to assign when the pattern matches
#   Priority - Integer; higher value = higher priority (controls output order)
#
# Glob pattern semantics:
#   **   - matches any path sequence including directory separators
#   *    - matches any characters except /
#   ?    - matches exactly one character except /
#   other - treated as literal characters (regex-escaped)

# ---------------------------------------------------------------------------
# TDD Green Iteration 1: ConvertTo-GlobRegex
# ---------------------------------------------------------------------------
function ConvertTo-GlobRegex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # Normalize to forward slashes so patterns work on Windows and Linux alike.
    $normalized = $Pattern.Replace('\', '/')

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')

    $i = 0
    while ($i -lt $normalized.Length) {
        $c = $normalized[$i]

        if ($c -eq '*' -and ($i + 1) -lt $normalized.Length -and $normalized[$i + 1] -eq '*') {
            # ** matches any path (zero or more characters including /)
            [void]$sb.Append('.*')
            $i += 2
            # Consume the trailing slash that often follows ** (e.g. "docs/**/")
            if ($i -lt $normalized.Length -and $normalized[$i] -eq '/') { $i++ }
        } elseif ($c -eq '*') {
            # Single * matches anything except /
            [void]$sb.Append('[^/]*')
            $i++
        } elseif ($c -eq '?') {
            # ? matches exactly one character except /
            [void]$sb.Append('[^/]')
            $i++
        } else {
            # Literal character — escape regex metacharacters (handles . + [ ] etc.)
            [void]$sb.Append([System.Text.RegularExpressions.Regex]::Escape([string]$c))
            $i++
        }
    }

    [void]$sb.Append('$')
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Helper: Test-PathMatchesGlob
# ---------------------------------------------------------------------------
function Test-PathMatchesGlob {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$GlobPattern
    )

    # Normalize backslashes so Windows paths match forward-slash patterns.
    $normalizedPath = $Path.Replace('\', '/')
    $regex = ConvertTo-GlobRegex -Pattern $GlobPattern
    return $normalizedPath -match $regex
}

# ---------------------------------------------------------------------------
# TDD Green Iteration 2-7: Get-PRLabels
# ---------------------------------------------------------------------------
function Get-PRLabels {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Rules
    )

    # Validate each rule has the required properties before doing any work.
    foreach ($rule in $Rules) {
        $hasPattern = $null -ne $rule.PSObject.Properties['Pattern'] -and $null -ne $rule.Pattern
        $hasLabel   = $null -ne $rule.PSObject.Properties['Label']   -and $null -ne $rule.Label

        if (-not $hasPattern) {
            throw "Rule is missing required 'Pattern' property: $($rule | ConvertTo-Json -Compress)"
        }
        if (-not $hasLabel) {
            throw "Rule is missing required 'Label' property: $($rule | ConvertTo-Json -Compress)"
        }
    }

    # Track the highest priority seen for each unique label.
    $labelPriority = [System.Collections.Generic.Dictionary[string, int]]::new()

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $Rules) {
            if (Test-PathMatchesGlob -Path $file -GlobPattern $rule.Pattern) {
                $label    = $rule.Label
                $priority = if ($null -ne $rule.PSObject.Properties['Priority'] -and $null -ne $rule.Priority) {
                    [int]$rule.Priority
                } else {
                    0
                }

                if (-not $labelPriority.ContainsKey($label) -or $labelPriority[$label] -lt $priority) {
                    $labelPriority[$label] = $priority
                }
            }
        }
    }

    # Return labels sorted by priority descending (highest priority first).
    $sorted = $labelPriority.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        Select-Object -ExpandProperty Key

    return @($sorted)
}

# ---------------------------------------------------------------------------
# Entry point — only runs when the script is invoked directly, not dot-sourced.
# When dot-sourced (. ./Invoke-PRLabelAssigner.ps1), $MyInvocation.InvocationName
# is '.' so this block is skipped, making functions available to callers.
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
    # Accept JSON via environment variables or use built-in mock data for testing.
    $changedFilesJson = $env:PR_CHANGED_FILES
    $rulesJson        = $env:PR_LABEL_RULES

    if ($changedFilesJson) {
        try {
            $changedFiles = $changedFilesJson | ConvertFrom-Json
        } catch {
            Write-Error "Failed to parse PR_CHANGED_FILES as JSON: $_"
            exit 1
        }
    } else {
        # Mock file list for demonstration / standalone testing.
        Write-Warning "PR_CHANGED_FILES not set — using mock file list."
        $changedFiles = @(
            "docs/README.md",
            "src/api/users.js",
            "src/api/users.test.js",
            "src/utils.test.ts",
            "src/main.js"
        )
    }

    if ($rulesJson) {
        try {
            $rules = $rulesJson | ConvertFrom-Json
        } catch {
            Write-Error "Failed to parse PR_LABEL_RULES as JSON: $_"
            exit 1
        }
    } else {
        # Default rules for demonstration.
        Write-Warning "PR_LABEL_RULES not set — using default rules."
        $rules = @(
            [PSCustomObject]@{Pattern = "docs/**";      Label = "documentation"; Priority = 10},
            [PSCustomObject]@{Pattern = "src/api/**";   Label = "api";           Priority = 20},
            [PSCustomObject]@{Pattern = "**/*.test.*";  Label = "tests";         Priority = 15},
            [PSCustomObject]@{Pattern = "src/**";       Label = "source";        Priority = 5}
        )
    }

    try {
        $labels = Get-PRLabels -ChangedFiles $changedFiles -Rules $rules
        if ($labels.Count -eq 0) {
            Write-Output "No labels matched the changed files."
        } else {
            Write-Output "Assigned labels: $($labels -join ', ')"
        }
    } catch {
        Write-Error "Error assigning labels: $_"
        exit 1
    }
}
