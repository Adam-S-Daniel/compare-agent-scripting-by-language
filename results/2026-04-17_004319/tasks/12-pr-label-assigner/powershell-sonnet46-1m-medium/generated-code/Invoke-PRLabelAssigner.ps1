# PR Label Assigner
# Assigns labels to PRs based on changed file paths and configurable glob rules.
# Dot-source this file to use Convert-GlobToRegex and Get-PRLabels in tests/workflows.

function Convert-GlobToRegex {
    <#
    .SYNOPSIS
    Converts a glob pattern to a .NET regex string.
    Handles: ** (any path), **/ (any directory prefix), * (non-slash chars), ? (one non-slash char).
    Patterns with no slash are treated as matching at any directory depth (like gitignore).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $p = $Pattern

    # No slash means match at any depth — prepend **/ to get (.+/)? prefix
    if ($p -notmatch '[/\\]') {
        $p = "**/$p"
    }

    # Replace glob wildcards with placeholders BEFORE regex escaping.
    # Placeholders use only letters and underscores — none of which are escaped
    # by [regex]::Escape (unlike #, which IS escaped in .NET regex).
    # Order matters: handle **/ before ** before *.
    $p = $p -replace '\*\*/', 'GLOB_DS'   # **/ → optional directory prefix
    $p = $p -replace '\*\*',  'GLOB_D'    # **  → match anything including slashes
    $p = $p -replace '\*',    'GLOB_S'    # *   → match any chars except slash
    $p = $p -replace '\?',    'GLOB_Q'    # ?   → match exactly one char except slash

    # Escape regex special characters in the remaining literal text
    $p = [regex]::Escape($p)

    # Restore placeholders as their regex equivalents
    $p = $p -replace 'GLOB_DS', '(.+[/\\])?'   # Optional "dir/" prefix (one or more chars + slash)
    $p = $p -replace 'GLOB_D',  '.*'            # Anything including slashes
    $p = $p -replace 'GLOB_S',  '[^/\\]*'       # Any chars except slash
    $p = $p -replace 'GLOB_Q',  '[^/\\]'        # Single char except slash

    # Anchored + case-insensitive (Windows paths may differ in case)
    return "(?i)^$p$"
}

function Get-PRLabels {
    <#
    .SYNOPSIS
    Returns the deduplicated, sorted set of labels for a PR based on changed files.

    .PARAMETER ChangedFiles
    Array of file paths changed in the PR.

    .PARAMETER ConfigPath
    Path to a JSON config file with a "rules" array.

    .PARAMETER Config
    PSObject with a "rules" array (for testing — avoids file I/O).

    Each rule object: { pattern: string, label: string, priority: int }
    Lower priority number = higher priority (applied first).
    All matching rules contribute labels; priority controls ordering, not exclusion.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [string]$ConfigPath = "",

        [object]$Config = $null
    )

    # Load config from disk if not supplied directly
    if ($null -eq $Config) {
        if ([string]::IsNullOrEmpty($ConfigPath)) {
            throw "Either ConfigPath or Config must be provided"
        }
        if (-not (Test-Path $ConfigPath)) {
            throw "Config file not found: $ConfigPath"
        }
        $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }

    if ($null -eq $Config.rules) {
        throw "Config must have a 'rules' property"
    }

    # Sort rules by priority ascending (lower number = higher priority)
    $sortedRules = @($Config.rules | Sort-Object { [int]$_.priority })

    # HashSet for automatic deduplication (case-insensitive label names)
    $labelSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $sortedRules) {
            $regex = Convert-GlobToRegex $rule.pattern
            if ($file -match $regex) {
                [void]$labelSet.Add($rule.label)
            }
        }
    }

    # Return labels sorted alphabetically for deterministic output
    return @($labelSet | Sort-Object)
}
