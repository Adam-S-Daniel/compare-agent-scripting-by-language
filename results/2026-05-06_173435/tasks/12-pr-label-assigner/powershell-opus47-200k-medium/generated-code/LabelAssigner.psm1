# LabelAssigner.psm1
#
# Maps changed file paths to labels using configurable glob rules.
#
# Approach:
#   * Convert each glob to an anchored regex (`*` -> [^/]*, `**` -> .*, `?` -> [^/])
#     so we don't depend on PowerShell's -like, which has no `**` semantics.
#   * For every (file, rule) pair, if the file matches the rule's pattern,
#     emit all that rule's labels.
#   * The output is the deduped union of those labels, sorted by the
#     highest priority among rules that produced each label (priority desc).

Set-StrictMode -Version Latest

function Convert-GlobToRegex {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Glob)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    for ($i = 0; $i -lt $Glob.Length; $i++) {
        $c = $Glob[$i]
        if ($c -eq '*') {
            if (($i + 1) -lt $Glob.Length -and $Glob[$i + 1] -eq '*') {
                [void]$sb.Append('.*')   # ** crosses path separators
                $i++
            } else {
                [void]$sb.Append('[^/]*') # * matches within a single segment
            }
        } elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
        } else {
            # Escape any regex metacharacter in the literal portion
            [void]$sb.Append([regex]::Escape([string]$c))
        }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-GlobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Pattern
    )
    $rx = Convert-GlobToRegex -Glob $Pattern
    return [regex]::IsMatch($Path, $rx)
}

function Get-LabelsForFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Files,
        [Parameter(Mandatory)] [object[]] $Rules
    )

    # Track the highest priority seen per label so duplicates don't lower rank.
    $labelPriority = [ordered]@{}

    foreach ($rule in $Rules) {
        $pattern  = [string]   $rule.pattern
        $labels   = @($rule.labels)
        $priority = if ($null -ne $rule.priority) { [int]$rule.priority } else { 0 }

        foreach ($file in $Files) {
            if (Test-GlobMatch -Path $file -Pattern $pattern) {
                foreach ($label in $labels) {
                    if (-not $labelPriority.Contains($label) -or
                        $labelPriority[$label] -lt $priority) {
                        $labelPriority[$label] = $priority
                    }
                }
            }
        }
    }

    # Sort by priority descending, then alphabetically for stable output.
    $sorted = $labelPriority.GetEnumerator() |
        Sort-Object @{Expression={$_.Value};Descending=$true},
                    @{Expression={$_.Key};Descending=$false}
    return @($sorted | ForEach-Object { $_.Key })
}

Export-ModuleMember -Function Convert-GlobToRegex, Test-GlobMatch, Get-LabelsForFiles
