# PRLabelAssigner: applies PR labels based on changed-file glob rules.
#
# Approach:
#  - Rules are simple records { Pattern, Labels[], Priority }.
#  - Patterns support ** (any depth), * (single segment), ? (single char).
#  - Each changed file is tested against every rule; matching rules contribute
#    their labels.  Output is deduped and sorted by priority, then label name.
#
# The public surface is three functions:
#   ConvertTo-GlobRegex   -- internal helper, exported for unit testability
#   Get-LabelRules        -- load rules from a JSON config file
#   Get-PRLabels          -- compute labels for a list of changed files + rules
#   Invoke-PRLabelAssigner -- thin CLI wrapper around the two above

Set-StrictMode -Version Latest

function ConvertTo-GlobRegex {
    <#
      Convert a glob pattern to an anchored regex.

      Order matters: ** must be translated before * so we do not double-escape.
      We use placeholders so later replacements don't clobber earlier ones.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    # Placeholders that cannot appear in a file path.
    $doubleStar = [char]0x0001
    $singleStar = [char]0x0002
    $questionCh = [char]0x0003

    $p = $Pattern
    $p = $p -replace '\*\*', [string]$doubleStar
    $p = $p -replace '\*',   [string]$singleStar
    $p = $p -replace '\?',   [string]$questionCh

    # Escape remaining regex metacharacters.
    $p = [regex]::Escape($p)

    # Expand placeholders back into regex fragments.
    # ** matches any characters including slash (and a leading "anything/" prefix
    # is collapsed to allow both "**/*.ext" == "*.ext" at root).
    $p = $p -replace [regex]::Escape([string]$doubleStar), '.*'
    $p = $p -replace [regex]::Escape([string]$singleStar), '[^/]*'
    $p = $p -replace [regex]::Escape([string]$questionCh), '[^/]'

    # Allow "**/foo" to also match "foo" at the root. Specifically: a leading
    # ".*/" may match zero characters too.
    $p = $p -replace '^\.\*/', '(?:.*/)?'

    return "^$p$"
}

function Test-GlobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )
    $regex = ConvertTo-GlobRegex -Pattern $Pattern
    return $Path -match $regex
}

function Get-LabelRules {
    <#
      Read a JSON configuration file describing label rules.

      Expected shape:
        { "rules": [ { "pattern": "...", "labels": ["..."], "priority": 10 } ] }

      Validation rules:
        - File must exist.
        - JSON must parse.
        - Each rule needs a non-empty pattern and at least one label.
        - Priority is optional (defaults to high integer = low importance).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $doc = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse config JSON '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $doc.rules) {
        throw "Config file '$Path' is missing top-level 'rules' array."
    }

    $out = New-Object System.Collections.Generic.List[object]
    $idx = 0
    foreach ($r in $doc.rules) {
        if ([string]::IsNullOrWhiteSpace($r.pattern)) {
            throw "Rule #$idx in '$Path' is missing a 'pattern'."
        }
        if ($null -eq $r.labels -or $r.labels.Count -eq 0) {
            throw "Rule #$idx in '$Path' has no 'labels'."
        }
        $priority = if ($r.PSObject.Properties.Name -contains 'priority' -and $null -ne $r.priority) {
            [int]$r.priority
        } else {
            [int]::MaxValue
        }
        $out.Add([pscustomobject]@{
            Pattern  = [string]$r.pattern
            Labels   = @($r.labels | ForEach-Object { [string]$_ })
            Priority = $priority
        })
        $idx++
    }
    return ,$out.ToArray()
}

function Get-PRLabels {
    <#
      Compute the final set of labels for a PR, given its changed files and a
      list of rules.  Rules may be hashtables or PSCustomObjects; both are
      accepted for convenience from tests and from config-loader output.

      Output is a string[] sorted by:
        1. Priority ascending (lower == more important)
        2. Label name ascending (for deterministic tie-break)
      Duplicates are removed, but when the same label is produced by several
      rules we retain the best (lowest) priority so it sorts correctly.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedFiles,
        [Parameter(Mandatory)][object[]]$Rules
    )

    $best = @{}  # label -> best priority seen

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $Rules) {
            $pattern = if ($rule -is [hashtable]) { $rule['Pattern'] } else { $rule.Pattern }
            if (-not (Test-GlobMatch -Path $file -Pattern $pattern)) { continue }

            $labels = if ($rule -is [hashtable]) { $rule['Labels'] } else { $rule.Labels }

            $priority = if ($rule -is [hashtable]) {
                if ($rule.ContainsKey('Priority')) { [int]$rule['Priority'] } else { [int]::MaxValue }
            } else {
                if ($rule.PSObject.Properties.Name -contains 'Priority' -and $null -ne $rule.Priority) {
                    [int]$rule.Priority
                } else {
                    [int]::MaxValue
                }
            }

            foreach ($lbl in $labels) {
                if (-not $best.ContainsKey($lbl) -or $priority -lt $best[$lbl]) {
                    $best[$lbl] = $priority
                }
            }
        }
    }

    $ordered = $best.GetEnumerator() |
        Sort-Object @{ Expression = { $_.Value } }, @{ Expression = { $_.Key } } |
        ForEach-Object { $_.Key }

    return ,@($ordered)
}

function Invoke-PRLabelAssigner {
    <#
      Thin CLI entry point: read rules from JSON, changed-files list from a
      newline-delimited text file, and write labels to stdout (one per line).
      Returns the label array for programmatic callers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RulesPath,
        [Parameter(Mandatory)][string]$FilesPath
    )

    if (-not (Test-Path -LiteralPath $FilesPath)) {
        throw "Changed-files list not found: $FilesPath"
    }

    $rules = Get-LabelRules -Path $RulesPath

    $files = Get-Content -LiteralPath $FilesPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }
    if ($null -eq $files) { $files = @() }

    $labels = Get-PRLabels -ChangedFiles @($files) -Rules $rules

    foreach ($l in $labels) { Write-Output $l }
    return $labels
}

Export-ModuleMember -Function ConvertTo-GlobRegex, Test-GlobMatch, Get-LabelRules, Get-PRLabels, Invoke-PRLabelAssigner
