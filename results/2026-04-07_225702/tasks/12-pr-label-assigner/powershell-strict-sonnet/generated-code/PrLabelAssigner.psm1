# PR Label Assigner Module
# Applies labels to a PR based on configurable glob-pattern rules.
#
# TDD implementation order:
#   1. ConvertTo-RegexFromGlob  - core glob->regex translation
#   2. Test-GlobMatch           - public path matching
#   3. Get-LabelsForFile        - per-file label application
#   4. Get-PrLabels             - full PR label aggregation
#   5. New-LabelRule            - rule construction + validation
#   6. Import-LabelConfig       - JSON config loader

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# ConvertTo-RegexFromGlob
# Converts a glob pattern to a regex string.
#
# Glob rules:
#   **  -> matches any sequence of characters including path separators
#   *   -> matches any sequence of characters except path separators (/ \)
#   ?   -> matches a single character except a path separator
#   .   -> literal dot (escaped)
#   All other characters are escaped with [regex]::Escape() equivalents
# ---------------------------------------------------------------------------
function ConvertTo-RegexFromGlob {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Normalise path separators in the pattern to forward slash
    $normalised = $GlobPattern -replace '\\', '/'

    # Build the regex character by character so we can handle ** vs * distinctly
    $regex = [System.Text.StringBuilder]::new()
    [void]$regex.Append('^')

    $i = 0
    while ($i -lt $normalised.Length) {
        $ch = $normalised[$i]

        if ($ch -eq '*') {
            # Peek ahead: if next char is also '*' it is the '**' globstar
            if ($i + 1 -lt $normalised.Length -and $normalised[$i + 1] -eq '*') {
                # Consume both stars
                [void]$regex.Append('.*')
                $i += 2
                # Also consume an optional trailing separator so 'docs/**' matches 'docs/a'
                if ($i -lt $normalised.Length -and $normalised[$i] -eq '/') {
                    # The regex .* already handles this; skip the slash so it is not
                    # emitted as a literal requirement
                    $i++
                }
                continue
            }
            else {
                # Single star: match anything except a path separator
                [void]$regex.Append('[^/\\]*')
            }
        }
        elseif ($ch -eq '?') {
            [void]$regex.Append('[^/\\]')
        }
        elseif ($ch -eq '.') {
            [void]$regex.Append('\.')
        }
        elseif ($ch -match '[+^$()\[\]{}|]') {
            # Escape regex meta-characters
            [void]$regex.Append([regex]::Escape([string]$ch))
        }
        else {
            [void]$regex.Append([string]$ch)
        }

        $i++
    }

    [void]$regex.Append('$')
    return $regex.ToString()
}

# ---------------------------------------------------------------------------
# Test-GlobMatch
# Returns $true if the given path matches the glob pattern.
# Path separators are normalised to forward slash before matching.
# ---------------------------------------------------------------------------
function Test-GlobMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GlobPattern
    )

    # Normalise the input path so Windows-style separators work too
    [string]$normalisedPath = $Path -replace '\\', '/'

    [string]$regex = ConvertTo-RegexFromGlob -GlobPattern $GlobPattern
    return [bool]($normalisedPath -match $regex)
}

# ---------------------------------------------------------------------------
# New-LabelRule
# Creates a validated PSCustomObject representing a single label rule.
# ---------------------------------------------------------------------------
function New-LabelRule {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Label,

        [Parameter(Mandatory)]
        [int]$Priority
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        throw [System.ArgumentException]::new('Pattern must not be empty.', 'Pattern')
    }

    if ([string]::IsNullOrWhiteSpace($Label)) {
        throw [System.ArgumentException]::new('Label must not be empty.', 'Label')
    }

    if ($Priority -lt 0) {
        throw [System.ArgumentOutOfRangeException]::new('Priority', 'Priority must be >= 0.')
    }

    return [PSCustomObject]@{
        Pattern  = $Pattern
        Label    = $Label
        Priority = $Priority
    }
}

# ---------------------------------------------------------------------------
# Get-LabelsForFile
# Returns an array of label strings that apply to a single file path,
# ordered by Priority descending (highest priority first).
# A file can receive labels from multiple rules.
# ---------------------------------------------------------------------------
function Get-LabelsForFile {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Rules
    )

    # Collect matching rules, sort by priority descending, then project labels
    [PSCustomObject[]]$matchingRules = @(
        $Rules | Where-Object { Test-GlobMatch -Path $FilePath -GlobPattern $_.Pattern }
    )

    if ($matchingRules.Count -eq 0) {
        return [string[]]@()
    }

    [string[]]$labels = @(
        $matchingRules |
        Sort-Object -Property Priority -Descending |
        Select-Object -ExpandProperty Label
    )

    return $labels
}

# ---------------------------------------------------------------------------
# Get-PrLabels
# Processes all changed files in a PR and returns the deduplicated set of
# labels that apply, preserving the order in which labels are first
# encountered (highest-priority rules surface first).
# ---------------------------------------------------------------------------
function Get-PrLabels {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Rules
    )

    # Use an ordered dictionary as a seen-set so we can deduplicate while
    # preserving insertion order
    [System.Collections.Specialized.OrderedDictionary]$seen = `
        [System.Collections.Specialized.OrderedDictionary]::new()

    foreach ($file in $ChangedFiles) {
        [string[]]$fileLabels = Get-LabelsForFile -FilePath $file -Rules $Rules
        foreach ($label in $fileLabels) {
            if (-not $seen.Contains($label)) {
                $seen[$label] = $true
            }
        }
    }

    if ($seen.Count -eq 0) {
        return [string[]]@()
    }

    return [string[]]$seen.Keys
}

# ---------------------------------------------------------------------------
# Import-LabelConfig
# Loads label rules from a JSON config file.
# Expected JSON structure:
#   { "rules": [ { "pattern": "...", "label": "...", "priority": N }, ... ] }
# ---------------------------------------------------------------------------
function Import-LabelConfig {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw [System.IO.FileNotFoundException]::new(
            "Label config file not found: $ConfigPath", $ConfigPath)
    }

    [string]$json = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    $config = $json | ConvertFrom-Json

    [PSCustomObject[]]$rules = @(
        $config.rules | ForEach-Object {
            New-LabelRule `
                -Pattern  ([string]$_.pattern) `
                -Label    ([string]$_.label) `
                -Priority ([int]$_.priority)
        }
    )

    return $rules
}
