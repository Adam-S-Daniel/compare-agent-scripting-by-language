<#
.SYNOPSIS
    PR Label Assigner - assigns labels to PRs based on changed file paths using glob patterns.

.DESCRIPTION
    Given a list of changed file paths (simulating a PR's changed files), applies labels
    based on configurable path-to-label mapping rules. Supports glob patterns (**,*,?),
    multiple labels per file, and priority ordering when rules conflict.
#>

#region Glob Pattern Matching

function Convert-GlobToRegex {
    <#
    .SYNOPSIS
        Converts a glob pattern to a .NET regex pattern.

    .DESCRIPTION
        Glob rules:
          **  matches any sequence of characters including path separators
          *   matches any sequence of non-separator characters
          ?   matches exactly one non-separator character
          All other characters are regex-escaped.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')

    $i = 0
    while ($i -lt $GlobPattern.Length) {
        $ch = $GlobPattern[$i]

        if ($ch -eq '*' -and ($i + 1) -lt $GlobPattern.Length -and $GlobPattern[$i + 1] -eq '*') {
            # ** matches everything including path separators
            [void]$sb.Append('.*')
            $i += 2
            # Consume optional trailing slash after **
            if ($i -lt $GlobPattern.Length -and $GlobPattern[$i] -eq '/') {
                [void]$sb.Append('/?')
                $i++
            }
        }
        elseif ($ch -eq '*') {
            # * matches anything except /
            [void]$sb.Append('[^/]*')
            $i++
        }
        elseif ($ch -eq '?') {
            # ? matches one char except /
            [void]$sb.Append('[^/]')
            $i++
        }
        else {
            # Escape regex metacharacters in the literal portion
            [void]$sb.Append([System.Text.RegularExpressions.Regex]::Escape([string]$ch))
            $i++
        }
    }

    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-GlobMatch {
    <#
    .SYNOPSIS
        Tests whether a file path matches a glob pattern.

    .PARAMETER Path
        The file path to test (use forward slashes).

    .PARAMETER Pattern
        A glob pattern (supports *, **, ?).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Normalize separators
    $normalizedPath    = $Path    -replace '\\', '/'
    $normalizedPattern = $Pattern -replace '\\', '/'

    $regex = Convert-GlobToRegex -GlobPattern $normalizedPattern
    return [System.Text.RegularExpressions.Regex]::IsMatch($normalizedPath, $regex)
}

#endregion

#region Label Assignment

function Get-PRLabels {
    <#
    .SYNOPSIS
        Returns the set of labels that apply to a PR given its changed files and label rules.

    .PARAMETER Files
        Array of changed file paths (relative, forward-slash separated).

    .PARAMETER Rules
        Array of hashtables: @{ Pattern = <glob>; Label = <string>; Priority = <int> }
        Higher Priority value = higher importance.

    .PARAMETER SortByPriority
        When specified, returns labels sorted by their highest matching rule priority
        (descending). When multiple rules share the same label, the highest priority wins.

    .OUTPUTS
        [string[]] Deduplicated set of label strings.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Files,

        [Parameter(Mandatory)]
        [hashtable[]]$Rules,

        [switch]$SortByPriority
    )

    if ($null -eq $Rules) {
        throw "Rules parameter must not be null. Provide an array of rule hashtables."
    }

    if ($Files.Count -eq 0) {
        return @()
    }

    # Map label -> highest priority that triggered it
    $labelPriority = @{}

    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                $label    = $rule.Label
                $priority = [int]$rule.Priority

                if (-not $labelPriority.ContainsKey($label) -or $labelPriority[$label] -lt $priority) {
                    $labelPriority[$label] = $priority
                }
            }
        }
    }

    if ($labelPriority.Count -eq 0) {
        return @()
    }

    if ($SortByPriority) {
        # Sort labels by their highest matched priority, descending
        return $labelPriority.GetEnumerator() |
               Sort-Object -Property Value -Descending |
               Select-Object -ExpandProperty Key
    }
    else {
        return @($labelPriority.Keys)
    }
}

#endregion

#region Entry Point (when run directly, not dot-sourced)

if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\.\s') {
    # Default mock PR file list for demonstration
    $MockFiles = @(
        "src/api/v1/users.ts",
        "src/api/v1/orders.ts",
        "src/api/v1/users.test.ts",
        "src/lib/utils.ts",
        "docs/api/users.md",
        "docs/setup.md",
        ".github/workflows/ci.yml",
        "jest.config.ts",
        "README.md"
    )

    $DefaultRules = @(
        @{ Pattern = "docs/**";      Label = "documentation"; Priority = 10 },
        @{ Pattern = "**/*.md";      Label = "documentation"; Priority = 10 },
        @{ Pattern = "src/api/**";   Label = "api";           Priority = 20 },
        @{ Pattern = "**/*.test.*";  Label = "tests";         Priority = 30 },
        @{ Pattern = "**/*.spec.*";  Label = "tests";         Priority = 30 },
        @{ Pattern = "src/**";       Label = "source";        Priority = 5  },
        @{ Pattern = ".github/**";   Label = "ci/cd";         Priority = 40 },
        @{ Pattern = "*.config.*";   Label = "config";        Priority = 15 }
    )

    Write-Host "=== PR Label Assigner ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Changed files:" -ForegroundColor Yellow
    $MockFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""

    $Labels = Get-PRLabels -Files $MockFiles -Rules $DefaultRules -SortByPriority

    Write-Host "Assigned labels (by priority):" -ForegroundColor Green
    $Labels | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""
    Write-Host "RESULT_LABELS: $($Labels -join ',')" -ForegroundColor Cyan
}

#endregion
