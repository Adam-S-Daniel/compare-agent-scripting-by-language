# PR Label Assigner
# ----------------
# Pure functions (Convert-GlobToRegex, Get-PrLabels) for testability,
# plus a thin file-driven entry point (Invoke-PrLabelAssigner) that the
# GitHub Actions workflow drives.
#
# Glob support:
#   *   -> any chars except '/'
#   **  -> any chars including '/'
#   ?   -> any single char except '/'
#
# Rule shape:
#   @{ pattern = 'docs/**'; label = 'documentation'; priority = 10 }
#
# Output ordering: descending priority, then alphabetical (deterministic).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-GlobToRegex {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Glob)

    # CODEOWNERS-style convention: patterns without a slash apply at any
    # directory depth (e.g. "*.test.*" matches "a/b/c.test.ts"). Patterns
    # containing a slash are anchored at the repo root.
    # If the pattern has no slash, allow it to match at any depth (including root).
    # We mark this with a sentinel that becomes "(?:.*/)?" in the regex.
    $g = if ($Glob -notmatch '/') { "<<ANY>>$Glob" } else { $Glob }

    # Walk char-by-char so we can distinguish ** from * cleanly. Everything
    # else gets regex-escaped so users never need to think about regex.
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $g.Length) {
        if ($i + 7 -le $g.Length -and $g.Substring($i, 7) -eq '<<ANY>>') {
            [void]$sb.Append('(?:.*/)?'); $i += 7; continue
        }
        $c = $g[$i]
        if ($c -eq '*' -and $i + 1 -lt $g.Length -and $g[$i+1] -eq '*') {
            [void]$sb.Append('.*'); $i += 2
        } elseif ($c -eq '*') {
            [void]$sb.Append('[^/]*'); $i++
        } elseif ($c -eq '?') {
            [void]$sb.Append('[^/]'); $i++
        } else {
            [void]$sb.Append([regex]::Escape([string]$c)); $i++
        }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Get-PrLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Files,
        # Each rule: @{ pattern; label; priority }. Accepts hashtables or
        # PSCustomObjects (e.g. from ConvertFrom-Json).
        [Parameter(Mandatory)]$Rules
    )

    # Pre-compile each pattern so we don't recompile per file.
    $compiled = foreach ($r in $Rules) {
        [pscustomobject]@{
            Regex    = [regex]::new((Convert-GlobToRegex $r.pattern))
            Label    = [string]$r.label
            Priority = [int]$r.priority
        }
    }

    $matched = @{}  # label -> priority (first-seen wins, identical labels share priority anyway)
    foreach ($f in $Files) {
        foreach ($c in $compiled) {
            if ($c.Regex.IsMatch($f) -and -not $matched.ContainsKey($c.Label)) {
                $matched[$c.Label] = $c.Priority
            }
        }
    }

    if ($matched.Count -eq 0) {
        # Force an empty array, not $null, so callers can rely on .Count.
        return ,@()
    }

    # Sort: priority desc, then label asc.
    $sorted = $matched.GetEnumerator() |
        Sort-Object @{ Expression = { $_.Value }; Descending = $true },
                    @{ Expression = { $_.Key  }; Descending = $false }
    return @($sorted | ForEach-Object { $_.Key })
}

function Invoke-PrLabelAssigner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilesPath,
        [Parameter(Mandatory)][string]$RulesPath
    )

    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Files list not found: $FilesPath"
    }
    if (-not (Test-Path -LiteralPath $RulesPath)) {
        throw "Rules file not found: $RulesPath"
    }

    $files = Get-Content -Raw -LiteralPath $FilesPath | ConvertFrom-Json
    $rulesDoc = Get-Content -Raw -LiteralPath $RulesPath | ConvertFrom-Json
    # Allow either { rules: [...] } or a bare [...].
    $rules = if ($rulesDoc.PSObject.Properties.Name -contains 'rules') { $rulesDoc.rules } else { $rulesDoc }

    $labels = Get-PrLabels -Files @($files) -Rules $rules
    # PowerShell unwraps 0- and 1-element arrays through pipelines, which would
    # turn [] into nothing and ["x"] into "x". Pass via -InputObject and
    # -AsArray so the JSON brackets are always preserved.
    return (ConvertTo-Json -InputObject @($labels) -Compress)
}

