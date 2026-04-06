# PrLabelAssigner.ps1
# Assigns labels to PRs based on changed file paths using configurable path-to-label mapping rules.
# Supports glob patterns, multiple labels per file, and priority ordering when rules conflict.

<#
.SYNOPSIS
    Converts a glob pattern (with ** and * wildcards) to a PowerShell-compatible regex.

.DESCRIPTION
    Translates glob patterns like "docs/**", "src/api/**", "*.test.*" into regex patterns.
    - ** matches any number of path segments (including zero)
    - * matches anything within a single path segment (no slashes)
    - ? matches a single character
    - Literal dots and other regex metacharacters are escaped

.PARAMETER GlobPattern
    The glob pattern to convert (e.g., "docs/**", "*.test.*")

.OUTPUTS
    A regex string equivalent of the glob pattern
#>
function Convert-GlobToRegex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Escape regex metacharacters first, then convert glob wildcards
    $regex = $GlobPattern

    # Escape special regex characters (except * and ?)
    $regex = $regex -replace '\.', '\.'
    $regex = $regex -replace '\+', '\+'
    $regex = $regex -replace '\^', '\^'
    $regex = $regex -replace '\$', '\$'
    $regex = $regex -replace '\(', '\('
    $regex = $regex -replace '\)', '\)'
    $regex = $regex -replace '\{', '\{'
    $regex = $regex -replace '\}', '\}'
    $regex = $regex -replace '\[', '\['
    $regex = $regex -replace '\]', '\]'
    $regex = $regex -replace '\|', '\|'

    # Convert ** (match any path segments) - must be done before single *
    # ** matches zero or more path segments including separators
    $regex = $regex -replace '\*\*', '<<<DOUBLESTAR>>>'

    # Convert single * (match within a single path segment, no slashes)
    $regex = $regex -replace '\*', '[^/]*'

    # Convert ? to match single non-slash character
    $regex = $regex -replace '\?', '[^/]'

    # Now replace the double-star placeholder with the real pattern
    $regex = $regex -replace '<<<DOUBLESTAR>>>', '.*'

    # Anchor the pattern to match the full path
    return "^${regex}$"
}

<#
.SYNOPSIS
    Tests whether a file path matches a glob pattern.

.PARAMETER FilePath
    The file path to test (e.g., "docs/readme.md")

.PARAMETER GlobPattern
    The glob pattern to match against (e.g., "docs/**")

.OUTPUTS
    Boolean indicating whether the path matches the pattern
#>
function Test-GlobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    $regex = Convert-GlobToRegex -GlobPattern $GlobPattern
    return $FilePath -match $regex
}

<#
.SYNOPSIS
    Given a list of changed file paths and label rules, returns the set of labels to apply.

.DESCRIPTION
    Evaluates each changed file against the configured rules (sorted by priority).
    Rules with lower priority numbers take precedence when conflicts exist.
    Each rule maps a glob pattern to a label. Multiple files can trigger the same label,
    and a single file can match multiple rules producing multiple labels.

.PARAMETER ChangedFiles
    Array of file paths representing PR changed files.

.PARAMETER Rules
    Array of hashtables, each with:
      - Pattern  [string]  : Glob pattern to match file paths
      - Label    [string]  : Label to assign when the pattern matches
      - Priority [int]     : Priority order (lower = higher priority)

.PARAMETER MaxLabels
    Optional maximum number of labels to return. When set, only the highest-priority
    labels (up to MaxLabels) are returned. Default is 0 (no limit).

.OUTPUTS
    An array of unique label strings, sorted by the highest priority rule that produced them.
#>
function Get-PrLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [hashtable[]]$Rules,

        [Parameter()]
        [int]$MaxLabels = 0
    )

    # Validate inputs
    if ($null -eq $ChangedFiles -or $ChangedFiles.Count -eq 0) {
        Write-Error "ChangedFiles must contain at least one file path."
        return @()
    }

    if ($null -eq $Rules -or $Rules.Count -eq 0) {
        Write-Error "Rules must contain at least one rule."
        return @()
    }

    # Validate each rule has required keys
    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('Pattern') -or -not $rule.ContainsKey('Label') -or -not $rule.ContainsKey('Priority')) {
            Write-Error "Each rule must have 'Pattern', 'Label', and 'Priority' keys. Invalid rule: $($rule | ConvertTo-Json -Compress)"
            return @()
        }
    }

    # Sort rules by priority (lower number = higher priority)
    $sortedRules = $Rules | Sort-Object { $_.Priority }

    # Track which labels have been assigned and the best (lowest) priority for each
    $labelPriority = @{}

    # Evaluate each file against each rule
    foreach ($file in $ChangedFiles) {
        foreach ($rule in $sortedRules) {
            if (Test-GlobMatch -FilePath $file -GlobPattern $rule.Pattern) {
                $label = $rule.Label
                $priority = $rule.Priority

                # Only record the label if it hasn't been seen or this priority is better
                if (-not $labelPriority.ContainsKey($label) -or $priority -lt $labelPriority[$label]) {
                    $labelPriority[$label] = $priority
                }
            }
        }
    }

    # If no labels matched, return empty
    if ($labelPriority.Count -eq 0) {
        return @()
    }

    # Sort labels by their best priority, then alphabetically for determinism
    $sortedLabels = $labelPriority.GetEnumerator() |
        Sort-Object { $_.Value }, { $_.Key } |
        ForEach-Object { $_.Key }

    # Apply MaxLabels limit if specified
    if ($MaxLabels -gt 0 -and $sortedLabels.Count -gt $MaxLabels) {
        $sortedLabels = $sortedLabels | Select-Object -First $MaxLabels
    }

    return $sortedLabels
}

<#
.SYNOPSIS
    Creates a default set of label rules for common file path patterns.

.DESCRIPTION
    Returns a preconfigured set of rules mapping common file patterns to labels.
    Useful as a starting point or for demonstration purposes.

.OUTPUTS
    Array of rule hashtables with Pattern, Label, and Priority keys.
#>
function Get-DefaultRules {
    return @(
        @{ Pattern = 'docs/**';           Label = 'documentation'; Priority = 1 }
        @{ Pattern = '*.md';              Label = 'documentation'; Priority = 2 }
        @{ Pattern = 'src/api/**';        Label = 'api';           Priority = 1 }
        @{ Pattern = 'src/ui/**';         Label = 'frontend';      Priority = 1 }
        @{ Pattern = 'src/core/**';       Label = 'core';          Priority = 1 }
        @{ Pattern = '**/*.test.*';       Label = 'tests';         Priority = 1 }
        @{ Pattern = '*.test.*';          Label = 'tests';         Priority = 1 }
        @{ Pattern = '**/*.spec.*';       Label = 'tests';         Priority = 2 }
        @{ Pattern = '*.spec.*';          Label = 'tests';         Priority = 2 }
        @{ Pattern = 'tests/**';          Label = 'tests';         Priority = 1 }
        @{ Pattern = '.github/**';        Label = 'ci/cd';         Priority = 1 }
        @{ Pattern = 'Dockerfile';        Label = 'infrastructure'; Priority = 1 }
        @{ Pattern = 'docker-compose.*';  Label = 'infrastructure'; Priority = 1 }
        @{ Pattern = '**/*.config.*';     Label = 'configuration'; Priority = 2 }
        @{ Pattern = '*.config.*';        Label = 'configuration'; Priority = 2 }
        @{ Pattern = 'package.json';      Label = 'dependencies';  Priority = 1 }
        @{ Pattern = 'requirements.txt';  Label = 'dependencies';  Priority = 1 }
    )
}

<#
.SYNOPSIS
    Runs a demonstration of the PR label assigner with mock data.

.DESCRIPTION
    Uses mock file lists representing typical PR changes and applies the default
    rules to show how labels are assigned. Outputs the results to the console.
#>
function Invoke-Demo {
    Write-Host "=== PR Label Assigner Demo ===" -ForegroundColor Cyan
    Write-Host ""

    $rules = Get-DefaultRules

    # Mock PR 1: Documentation update
    $mockPr1 = @('docs/api-guide.md', 'docs/setup.md', 'README.md')
    Write-Host "PR #1 - Changed files:" -ForegroundColor Yellow
    $mockPr1 | ForEach-Object { Write-Host "  - $_" }
    $labels1 = Get-PrLabels -ChangedFiles $mockPr1 -Rules $rules
    Write-Host "Labels: $($labels1 -join ', ')" -ForegroundColor Green
    Write-Host ""

    # Mock PR 2: API feature with tests
    $mockPr2 = @('src/api/users.js', 'src/api/auth.js', 'src/api/users.test.js', 'tests/integration/api.test.js')
    Write-Host "PR #2 - Changed files:" -ForegroundColor Yellow
    $mockPr2 | ForEach-Object { Write-Host "  - $_" }
    $labels2 = Get-PrLabels -ChangedFiles $mockPr2 -Rules $rules
    Write-Host "Labels: $($labels2 -join ', ')" -ForegroundColor Green
    Write-Host ""

    # Mock PR 3: Full-stack with infra
    $mockPr3 = @('src/api/endpoint.js', 'src/ui/dashboard.tsx', 'Dockerfile', '.github/workflows/ci.yml')
    Write-Host "PR #3 - Changed files:" -ForegroundColor Yellow
    $mockPr3 | ForEach-Object { Write-Host "  - $_" }
    $labels3 = Get-PrLabels -ChangedFiles $mockPr3 -Rules $rules
    Write-Host "Labels: $($labels3 -join ', ')" -ForegroundColor Green
    Write-Host ""

    # Mock PR 4: Config + dependency update
    $mockPr4 = @('package.json', 'webpack.config.js', 'tsconfig.json')
    Write-Host "PR #4 - Changed files:" -ForegroundColor Yellow
    $mockPr4 | ForEach-Object { Write-Host "  - $_" }
    $labels4 = Get-PrLabels -ChangedFiles $mockPr4 -Rules $rules
    Write-Host "Labels: $($labels4 -join ', ')" -ForegroundColor Green
}
