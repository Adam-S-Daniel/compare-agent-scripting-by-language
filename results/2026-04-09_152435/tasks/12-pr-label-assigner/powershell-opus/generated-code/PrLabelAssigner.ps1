# PrLabelAssigner.ps1
# Core functions for PR Label Assigner
# Assigns labels to PRs based on changed file paths using configurable glob pattern rules

<#
.SYNOPSIS
    Converts a glob pattern to a regular expression for file path matching.
.DESCRIPTION
    Supports:
    - ** (matches zero or more directories)
    - * (matches any characters within a single path segment)
    - ? (matches a single character within a path segment)
    Standard glob semantics: ** crosses directory boundaries, * does not.
#>
function ConvertTo-GlobRegex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    # Normalize path separators to forward slash
    $Pattern = $Pattern -replace '\\', '/'

    # Handle ** patterns before escaping, using placeholders
    # Order matters: **/ first (zero or more directory prefixes),
    # then /** (everything under a directory), then standalone **
    $Pattern = $Pattern -replace '\*\*/', '<<GLOBSTAR_SLASH>>'
    $Pattern = $Pattern -replace '/\*\*', '<<SLASH_GLOBSTAR>>'
    $Pattern = $Pattern -replace '\*\*', '<<GLOBSTAR>>'

    # Escape regex special characters (preserves our placeholders since < > are not special)
    $escaped = [regex]::Escape($Pattern)

    # Restore glob wildcards: undo escaping of * and ?
    $escaped = $escaped -replace '\\\*', '[^/]*'
    $escaped = $escaped -replace '\\\?', '[^/]'

    # Replace placeholders with regex equivalents
    $escaped = $escaped -replace '<<GLOBSTAR_SLASH>>', '(.+/)?'
    $escaped = $escaped -replace '<<SLASH_GLOBSTAR>>', '/.*'
    $escaped = $escaped -replace '<<GLOBSTAR>>', '.*'

    return "^$escaped$"
}

<#
.SYNOPSIS
    Determines PR labels based on changed file paths and configurable rules.
.DESCRIPTION
    Rules are sorted by priority (ascending: lower number = higher importance).
    For each file, matching rules contribute their label.
    If a rule has "exclusive" set to true, no further rules are evaluated for that file.
    The output is the sorted, deduplicated union of all labels across all files.
.PARAMETER Config
    A hashtable with a "rules" key containing an array of rule hashtables.
    Each rule has: pattern (glob), label (string), priority (int), and optional exclusive (bool).
.PARAMETER FilePaths
    An array of changed file paths to evaluate against the rules.
#>
function Get-PrLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Config,

        [Parameter(Mandatory = $true)]
        [string[]]$FilePaths
    )

    # Validate config structure
    # Use $null check (not -not) because empty arrays are falsy in PowerShell
    if ($null -eq $Config.rules) {
        throw "Config must contain a 'rules' array"
    }

    if (@($Config.rules).Count -eq 0) {
        throw "Config 'rules' array must not be empty"
    }

    foreach ($rule in $Config.rules) {
        if (-not $rule.pattern -or -not $rule.label) {
            throw "Each rule must have 'pattern' and 'label' fields"
        }
        if ($null -eq $rule.priority) {
            throw "Each rule must have a 'priority' field"
        }
    }

    # Sort rules by priority (ascending - lower number = higher importance)
    $sortedRules = $Config.rules | Sort-Object { [int]$_.priority }

    $allLabels = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($file in $FilePaths) {
        # Normalize path separators
        $file = $file -replace '\\', '/'

        foreach ($rule in $sortedRules) {
            $regex = ConvertTo-GlobRegex -Pattern $rule.pattern
            if ($file -match $regex) {
                [void]$allLabels.Add($rule.label)
                # If this rule is exclusive, skip remaining rules for this file
                if ($rule.exclusive -eq $true) {
                    break
                }
            }
        }
    }

    # Return sorted label array
    return @($allLabels | Sort-Object)
}
