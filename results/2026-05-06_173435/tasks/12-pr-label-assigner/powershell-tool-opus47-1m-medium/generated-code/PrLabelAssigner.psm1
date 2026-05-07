# PrLabelAssigner.psm1
#
# Maps a list of changed file paths to a set of labels using configurable
# glob-pattern rules. Each rule is { Pattern, Label, Priority }; a file matches
# a rule when its path matches Pattern. The output is a deduplicated list of
# labels ordered by descending rule priority.
#
# Glob semantics implemented here:
#   *   matches any sequence of characters except '/'
#   **  matches any sequence of characters including '/'
#   ?   matches a single character except '/'
# Patterns are anchored to the full path (start to end).

Set-StrictMode -Version Latest

function ConvertTo-RegexFromGlob {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Pattern)

    # Build the regex character-by-character so we can distinguish ** from *
    # and properly escape literal regex metacharacters.
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $Pattern.Length) {
        $c = $Pattern[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                [void]$sb.Append('.*')
                $i += 2
                continue
            }
            [void]$sb.Append('[^/]*')
            $i++
            continue
        }
        if ($c -eq '?') {
            [void]$sb.Append('[^/]')
            $i++
            continue
        }
        # Escape any regex metacharacter
        [void]$sb.Append([regex]::Escape([string]$c))
        $i++
    }
    [void]$sb.Append('$')
    $sb.ToString()
}

function Test-GlobMatch {
    <#
    .SYNOPSIS
    Returns $true when Path matches the glob Pattern.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )
    $regex = ConvertTo-RegexFromGlob -Pattern $Pattern
    return [regex]::IsMatch($Path, $regex)
}

function ConvertTo-RuleObject {
    # Normalize a rule (hashtable / PSCustomObject) into a uniform PSCustomObject
    # with Pattern/Label/Priority properties. Accepts case-insensitive keys.
    param([Parameter(Mandatory)]$Rule)
    if ($Rule -is [hashtable]) {
        return [pscustomobject]@{
            Pattern  = [string]$Rule['Pattern']
            Label    = [string]$Rule['Label']
            Priority = [int]($Rule['Priority'] ?? 0)
        }
    }
    # PSCustomObject from ConvertFrom-Json — properties may be lowercase.
    $props = $Rule.PSObject.Properties
    $pattern  = ($props | Where-Object { $_.Name -ieq 'pattern' }).Value
    $label    = ($props | Where-Object { $_.Name -ieq 'label' }).Value
    $priority = ($props | Where-Object { $_.Name -ieq 'priority' }).Value
    return [pscustomobject]@{
        Pattern  = [string]$pattern
        Label    = [string]$label
        Priority = [int]($priority ?? 0)
    }
}

function Get-PrLabels {
    <#
    .SYNOPSIS
    Apply label rules to a list of changed files and return the deduplicated
    label set ordered by descending rule priority.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedFiles,
        [Parameter(Mandatory)]$Rules
    )
    if ($null -eq $Rules) { throw 'Rules cannot be null' }

    $normalized = @($Rules | ForEach-Object { ConvertTo-RuleObject -Rule $_ })

    # Track highest priority observed for each matched label so we can sort.
    $labelPriority = [ordered]@{}
    foreach ($rule in $normalized) {
        if ([string]::IsNullOrWhiteSpace($rule.Pattern) -or
            [string]::IsNullOrWhiteSpace($rule.Label)) {
            throw "Rule must have non-empty Pattern and Label: $($rule | ConvertTo-Json -Compress)"
        }
        foreach ($file in $ChangedFiles) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                if (-not $labelPriority.Contains($rule.Label) -or
                    $labelPriority[$rule.Label] -lt $rule.Priority) {
                    $labelPriority[$rule.Label] = $rule.Priority
                }
            }
        }
    }

    $sorted = $labelPriority.GetEnumerator() |
        Sort-Object -Property @{Expression = 'Value'; Descending = $true},
                              @{Expression = 'Key';   Descending = $false} |
        ForEach-Object { $_.Key }
    return ,@($sorted)
}

function Import-LabelRules {
    <#
    .SYNOPSIS
    Load label rules from a JSON file. Each entry must have pattern, label,
    and priority fields.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Label rules file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $parsed = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse rules JSON at ${Path}: $($_.Exception.Message)"
    }
    return ,@($parsed | ForEach-Object { ConvertTo-RuleObject -Rule $_ })
}

function Invoke-LabelAssigner {
    <#
    .SYNOPSIS
    End-to-end: read rules JSON + changed-files JSON and emit ordered labels.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RulesPath,
        [Parameter(Mandatory)][string]$FilesPath
    )
    $rules = Import-LabelRules -Path $RulesPath
    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Changed-files file not found: $FilesPath"
    }
    $files = @((Get-Content -LiteralPath $FilesPath -Raw | ConvertFrom-Json))
    return Get-PrLabels -ChangedFiles $files -Rules $rules
}

Export-ModuleMember -Function Test-GlobMatch, Get-PrLabels, Import-LabelRules, Invoke-LabelAssigner
