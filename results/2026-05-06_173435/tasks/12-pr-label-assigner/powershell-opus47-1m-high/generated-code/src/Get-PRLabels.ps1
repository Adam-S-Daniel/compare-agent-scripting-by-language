#requires -Version 7.2

<#
.SYNOPSIS
    Assigns PR labels from a list of changed file paths using glob-pattern rules.

.DESCRIPTION
    The script exposes three commands.

      ConvertTo-GlobRegex            Pure helper. Translates a glob (with **,
                                     *, ?) into a .NET-compatible regex. Lives
                                     here for testability — it is the part most
                                     prone to off-by-one bugs.

      Get-PRLabels                   Core function. Given an array of changed
                                     file paths and an array of rule objects
                                     ({ Pattern, Label, Priority?, Group? }),
                                     returns the deduplicated, ordered set of
                                     labels.

      Invoke-PRLabelAssignerFromJson Thin file-driven adapter so CI can hand the
                                     script two JSON files and write the labels
                                     to stdout, one per line.

    Conflict semantics: rules that share a non-empty `Group` are mutually
    exclusive. When two such rules match the same file, the one with the higher
    `Priority` wins. Rules without a `Group` are independent and stack.

    Output ordering: labels are returned in descending Priority order, with
    ties broken alphabetically. The maximum priority of any rule that produced
    the label is what counts (a label can be produced by several rules).

    Errors are surfaced as terminating exceptions with messages that name the
    offending rule index and the missing field, so they are useful in CI logs.
#>

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'


function ConvertTo-GlobRegex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Pattern
    )

    # Strategy: walk the input character by character. We need to translate
    # `**`, `*`, and `?` while leaving every other regex metacharacter
    # ESCAPED so that, for example, "a.b" only matches "a.b" not "aXb".
    #
    # Doing this with a series of -replace calls is fragile because the
    # tokens overlap (`**` vs `*`) and the replacements interact with their
    # own output. A single forward pass keeps the precedence obvious.
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')

    $i = 0
    while ($i -lt $Pattern.Length) {
        $c = $Pattern[$i]
        switch ($c) {
            '*' {
                if ($i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                    # `**` -> match any character (including / ) any number of
                    # times.  The non-greedy form keeps engine work bounded and
                    # is fine here because we anchor with $.
                    [void]$sb.Append('.*')
                    $i += 2
                } else {
                    # `*` -> any non-separator characters.
                    [void]$sb.Append('[^/]*')
                    $i += 1
                }
            }
            '?' {
                [void]$sb.Append('[^/]')
                $i += 1
            }
            default {
                [void]$sb.Append([regex]::Escape([string]$c))
                $i += 1
            }
        }
    }

    [void]$sb.Append('$')
    return $sb.ToString()
}


function Get-PRLabels {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $ChangedFiles,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Rules
    )

    # Validate rules up-front. Doing it here (rather than lazily) means a
    # malformed config fails fast in CI instead of producing partial output.
    $compiled = @()
    for ($idx = 0; $idx -lt $Rules.Count; $idx++) {
        $rule = $Rules[$idx]

        $pattern  = _Get-RuleField -Rule $rule -Field 'Pattern' -Required -Index $idx
        $label    = _Get-RuleField -Rule $rule -Field 'Label'   -Required -Index $idx
        $priority = _Get-RuleField -Rule $rule -Field 'Priority' -Default 0 -Index $idx
        $group    = _Get-RuleField -Rule $rule -Field 'Group'    -Default '' -Index $idx

        $compiled += [pscustomobject]@{
            Pattern  = $pattern
            Label    = $label
            Priority = [int]$priority
            Group    = [string]$group
            Regex    = [regex](ConvertTo-GlobRegex -Pattern $pattern)
        }
    }

    if ($ChangedFiles.Count -eq 0) {
        return @()
    }

    # Per-file: collect every matching rule.  Then resolve Group conflicts on
    # a per-file basis: within a single file, only the highest-priority rule
    # in each Group contributes its label.  This matches the user's mental
    # model of "this file is in the api area, not the src area".
    $aggregate = [System.Collections.Generic.Dictionary[string,int]]::new()

    foreach ($file in $ChangedFiles) {
        $matched = foreach ($rule in $compiled) {
            if ($rule.Regex.IsMatch($file)) { $rule }
        }
        if (-not $matched) { continue }

        # Resolve groups: keep the top-priority rule per non-empty group, and
        # keep all ungrouped rules.
        $kept = @()
        $kept += $matched | Where-Object { -not $_.Group }
        $kept += $matched |
            Where-Object { $_.Group } |
            Group-Object -Property Group |
            ForEach-Object {
                ($_.Group | Sort-Object -Property Priority -Descending)[0]
            }

        foreach ($rule in $kept) {
            if ($aggregate.ContainsKey($rule.Label)) {
                if ($rule.Priority -gt $aggregate[$rule.Label]) {
                    $aggregate[$rule.Label] = $rule.Priority
                }
            } else {
                $aggregate[$rule.Label] = $rule.Priority
            }
        }
    }

    if ($aggregate.Count -eq 0) {
        return @()
    }

    # Final ordering: descending priority, then alphabetical for stability.
    $ordered = $aggregate.GetEnumerator() |
        Sort-Object -Property @{ Expression = 'Value'; Descending = $true },
                              @{ Expression = 'Key';   Descending = $false } |
        ForEach-Object { $_.Key }

    return ,@($ordered)
}


function _Get-RuleField {
    # Internal helper. Pulls a field off a rule object regardless of whether
    # the object is a [pscustomobject], [hashtable], or
    # [System.Collections.IDictionary]. Returns $Default when the field is
    # absent and -Required was not specified; otherwise throws.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] [string] $Field,
        [switch] $Required,
        $Default = $null,
        [int] $Index = -1
    )

    $value = $null
    $hasValue = $false

    if ($Rule -is [System.Collections.IDictionary]) {
        if ($Rule.Contains($Field)) {
            $value = $Rule[$Field]
            $hasValue = $true
        }
    } else {
        $prop = $Rule.PSObject.Properties[$Field]
        if ($null -ne $prop) {
            $value = $prop.Value
            $hasValue = $true
        }
    }

    if (-not $hasValue -or $null -eq $value -or ($value -is [string] -and $value -eq '')) {
        if ($Required) {
            throw "Rule at index $Index is missing required field '$Field'."
        }
        return $Default
    }

    return $value
}


function Invoke-PRLabelAssignerFromJson {
    <#
    .SYNOPSIS
        File-driven entry point used by the GitHub Actions workflow.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [string] $ChangedFilesJsonPath,
        [Parameter(Mandatory)] [string] $RulesJsonPath
    )

    if (-not (Test-Path -LiteralPath $ChangedFilesJsonPath)) {
        throw "Changed-files JSON file not found: $ChangedFilesJsonPath"
    }
    if (-not (Test-Path -LiteralPath $RulesJsonPath)) {
        throw "Rules JSON file not found: $RulesJsonPath"
    }

    $filesRaw = Get-Content -LiteralPath $ChangedFilesJsonPath -Raw
    $rulesRaw = Get-Content -LiteralPath $RulesJsonPath -Raw

    $files = @()
    if (-not [string]::IsNullOrWhiteSpace($filesRaw)) {
        $parsed = $filesRaw | ConvertFrom-Json
        # ConvertFrom-Json returns a single object when the JSON has one
        # element; coerce to array so .Count works either way.
        if ($null -ne $parsed) { $files = @($parsed) }
    }

    $rules = @()
    if (-not [string]::IsNullOrWhiteSpace($rulesRaw)) {
        $parsed = $rulesRaw | ConvertFrom-Json
        if ($null -ne $parsed) { $rules = @($parsed) }
    }

    return Get-PRLabels -ChangedFiles ([string[]]$files) -Rules ([object[]]$rules)
}
