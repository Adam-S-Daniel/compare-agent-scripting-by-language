# PRLabelAssigner.psm1
# Applies labels to a PR based on its changed file paths and a set of
# glob-pattern rules. Each rule carries one-or-more labels and a priority;
# higher priority labels appear first in the output. Labels are deduplicated
# across all matched rules.

function Convert-GlobToRegex {
    # Converts a glob pattern into an anchored regex.
    #   **  -> .*           (matches across path separators)
    #   *   -> [^/]*        (matches within one path segment)
    #   ?   -> .            (matches a single character)
    # All other regex metacharacters are escaped.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Glob
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $Glob.Length) {
        $ch = $Glob[$i]
        # "**/" should match zero or more directory segments, so "**/foo"
        # matches both "foo" and "a/b/foo".
        if ($ch -eq '*' -and $i + 2 -lt $Glob.Length -and $Glob[$i + 1] -eq '*' -and $Glob[$i + 2] -eq '/') {
            [void]$sb.Append('(?:.*/)?')
            $i += 3
            continue
        }
        if ($ch -eq '*' -and $i + 1 -lt $Glob.Length -and $Glob[$i + 1] -eq '*') {
            [void]$sb.Append('.*')
            $i += 2
            continue
        }
        switch ($ch) {
            '*' { [void]$sb.Append('[^/]*') }
            '?' { [void]$sb.Append('.') }
            default {
                # Escape regex metachar when needed
                if ('.+()[]{}|^$\'.Contains($ch)) {
                    [void]$sb.Append('\').Append($ch)
                } else {
                    [void]$sb.Append($ch)
                }
            }
        }
        $i++
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-GlobMatch {
    # True when $Path matches the glob $Pattern.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )
    $regex = Convert-GlobToRegex -Glob $Pattern
    return [regex]::IsMatch($Path, $regex)
}

function Invoke-PRLabelAssigner {
    <#
        Main entry point.

        Parameters:
          ChangedFiles : string[]    list of PR-changed paths
          Rules        : hashtable[] each with: pattern (string),
                                                 labels (string[]),
                                                 priority (int, default 0)

        Returns a deduplicated, priority-ordered array of labels.
        A label's effective priority is the max priority among the rules
        that introduced it. Ties break alphabetically.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rules
    )

    # Validate rules up-front for clear errors.
    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('pattern')) {
            throw "Rule is missing required field 'pattern': $($rule | ConvertTo-Json -Compress)"
        }
        if (-not $rule.ContainsKey('labels')) {
            throw "Rule is missing required field 'labels': $($rule | ConvertTo-Json -Compress)"
        }
    }

    # label => highest priority seen
    $labelPriority = @{}
    foreach ($file in $ChangedFiles) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.pattern) {
                $prio = if ($rule.ContainsKey('priority')) { [int]$rule.priority } else { 0 }
                foreach ($label in $rule.labels) {
                    if (-not $labelPriority.ContainsKey($label) -or $labelPriority[$label] -lt $prio) {
                        $labelPriority[$label] = $prio
                    }
                }
            }
        }
    }

    # Sort by priority desc, then label name asc.
    $ordered = @($labelPriority.GetEnumerator() |
        Sort-Object @{Expression = { $_.Value }; Descending = $true }, @{Expression = { $_.Key }; Descending = $false } |
        ForEach-Object { $_.Key })

    # Emit each label to the output stream. Callers that need a guaranteed
    # array should wrap the call with @(...).
    return $ordered
}

function Get-RulesFromFile {
    # Load rules from a JSON file. JSON arrives as PSCustomObject; convert to
    # hashtables so the rest of the pipeline can use ContainsKey uniformly.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Rules file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse rules JSON at $Path : $($_.Exception.Message)"
    }
    $result = foreach ($item in $parsed) {
        $h = @{}
        foreach ($p in $item.PSObject.Properties) { $h[$p.Name] = $p.Value }
        # Normalize labels from object[] to string[] for downstream use.
        if ($h.ContainsKey('labels')) { $h.labels = @($h.labels) }
        $h
    }
    return ,@($result)
}

Export-ModuleMember -Function Convert-GlobToRegex, Test-GlobMatch, Invoke-PRLabelAssigner, Get-RulesFromFile
