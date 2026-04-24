# PR Label Assigner.
#
# Given a list of file paths and a set of rules (pattern -> label, with priority),
# emits the deduplicated set of labels that should be applied to a PR.
#
# Rules can match the same file multiple times (multiple labels per file) and
# tie-breaking on conflicts uses descending Priority, then label name.

Set-StrictMode -Version Latest

function Test-GlobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Pattern
    )
    # Translate a glob (supporting **, *, ?) into a regex.
    # ** -> match anything including '/'
    # *  -> match anything except '/'
    # ?  -> match a single non-'/' character
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $Pattern.Length) {
        $c = $Pattern[$i]
        switch ($c) {
            '*' {
                if ($i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                    [void]$sb.Append('.*')
                    $i += 2
                } else {
                    [void]$sb.Append('[^/]*')
                    $i += 1
                }
            }
            '?' { [void]$sb.Append('[^/]'); $i += 1 }
            default {
                # escape regex meta chars
                if ('.+()|[]{}^$\'.IndexOf([string]$c) -ge 0) {
                    [void]$sb.Append('\').Append($c)
                } else {
                    [void]$sb.Append($c)
                }
                $i += 1
            }
        }
    }
    [void]$sb.Append('$')
    $regex = $sb.ToString()
    # If the pattern contains no path separator, match against the basename too
    # (common labeler convention: bare patterns like '*.test.*' apply at any depth).
    if ($Pattern -notmatch '/') {
        $base = [System.IO.Path]::GetFileName($Path)
        if ([regex]::IsMatch($base, $regex)) { return $true }
    }
    return [regex]::IsMatch($Path, $regex)
}

function Get-PRLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string[]] $Files,
        [Parameter(Mandatory)] [object[]] $Rules
    )
    # Map: label -> highest priority seen.
    $labelPriority = @{}
    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                $existing = if ($labelPriority.ContainsKey($rule.Label)) { $labelPriority[$rule.Label] } else { [int]::MinValue }
                if ($rule.Priority -gt $existing) {
                    $labelPriority[$rule.Label] = [int]$rule.Priority
                }
            }
        }
    }
    if ($labelPriority.Count -eq 0) { return @() }
    # Sort: descending priority, then label name ascending.
    $sorted = $labelPriority.GetEnumerator() |
        Sort-Object @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { $_.Key }; Descending = $false }
    return @($sorted | ForEach-Object { $_.Key })
}

function Import-LabelRules {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Rules file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $parsed = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse rules JSON at ${Path}: $($_.Exception.Message)"
    }
    $result = foreach ($entry in $parsed) {
        [pscustomobject]@{
            Pattern  = [string]$entry.pattern
            Label    = [string]$entry.label
            Priority = if ($entry.PSObject.Properties.Name -contains 'priority') { [int]$entry.priority } else { 0 }
        }
    }
    return @($result)
}

function Invoke-LabelAssigner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $RulesPath,
        [Parameter(Mandatory)] [string] $FilesPath
    )
    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Files list not found: $FilesPath"
    }
    $rules = Import-LabelRules -Path $RulesPath
    $files = Get-Content -LiteralPath $FilesPath | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() }
    return Get-PRLabels -Files $files -Rules $rules
}

# When invoked directly (not dot-sourced), run end-to-end.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -ge 2) {
        $labels = @(Invoke-LabelAssigner -RulesPath $args[0] -FilesPath $args[1])
        if ($labels.Count -eq 0) {
            Write-Output 'LABELS:'
        } else {
            Write-Output ("LABELS: " + ($labels -join ','))
        }
    }
}
