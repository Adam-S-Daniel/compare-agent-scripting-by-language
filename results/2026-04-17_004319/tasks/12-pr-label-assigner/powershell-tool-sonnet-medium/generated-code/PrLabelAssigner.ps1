# PrLabelAssigner.ps1
# Library: core functions for PR label assignment based on glob path rules.

# Convert a glob pattern to a .NET regex string.
# Supported wildcards: ** (any path), **/ (optional path prefix), * (non-slash chars), ? (single non-slash char).
function ConvertGlobToRegex {
    param([string]$Glob)

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.Append('^')
    $i = 0
    $len = $Glob.Length

    while ($i -lt $len) {
        $c = $Glob[$i]

        if ($c -eq '*') {
            if (($i + 1) -lt $len -and $Glob[$i + 1] -eq '*') {
                # Double-star
                if (($i + 2) -lt $len -and $Glob[$i + 2] -eq '/') {
                    # **/ => optional path prefix (matches zero or more path segments)
                    $null = $sb.Append('(.*?/)?')
                    $i += 3
                } else {
                    # ** at end or before non-slash => match anything
                    $null = $sb.Append('.*')
                    $i += 2
                }
            } else {
                # Single * => match anything except path separator
                $null = $sb.Append('[^/]*')
                $i++
            }
        } elseif ($c -eq '?') {
            $null = $sb.Append('[^/]')
            $i++
        } elseif ($c -in '.', '+', '(', ')', '[', ']', '{', '}', '^', '$', '|', '\') {
            # Escape regex metacharacters
            $null = $sb.Append('\' + $c)
            $i++
        } else {
            $null = $sb.Append($c)
            $i++
        }
    }

    $null = $sb.Append('$')
    return $sb.ToString()
}

# Test whether a file path matches a glob pattern.
function Test-GlobMatch {
    param(
        [string]$Path,
        [string]$Pattern
    )
    $regex = ConvertGlobToRegex -Glob $Pattern
    return [bool]($Path -match $regex)
}

# Given a list of changed file paths and an array of rule objects, return a
# deduplicated, priority-sorted list of labels to apply.
# Each rule: { pattern, label, priority }  (lower priority number = applied first in output)
function Get-LabelsForFiles {
    param(
        [string[]]$Files,
        [object[]]$Rules
    )

    # Map label -> best (lowest) priority that assigned it
    $labelPriority = @{}

    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.pattern) {
                $label = $rule.label
                $pri   = [int]$rule.priority
                if (-not $labelPriority.ContainsKey($label) -or $pri -lt $labelPriority[$label]) {
                    $labelPriority[$label] = $pri
                }
            }
        }
    }

    # Sort by priority ascending, then alphabetically to break ties
    return @($labelPriority.Keys | Sort-Object { $labelPriority[$_] }, { $_ })
}

# Load and validate label rules from a JSON config file.
function Import-LabelRules {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Label rules config not found: $Path"
    }

    $raw = Get-Content $Path -Raw -ErrorAction Stop
    $config = $raw | ConvertFrom-Json -ErrorAction Stop

    if (-not $config.rules) {
        throw "Rules config must have a 'rules' array: $Path"
    }

    return $config.rules
}
