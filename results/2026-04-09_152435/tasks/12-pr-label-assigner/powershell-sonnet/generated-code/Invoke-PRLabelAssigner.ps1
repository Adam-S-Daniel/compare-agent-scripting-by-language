# Invoke-PRLabelAssigner.ps1
# PR Label Assigner - assigns labels to a PR based on changed file paths
#
# Design:
#   - Rules are defined in a JSON config: each rule has a glob pattern, a label, and a priority
#   - For each changed file, we test it against every rule's pattern
#   - All matching labels are collected across all files and deduplicated
#   - Labels are returned ordered by descending priority (highest priority first)
#   - Glob patterns use PowerShell's -like operator after converting ** -> *
#
# Usage (CLI):
#   ./Invoke-PRLabelAssigner.ps1 -FilePaths @("docs/README.md","src/api/users.js") -ConfigPath ./label-config.json
#   ./Invoke-PRLabelAssigner.ps1 -FilesPath ./fixtures/changed-files.txt -ConfigPath ./label-config.json

param(
    # Inline list of changed file paths (mutually exclusive with FilesPath)
    [string[]]$FilePaths,

    # Path to a text file with one changed file path per line
    [string]$FilesPath,

    # Path to the JSON config with label rules
    [string]$ConfigPath = "$PSScriptRoot/label-config.json"
)

# =============================================================================
# Test-GlobPattern
# Checks if a file path matches a glob pattern.
#
# Conversion rules:
#   ** -> * (PowerShell's * already matches path separators)
#   * stays as *
#   ? stays as ?
#
# Special case: patterns starting with **/ are also tried without the **/ prefix
# so that "**/*.md" matches both "README.md" and "docs/README.md".
# =============================================================================
function Test-GlobPattern {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )

    # Normalize to forward slashes so patterns work cross-platform
    $normalizedPath = $Path -replace '\\', '/'

    # Convert glob to PowerShell wildcard: ** becomes *
    $psPattern = $Pattern -replace '\*\*', '*'

    if ($normalizedPath -like $psPattern) {
        return $true
    }

    # For patterns starting with **/, also match without the leading **/
    # e.g. "**/*.md" -> also try "*.md" so it matches root-level files
    if ($Pattern -match '^\*\*/(.+)') {
        $subPattern = $matches[1] -replace '\*\*', '*'
        if ($normalizedPath -like $subPattern) {
            return $true
        }
    }

    return $false
}

# =============================================================================
# Get-LabelRulesFromConfig
# Loads label rules from a JSON config file.
#
# Expected JSON format:
#   {
#     "rules": [
#       { "pattern": "docs/**", "label": "documentation", "priority": 100 },
#       ...
#     ]
#   }
#
# Returns an array of PSCustomObject with Pattern, Label, and Priority properties.
# =============================================================================
function Get-LabelRulesFromConfig {
    param(
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: '$ConfigPath'"
    }

    $raw = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    if (-not $raw.rules) {
        throw "Config file '$ConfigPath' is missing a 'rules' array"
    }

    # Normalize to PSCustomObjects with consistent property names (PascalCase)
    $rules = $raw.rules | ForEach-Object {
        [PSCustomObject]@{
            Pattern  = $_.pattern
            Label    = $_.label
            Priority = [int]$_.priority
        }
    }

    return $rules
}

# =============================================================================
# Get-MatchingLabels
# Given a list of file paths and an array of rules, returns all matching labels.
#
# - Collects every label whose rule pattern matches at least one changed file
# - Deduplicates labels (same label from multiple rules counts once)
# - Orders results by descending priority (the highest-priority rule that produced
#   each label determines its position in the output)
# =============================================================================
function Get-MatchingLabels {
    param(
        [Parameter(Mandatory)][string[]]$FilePaths,
        [Parameter(Mandatory)][array]$Rules
    )

    # Sort rules by descending priority so we process highest-priority first
    $sortedRules = $Rules | Sort-Object -Property Priority -Descending

    # Track (label -> max priority that matched) to handle deduplication with ordering
    $labelPriority = [ordered]@{}

    foreach ($file in $FilePaths) {
        foreach ($rule in $sortedRules) {
            if (Test-GlobPattern -Path $file -Pattern $rule.Pattern) {
                # Only record this label if we haven't seen it yet, or if this
                # rule has higher priority than the previous match for the same label
                if (-not $labelPriority.Contains($rule.Label) -or
                    $rule.Priority -gt $labelPriority[$rule.Label]) {
                    $labelPriority[$rule.Label] = $rule.Priority
                }
            }
        }
    }

    if ($labelPriority.Count -eq 0) {
        return @()
    }

    # Return labels ordered by descending priority
    $ordered = $labelPriority.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        Select-Object -ExpandProperty Name

    return @($ordered)
}

# =============================================================================
# Invoke-PRLabelAssigner
# Main function: loads config, runs matching, returns final label set.
# =============================================================================
function Invoke-PRLabelAssigner {
    param(
        [Parameter(Mandatory)][string[]]$FilePaths,
        [Parameter(Mandatory)][string]$ConfigPath
    )

    $rules = Get-LabelRulesFromConfig -ConfigPath $ConfigPath
    return Get-MatchingLabels -FilePaths $FilePaths -Rules $rules
}

# =============================================================================
# CLI entry point
# Only executes when the script is invoked directly (not dot-sourced for tests).
# Reads file list from -FilePaths or -FilesPath, loads config, outputs labels.
# =============================================================================
if ($FilePaths -or $FilesPath) {
    $resolvedFiles = @()

    if ($FilesPath) {
        if (-not (Test-Path $FilesPath)) {
            Write-Error "Files list not found: '$FilesPath'"
            exit 1
        }
        $resolvedFiles = Get-Content $FilesPath | Where-Object { $_.Trim() -ne "" }
    }

    if ($FilePaths) {
        $resolvedFiles += $FilePaths
    }

    if ($resolvedFiles.Count -eq 0) {
        Write-Warning "No file paths provided. Nothing to label."
        exit 0
    }

    try {
        $labels = Invoke-PRLabelAssigner -FilePaths $resolvedFiles -ConfigPath $ConfigPath

        if ($labels.Count -eq 0) {
            Write-Output "No labels matched."
        }
        else {
            Write-Output "Labels: $($labels -join ', ')"
            # Also output individual labels for easy parsing
            foreach ($label in $labels) {
                Write-Output "LABEL: $label"
            }
        }
    }
    catch {
        Write-Error "Error assigning labels: $_"
        exit 1
    }
}
