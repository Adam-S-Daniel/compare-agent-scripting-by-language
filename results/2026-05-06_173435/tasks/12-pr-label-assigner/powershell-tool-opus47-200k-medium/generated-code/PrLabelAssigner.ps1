# PR Label Assigner: maps a list of changed file paths to a set of labels
# using configurable glob rules. Pure functions are exported for unit testing;
# the CLI entrypoint Invoke-PrLabelAssigner reads from disk and emits one label per line.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-GlobMatch {
    # Translates a git-style glob (supporting *, **, ?) into a regex anchored
    # to the whole path, then tests the file path against it.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Pattern
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $Pattern.Length) {
        $c = $Pattern[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                # ** matches any sequence including '/'.
                # Handle the conventional "**/" form: collapse the trailing slash so
                # that the pattern can also match zero directories (e.g. docs/** matches docs/x.md).
                $i += 2
                if ($i -lt $Pattern.Length -and $Pattern[$i] -eq '/') {
                    [void]$sb.Append('(?:.*/)?')
                    $i++
                } else {
                    [void]$sb.Append('.*')
                }
                continue
            } else {
                # Single * matches anything except '/'.
                [void]$sb.Append('[^/]*')
                $i++
                continue
            }
        }
        elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
        }
        elseif ('.+()|^$[]{}\'.Contains($c)) {
            [void]$sb.Append('\').Append($c) | Out-Null
        }
        else {
            [void]$sb.Append($c)
        }
        $i++
    }
    [void]$sb.Append('$')
    return $Path -match $sb.ToString()
}

function Get-AssignedLabels {
    # Returns the deduplicated label set for a given list of files.
    # Output is ordered by descending rule priority, then alphabetically within a priority.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Files,
        [Parameter(Mandatory)] [object[]] $Rules
    )

    # Track the highest priority a label has been assigned at, for ordering.
    $labelPriority = @{}
    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.pattern) {
                foreach ($label in $rule.labels) {
                    if (-not $labelPriority.ContainsKey($label) -or $rule.priority -gt $labelPriority[$label]) {
                        $labelPriority[$label] = [int]$rule.priority
                    }
                }
            }
        }
    }

    if ($labelPriority.Count -eq 0) { return @() }

    return @($labelPriority.GetEnumerator() |
        Sort-Object @{Expression = { $_.Value }; Descending = $true}, @{Expression = { $_.Key }; Descending = $false} |
        ForEach-Object { $_.Key })
}

function Invoke-PrLabelAssigner {
    # CLI entrypoint. Loads rules JSON and a newline-separated files list,
    # writes labels one per line to stdout (also returns them for callers).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RulesPath,
        [Parameter(Mandatory)] [string] $FilesPath
    )

    if (-not (Test-Path -LiteralPath $RulesPath)) {
        throw "Rules file not found: $RulesPath"
    }
    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Files list not found: $FilesPath"
    }

    $raw = Get-Content -LiteralPath $RulesPath -Raw
    try {
        $rules = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse rules JSON ($RulesPath): $($_.Exception.Message)"
    }

    # Normalize to an array even if JSON has a single object.
    if ($rules -isnot [System.Array]) { $rules = @($rules) }

    $files = Get-Content -LiteralPath $FilesPath |
        Where-Object { $_ -and $_.Trim().Length -gt 0 }

    $labels = Get-AssignedLabels -Files @($files) -Rules @($rules)
    foreach ($l in $labels) { Write-Output $l }
}

# Allow direct script invocation: `pwsh PrLabelAssigner.ps1 -RulesPath ... -FilesPath ...`
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # no-op: parameters are not bound at script scope here
    }
}
