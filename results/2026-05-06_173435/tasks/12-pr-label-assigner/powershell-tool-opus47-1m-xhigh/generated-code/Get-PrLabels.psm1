# Get-PrLabels.psm1
#
# A small library that decides which labels to apply to a pull request based
# on its changed-files list and a set of glob -> label mapping rules.
#
# Public surface:
#   - Get-PrLabels       : returns the (deduplicated, priority-ordered) labels
#                          for a list of changed files
#   - Convert-GlobToRegex: glob -> anchored .NET regex (exposed for testability;
#                          not intended as a public CLI)
#
# Glob syntax (a small, gitignore-flavored subset):
#   *      matches any run of characters that does NOT cross a directory
#          boundary (i.e. cannot match '/').
#   ?      matches a single non-'/' character.
#   **     matches any number of path segments (including zero) when used as
#          its own segment ('**/foo', 'foo/**', 'a/**/b'). When **
#          stands alone it matches any path. When ** is not delimited by
#          slashes (e.g. used inside a segment) it falls back to '.*' so the
#          result is still useful but not segment-aware.
#   anything else is treated as a literal character.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-GlobToRegex {
    <#
    .SYNOPSIS
      Convert a path glob into an anchored .NET regular expression.
    .DESCRIPTION
      Designed for matching repository-relative paths. The returned pattern is
      anchored with ^ and $ so callers can use it directly with -match.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Glob
    )

    # Normalize Windows-style separators so a single regex works on either
    # platform. Callers are expected to do the same on the input path.
    $Glob = $Glob -replace '\\', '/'

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')

    $i = 0
    $len = $Glob.Length
    while ($i -lt $len) {
        $c = $Glob[$i]

        if ($c -eq '*') {
            $isDouble = ($i + 1 -lt $len) -and ($Glob[$i + 1] -eq '*')
            if ($isDouble) {
                $atStart     = ($i -eq 0)
                $atEnd       = ($i + 2 -eq $len)
                $prevIsSlash = (-not $atStart) -and ($Glob[$i - 1] -eq '/')
                $nextIsSlash = ($i + 2 -lt $len) -and ($Glob[$i + 2] -eq '/')

                if ($atStart -and $nextIsSlash) {
                    # Pattern begins with '**/': match zero or more leading
                    # directory segments, no leading '/' required.
                    [void]$sb.Append('(?:.*/)?')
                    $i += 3
                }
                elseif ($prevIsSlash -and $nextIsSlash) {
                    # 'a/**/b': zero or more directories between the literals.
                    # Rewind the previously-emitted '/' so we can re-emit a
                    # single '(?:/.*)?/' that also accepts the zero-dir case
                    # ('a/b' for 'a/**/b').
                    if ($sb.Length -gt 0 -and $sb[$sb.Length - 1] -eq '/') {
                        [void]$sb.Remove($sb.Length - 1, 1)
                    }
                    [void]$sb.Append('(?:/.*)?/')
                    $i += 3
                }
                elseif ($prevIsSlash -and $atEnd) {
                    # 'foo/**': match anything under foo/.
                    [void]$sb.Append('.*')
                    $i += 2
                }
                elseif ($atStart -and $atEnd) {
                    # Bare '**': match everything.
                    [void]$sb.Append('.*')
                    $i += 2
                }
                else {
                    # ** in some other position (fused with other chars).
                    # Fall back to a permissive '.*'.
                    [void]$sb.Append('.*')
                    $i += 2
                }
            }
            else {
                [void]$sb.Append('[^/]*')
                $i += 1
            }
        }
        elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
            $i += 1
        }
        else {
            # Escape regex metacharacters; everything else is a literal.
            if ('.+(){}[]|^$\'.Contains([string]$c)) {
                [void]$sb.Append('\').Append($c)
            }
            else {
                [void]$sb.Append($c)
            }
            $i += 1
        }
    }

    [void]$sb.Append('$')
    return $sb.ToString()
}

function Get-RuleField {
    # Helper: read a field from a rule that may be a hashtable, ordered
    # dictionary, or PSCustomObject (as produced by ConvertFrom-Json).
    # Returns $null when the field is absent.
    param(
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] [string[]]$Names
    )
    foreach ($name in $Names) {
        if ($Rule -is [System.Collections.IDictionary]) {
            if ($Rule.Contains($name)) { return $Rule[$name] }
        }
        elseif ($Rule -is [psobject]) {
            $prop = $Rule.PSObject.Properties[$name]
            if ($null -ne $prop) { return $prop.Value }
        }
    }
    return $null
}

function Resolve-Rule {
    # Normalize a single user-supplied rule into a fixed-shape PSCustomObject
    # carrying the compiled regex. Throws on malformed input.
    param(
        [Parameter(Mandatory)] $Rule,
        [Parameter(Mandatory)] [int]$Index
    )

    $pattern  = Get-RuleField -Rule $Rule -Names @('pattern',  'Pattern')
    $labels   = Get-RuleField -Rule $Rule -Names @('labels',   'Labels')
    $priority = Get-RuleField -Rule $Rule -Names @('priority', 'Priority')

    if (-not $pattern -or [string]::IsNullOrWhiteSpace([string]$pattern)) {
        throw "Rule at index $Index is missing a 'pattern'."
    }
    if ($null -eq $labels) {
        throw "Rule at index $Index (pattern '$pattern') has no labels."
    }
    # Wrap in @() so strict mode is happy when Where-Object returns a scalar
    # or $null (it doesn't expose .Count on those).
    $labelArray = @(@($labels) | Where-Object { $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($labelArray.Count -eq 0) {
        throw "Rule at index $Index (pattern '$pattern') has no labels."
    }

    $prio = 0
    if ($null -ne $priority) {
        try { $prio = [int]$priority }
        catch { throw "Rule at index $Index (pattern '$pattern') has a non-integer priority '$priority'." }
    }

    [pscustomobject]@{
        Pattern    = [string]$pattern
        Labels     = [string[]]$labelArray
        Priority   = $prio
        OrderIndex = $Index
        Regex      = (Convert-GlobToRegex -Glob ([string]$pattern))
    }
}

function Get-PrLabels {
    <#
    .SYNOPSIS
      Compute the set of labels that should be applied to a PR given its
      list of changed files and a set of glob -> label rules.

    .DESCRIPTION
      Each rule is matched against every changed file (using the glob syntax
      documented at the top of this module). Every matching rule contributes
      its labels. Duplicate labels are deduplicated. The final list is sorted
      first by descending priority (so the highest-priority labels appear
      first), then by the rule's declaration order to keep the result
      deterministic when priorities tie.

    .PARAMETER ChangedFiles
      The list of repository-relative paths considered changed for this PR.
      Forward and backward slashes are accepted; the function normalizes
      backslashes to forward slashes before matching.

    .PARAMETER ConfigPath
      Path to a JSON configuration file with shape:
        { "rules": [ { "pattern": "...", "labels": ["..."], "priority": 0 }, ... ] }

    .PARAMETER Rules
      An array of rules supplied directly (hashtables or objects with
      'pattern' / 'labels' / optional 'priority'). Mutually exclusive with
      -ConfigPath.

    .OUTPUTS
      [string[]] - the deduplicated, priority-ordered labels (or an empty
      array when nothing matches).
    #>
    [CmdletBinding(DefaultParameterSetName = 'Rules')]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(ParameterSetName = 'Config', Mandatory)]
        [string]$ConfigPath,

        [Parameter(ParameterSetName = 'Rules', Mandatory)]
        [object[]]$Rules
    )

    # Load rules from a JSON config file when the user picked that path.
    if ($PSCmdlet.ParameterSetName -eq 'Config') {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Config file not found: $ConfigPath"
        }
        try {
            $configText = Get-Content -LiteralPath $ConfigPath -Raw
            $configObj  = $configText | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "Failed to parse config file '$ConfigPath': $($_.Exception.Message)"
        }

        $rulesField = $null
        if ($configObj -is [psobject]) {
            $rulesField = $configObj.PSObject.Properties['rules']
        }
        if ($null -eq $rulesField -or $null -eq $rulesField.Value) {
            throw "Config file '$ConfigPath' contains no rules."
        }
        $Rules = @($rulesField.Value)
        if ($Rules.Count -eq 0) {
            throw "Config file '$ConfigPath' contains no rules."
        }
    }

    if ($null -eq $Rules -or $Rules.Count -eq 0) {
        throw "No rules provided."
    }

    # Validate + compile every rule up-front so a single malformed rule is
    # surfaced even if no file would have matched it.
    $compiled = for ($i = 0; $i -lt $Rules.Count; $i++) {
        Resolve-Rule -Rule $Rules[$i] -Index $i
    }

    if ($ChangedFiles.Count -eq 0) {
        return @()
    }

    # label name -> { MaxPriority, FirstSeenOrder }
    $labelInfo = [System.Collections.Specialized.OrderedDictionary]::new(
        [System.StringComparer]::Ordinal)

    foreach ($file in $ChangedFiles) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        $normalized = ([string]$file) -replace '\\', '/'

        foreach ($rule in $compiled) {
            if ($normalized -match $rule.Regex) {
                foreach ($label in $rule.Labels) {
                    if (-not $labelInfo.Contains($label)) {
                        $labelInfo[$label] = [pscustomobject]@{
                            MaxPriority    = $rule.Priority
                            FirstSeenOrder = $rule.OrderIndex
                        }
                    }
                    else {
                        $entry = $labelInfo[$label]
                        if ($rule.Priority -gt $entry.MaxPriority) {
                            $entry.MaxPriority    = $rule.Priority
                            $entry.FirstSeenOrder = $rule.OrderIndex
                        }
                        elseif ($rule.Priority -eq $entry.MaxPriority -and
                                $rule.OrderIndex -lt $entry.FirstSeenOrder) {
                            $entry.FirstSeenOrder = $rule.OrderIndex
                        }
                    }
                }
            }
        }
    }

    if ($labelInfo.Count -eq 0) {
        return @()
    }

    $sorted = $labelInfo.GetEnumerator() | Sort-Object @(
        @{ Expression = { $_.Value.MaxPriority }; Descending = $true },
        @{ Expression = { $_.Value.FirstSeenOrder }; Descending = $false }
    )

    # Force an array result so a single-label match still returns [string[]],
    # not a bare [string].
    return ,@($sorted | ForEach-Object { [string]$_.Key })
}

Export-ModuleMember -Function Get-PrLabels, Convert-GlobToRegex
