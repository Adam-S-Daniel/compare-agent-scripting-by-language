Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# PR Label Assigner
# Assigns labels to a PR based on changed file paths and configurable glob-pattern rules.
# Supports glob patterns (**, *, ?), multiple labels per file, and priority ordering.

<#
.SYNOPSIS
    Converts a glob pattern (with ** and * wildcards) into a PowerShell-compatible regex.
.DESCRIPTION
    Translates glob syntax: ** matches any path segment(s), * matches within a segment,
    ? matches a single char. Dots and other regex metacharacters are escaped.
#>
function ConvertTo-GlobRegex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Normalize path separators to forward slash
    [string]$p = $Pattern.Replace('\', '/')

    # Escape regex metacharacters except our glob wildcards (* and ?)
    # We handle ** first by replacing with a placeholder, then * and ?
    [string]$escaped = ''
    [int]$i = 0
    while ($i -lt $p.Length) {
        [string]$c = $p[$i].ToString()
        if ($c -eq '*' -and ($i + 1) -lt $p.Length -and $p[$i + 1] -eq '*') {
            # ** - match any path including separators
            $escaped += '<<<GLOBSTAR>>>'
            $i += 2
            # Skip trailing slash after ** if present
            if ($i -lt $p.Length -and $p[$i] -eq '/') { $i++ }
        }
        elseif ($c -eq '*') {
            # * - match anything except path separator
            $escaped += '<<<STAR>>>'
            $i++
        }
        elseif ($c -eq '?') {
            $escaped += '<<<QUESTION>>>'
            $i++
        }
        else {
            # Escape regex metacharacters
            $escaped += [regex]::Escape($c)
            $i++
        }
    }

    # Replace placeholders with regex equivalents
    $escaped = $escaped.Replace('<<<GLOBSTAR>>>', '.*')
    $escaped = $escaped.Replace('<<<STAR>>>', '[^/]*')
    $escaped = $escaped.Replace('<<<QUESTION>>>', '[^/]')

    return "^$escaped$"
}

<#
.SYNOPSIS
    Tests whether a file path matches a glob pattern.
#>
function Test-GlobMatch {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Pattern
    )

    [string]$normalizedPath = $Path.Replace('\', '/')
    [string]$regex = ConvertTo-GlobRegex -Pattern $Pattern
    return [bool]($normalizedPath -match $regex)
}

<#
.SYNOPSIS
    Given a list of changed files and label rules, returns the set of labels to apply.
.DESCRIPTION
    Each rule is a hashtable with Pattern (glob), Label (string), and optional Priority (int).
    Higher priority rules win when conflicts arise. Returns a deduplicated, sorted label set.
#>
function Get-PrLabels {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [hashtable[]]$Rules
    )

    # Validate rules upfront
    [int]$ruleIndex = 0
    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('Pattern')) {
            throw "Rule at index $ruleIndex is missing required key 'Pattern'. Each rule must have Pattern and Label."
        }
        if (-not $rule.ContainsKey('Label')) {
            throw "Rule at index $ruleIndex is missing required key 'Label'. Each rule must have Pattern and Label."
        }
        $ruleIndex++
    }

    [System.Collections.Generic.HashSet[string]]$labels = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($file in $ChangedFiles) {
        # Collect all matching rules for this file
        [System.Collections.ArrayList]$matchedRules = [System.Collections.ArrayList]::new()
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern ([string]$rule.Pattern)) {
                [int]$priority = if ($rule.ContainsKey('Priority')) { [int]$rule.Priority } else { 0 }
                [void]$matchedRules.Add(@{ Label = [string]$rule.Label; Priority = $priority })
            }
        }

        if ($matchedRules.Count -eq 0) { continue }

        # Find the highest priority among matched rules for this file
        [int]$maxPriority = 0
        foreach ($m in $matchedRules) {
            if ([int]$m.Priority -gt $maxPriority) {
                $maxPriority = [int]$m.Priority
            }
        }

        # Only add labels at the highest priority level
        foreach ($m in $matchedRules) {
            if ([int]$m.Priority -eq $maxPriority) {
                [void]$labels.Add([string]$m.Label)
            }
        }
    }

    if ($labels.Count -eq 0) {
        return , [string[]]@()
    }
    [string[]]$sorted = @($labels | Sort-Object)
    return , [string[]]$sorted
}
