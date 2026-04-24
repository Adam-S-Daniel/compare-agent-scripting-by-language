#requires -Version 7.0

# LabelAssigner — maps a list of changed paths to a set of labels based on
# configurable glob-pattern rules. Supports multiple labels per rule, priority
# ordering, and mutually-exclusive rule groups.

Set-StrictMode -Version Latest

function ConvertTo-GlobRegex {
    <#
    .SYNOPSIS
        Convert a glob pattern into an anchored .NET regex.
    .DESCRIPTION
        Semantics follow common PR-label matcher tools (e.g. actions/labeler):
          **  -> matches any sequence of characters INCLUDING path separators
          *   -> matches any sequence of non-separator characters
          ?   -> matches a single non-separator character
        Everything else is treated as a literal (regex metacharacters escaped).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Pattern
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    for ($i = 0; $i -lt $Pattern.Length; $i++) {
        $c = $Pattern[$i]
        # Look for the two-character sequence '**' first so we don't accidentally
        # consume it as two separate '*' wildcards. The leading form '**/' is
        # special-cased to mean "zero or more directory segments" so that
        # patterns like **/*.md also match root-level files (README.md).
        if ($c -eq '*' -and $i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
            if ($i + 2 -lt $Pattern.Length -and $Pattern[$i + 2] -eq '/') {
                [void]$sb.Append('(?:.*/)?')
                $i += 2
            } else {
                [void]$sb.Append('.*')
                $i++
            }
            continue
        }
        switch ($c) {
            '*' { [void]$sb.Append('[^/]*') }
            '?' { [void]$sb.Append('[^/]') }
            default {
                # Escape every non-wildcard character. [regex]::Escape handles
                # regex metacharacters (., +, (, ), etc.) safely.
                [void]$sb.Append([regex]::Escape([string]$c))
            }
        }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-PathGlobMatch {
    <#
    .SYNOPSIS
        Returns $true if $Path matches $Pattern under glob semantics.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Pattern
    )
    $rx = ConvertTo-GlobRegex -Pattern $Pattern
    return [regex]::IsMatch($Path, $rx)
}

function Import-LabelRules {
    <#
    .SYNOPSIS
        Load a JSON rules file into normalized rule objects.
    .DESCRIPTION
        Each rule must have a `pattern` (string) and `labels` (string array).
        `priority` (int, default 0) and `group` (string, default $null) are optional.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Rules file not found: $Path"
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        $parsed = $raw | ConvertFrom-Json -Depth 10
    } catch {
        throw "Failed to parse rules JSON at '$Path': $($_.Exception.Message)"
    }

    # Normalize into an array even when the file contains a single object.
    $rules = @()
    foreach ($r in @($parsed)) {
        if (-not $r.PSObject.Properties['pattern'] -or [string]::IsNullOrWhiteSpace($r.pattern)) {
            throw "Rule is missing required 'pattern' field: $($r | ConvertTo-Json -Compress)"
        }
        if (-not $r.PSObject.Properties['labels']) {
            throw "Rule is missing required 'labels' field for pattern '$($r.pattern)'"
        }
        $priority = 0
        if ($r.PSObject.Properties['priority'] -and $null -ne $r.priority) {
            $priority = [int]$r.priority
        }
        $group = $null
        if ($r.PSObject.Properties['group']) { $group = $r.group }

        $rules += [pscustomobject]@{
            pattern  = [string]$r.pattern
            labels   = @($r.labels)
            priority = $priority
            group    = $group
        }
    }
    return ,$rules
}

function Get-PullRequestLabels {
    <#
    .SYNOPSIS
        Compute the label set for a list of changed paths.
    .DESCRIPTION
        Rules are evaluated highest-priority first. Every matching rule
        contributes its labels to the aggregated set. Rules sharing a `group`
        are mutually exclusive — once a group has a match, lower-priority
        rules in the same group are skipped. Output is deduplicated and
        ordered by the priority of the first rule that introduced each label.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $Paths,
        [Parameter(Mandatory)][object[]] $Rules
    )

    if ($null -eq $Paths -or $Paths.Count -eq 0) {
        return @()
    }

    # Sort once by priority descending so earliest-added labels have highest priority.
    $sorted = @($Rules | Sort-Object -Property @{ Expression = 'priority'; Descending = $true })

    # Use an ordered hashtable to preserve insertion order for deterministic output.
    $labelSet    = [ordered]@{}
    $groupsTaken = @{}

    foreach ($rule in $sorted) {
        # Group exclusivity: skip if a higher-priority rule in this group already fired.
        if ($rule.group -and $groupsTaken.ContainsKey($rule.group)) { continue }

        $matched = $false
        foreach ($p in $Paths) {
            if (Test-PathGlobMatch -Path $p -Pattern $rule.pattern) {
                $matched = $true
                break
            }
        }
        if (-not $matched) { continue }

        foreach ($label in $rule.labels) {
            if (-not $labelSet.Contains($label)) {
                $labelSet[$label] = $true
            }
        }
        if ($rule.group) { $groupsTaken[$rule.group] = $true }
    }

    return ,@($labelSet.Keys)
}

Export-ModuleMember -Function ConvertTo-GlobRegex, Test-PathGlobMatch, Import-LabelRules, Get-PullRequestLabels
