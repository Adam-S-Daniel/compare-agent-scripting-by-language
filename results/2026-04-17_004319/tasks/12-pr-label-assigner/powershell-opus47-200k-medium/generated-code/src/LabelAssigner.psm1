# LabelAssigner.psm1
#
# Assigns labels to a PR based on its changed files and a configurable set of
# glob-based rules. The module is intentionally small so it can be driven from
# a CI workflow. Glob semantics follow GitHub / gitignore conventions:
#   *  matches within a path segment (no slash)
#   ** matches any number of path segments (including zero, with surrounding /)
#   ?  matches a single non-slash character

function ConvertTo-LabelRegex {
    # Translate a glob pattern to an anchored regex. Literal parts are escaped
    # so that characters like '.' and '+' don't act as regex metacharacters.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Pattern)

    $sb = [System.Text.StringBuilder]::new('^')
    for ($i = 0; $i -lt $Pattern.Length; $i++) {
        $c = $Pattern[$i]
        if ($c -eq '*') {
            if ($i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                # **/ at start or in middle matches zero or more path segments.
                if ($i + 2 -lt $Pattern.Length -and $Pattern[$i + 2] -eq '/') {
                    [void]$sb.Append('(?:.*/)?')
                    $i += 2
                } else {
                    [void]$sb.Append('.*')
                    $i++
                }
            } else {
                [void]$sb.Append('[^/]*')
            }
        } elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
        } else {
            [void]$sb.Append([regex]::Escape([string]$c))
        }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-LabelGlob {
    # Returns $true when Path matches the supplied glob Pattern.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )
    $regex = ConvertTo-LabelRegex -Pattern $Pattern
    return [regex]::IsMatch($Path, $regex)
}

function Get-FileLabels {
    # Given a list of changed files and an ordered list of rules, produce the
    # union of labels that should be applied. Each rule must expose:
    #   pattern  - glob string
    #   labels   - array of labels to add when the rule matches
    #   priority - integer; lower wins (used only when -HighestPriorityOnly)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Files,
        [Parameter(Mandatory)][object[]]$Rules,
        [switch]$HighestPriorityOnly
    )

    $resultSet = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($file in $Files) {
        $matching = @()
        foreach ($rule in $Rules) {
            if (Test-LabelGlob -Path $file -Pattern $rule.pattern) {
                $matching += ,$rule
            }
        }
        if ($matching.Count -eq 0) { continue }

        if ($HighestPriorityOnly) {
            # Lower priority number == higher priority (conventional in CI tools).
            $winner = $matching | Sort-Object -Property priority | Select-Object -First 1
            foreach ($l in $winner.labels) { [void]$resultSet.Add($l) }
        } else {
            foreach ($rule in $matching) {
                foreach ($l in $rule.labels) { [void]$resultSet.Add($l) }
            }
        }
    }

    # Return as a sorted array for determinism. The unary comma prevents
    # PowerShell from unwrapping an empty array to $null at the call site.
    return ,@($resultSet | Sort-Object)
}

function Invoke-LabelAssigner {
    # CLI-style entrypoint. Reads JSON files and prints one label per line to
    # stdout (also returns them so the function can be used programmatically).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilesPath,
        [Parameter(Mandatory)][string]$RulesPath,
        [switch]$HighestPriorityOnly
    )

    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Files input not found: $FilesPath"
    }
    if (-not (Test-Path -LiteralPath $RulesPath)) {
        throw "Rules input not found: $RulesPath"
    }

    $files = Get-Content -LiteralPath $FilesPath -Raw | ConvertFrom-Json
    $rules = Get-Content -LiteralPath $RulesPath -Raw | ConvertFrom-Json

    # ConvertFrom-Json returns a single object when the JSON contains one
    # element; normalise to arrays so downstream iteration is uniform.
    if ($null -eq $files) { $files = @() } elseif ($files -isnot [array]) { $files = @($files) }
    if ($null -eq $rules) { $rules = @() } elseif ($rules -isnot [array]) { $rules = @($rules) }

    $labels = Get-FileLabels -Files $files -Rules $rules -HighestPriorityOnly:$HighestPriorityOnly
    foreach ($l in $labels) { Write-Output $l }
}

Export-ModuleMember -Function ConvertTo-LabelRegex, Test-LabelGlob, Get-FileLabels, Invoke-LabelAssigner
