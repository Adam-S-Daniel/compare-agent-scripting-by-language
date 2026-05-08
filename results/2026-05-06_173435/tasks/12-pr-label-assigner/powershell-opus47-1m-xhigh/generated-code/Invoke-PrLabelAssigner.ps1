<#
.SYNOPSIS
    Apply labels to a simulated pull request based on its changed file paths.

.DESCRIPTION
    Reads a list of changed file paths and a JSON configuration of glob-pattern
    -> label rules, then emits the deduplicated set of labels that match.
    Supports:
      * Glob patterns including '**' (multi-segment), '*' (single segment) and '?'.
      * Multiple labels per rule.
      * Priority ordering: when multiple rules match, the higher-priority rule's
        labels appear first in the output.

    The script is dot-source-friendly: when run with no parameters it loads its
    helper functions for testing; when run with -FilesPath and -ConfigPath it
    runs the full pipeline and writes the result to stdout in the requested
    Format ('csv' | 'json' | 'lines').

.PARAMETER FilesPath
    Path to a text file containing one changed-file path per line. Blank lines
    and lines starting with '#' are ignored.

.PARAMETER ConfigPath
    Path to a JSON file shaped like:
        { "rules": [ { "pattern": "docs/**", "labels": ["documentation"], "priority": 10 } ] }

.PARAMETER Format
    Output format. 'csv' (default) prints a single comma-separated line.
    'json' prints { "labels": [...] }. 'lines' prints one label per line.

.PARAMETER GitHubOutput
    Optional path to a GitHub Actions $GITHUB_OUTPUT file. When set, the
    script appends 'labels=<csv>' and 'count=<n>' lines so the workflow can
    consume the result via steps.<id>.outputs.labels.

.EXAMPLE
    pwsh ./Invoke-PrLabelAssigner.ps1 -FilesPath changed.txt -ConfigPath rules.json -Format json
#>
[CmdletBinding(DefaultParameterSetName = 'Library')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [string]$FilesPath,

    [Parameter(Mandatory, ParameterSetName = 'Run')]
    [string]$ConfigPath,

    [Parameter(ParameterSetName = 'Run')]
    [ValidateSet('csv', 'json', 'lines')]
    [string]$Format = 'csv',

    [Parameter(ParameterSetName = 'Run')]
    [string]$GitHubOutput
)

# --- Library functions ---------------------------------------------------

function Convert-GlobToRegex {
    <#
    .SYNOPSIS
        Convert a glob pattern into an anchored .NET regex.

    .DESCRIPTION
        Glob semantics (gitignore-flavored):
          **/    at the start: optional any-number-of-directories prefix.
          /**/   in the middle: '/' plus optional any-number-of-directories.
          **     standalone: matches any sequence of characters incl. '/'.
          *      matches any sequence of characters except '/'.
          ?      matches any single character except '/'.
        All other regex metacharacters are escaped so they match literally.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Pattern)

    # Tokenize so wildcards survive the per-character regex escape pass.
    # Use unprintable placeholders that cannot appear in real paths.
    $LEAD   = [char]0x01   # leading '**/' sentinel
    $MID    = [char]0x02   # '/**/' sentinel
    $DOUBLE = [char]0x03   # bare '**'
    $STAR   = [char]0x04   # '*'
    $QMARK  = [char]0x05   # '?'

    $t = $Pattern
    if ($t.StartsWith('**/')) {
        $t = [string]$LEAD + $t.Substring(3)
    }
    $t = $t.Replace('/**/', [string]$MID)
    $t = $t.Replace('**', [string]$DOUBLE)
    $t = $t.Replace('*',  [string]$STAR)
    $t = $t.Replace('?',  [string]$QMARK)

    $escaped = [System.Text.RegularExpressions.Regex]::Escape($t)

    $escaped = $escaped.Replace([string]$LEAD,   '(?:.*/)?')
    $escaped = $escaped.Replace([string]$MID,    '/(?:.*/)?')
    $escaped = $escaped.Replace([string]$DOUBLE, '.*')
    $escaped = $escaped.Replace([string]$STAR,   '[^/]*')
    $escaped = $escaped.Replace([string]$QMARK,  '[^/]')

    return '^' + $escaped + '$'
}

function Test-PathMatchesGlob {
    <#
    .SYNOPSIS
        Test whether a single path matches a glob pattern.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )

    $regex = Convert-GlobToRegex $Pattern
    return [bool]($Path -match $regex)
}

function Get-LabelsForFiles {
    <#
    .SYNOPSIS
        Resolve the deduplicated, priority-ordered label set for a file list.

    .DESCRIPTION
        Returns labels sorted by descending rule priority. Within the same
        priority, labels keep the order they appear in the rules. Labels that
        appear in multiple matched rules are kept at their highest priority.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Files,
        [Parameter(Mandatory)]$Rules
    )

    # Map label -> highest priority seen across matching rules.
    $seen = [ordered]@{}

    # Iterate in original rule order so that, given equal priority, the rule
    # author's intent (earlier first) is preserved.
    foreach ($rule in $Rules) {
        $matched = $false
        foreach ($file in $Files) {
            if (Test-PathMatchesGlob -Path $file -Pattern $rule.pattern) {
                $matched = $true
                break
            }
        }
        if (-not $matched) { continue }

        foreach ($label in $rule.labels) {
            if ($seen.Contains($label)) {
                if ($rule.priority -gt $seen[$label].priority) {
                    $seen[$label] = [pscustomobject]@{ priority = $rule.priority; order = $seen[$label].order }
                }
            } else {
                $seen[$label] = [pscustomobject]@{ priority = $rule.priority; order = $seen.Count }
            }
        }
    }

    if ($seen.Count -eq 0) { return @() }

    # Sort by priority desc, then by first-seen order asc for stable output.
    $ordered = $seen.GetEnumerator() |
        Sort-Object -Property `
            @{ Expression = { $_.Value.priority }; Descending = $true }, `
            @{ Expression = { $_.Value.order };    Descending = $false }

    return @($ordered | ForEach-Object { $_.Key })
}

function Read-RuleConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse config JSON at '${Path}': $($_.Exception.Message)"
    }
    if (-not $data.rules) {
        throw "Config at '$Path' must contain a top-level 'rules' array."
    }
    return @($data.rules)
}

function Read-ChangedFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Changed-files list not found: $Path"
    }
    return Get-Content -LiteralPath $Path |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }
}

# --- Main ---------------------------------------------------------------

if ($PSCmdlet.ParameterSetName -eq 'Run') {
    $rules = Read-RuleConfig -Path $ConfigPath
    $files = Read-ChangedFiles -Path $FilesPath

    if (-not $files -or $files.Count -eq 0) {
        Write-Verbose 'No changed files; emitting empty label set.'
    }

    $labels = Get-LabelsForFiles -Files @($files) -Rules $rules

    switch ($Format) {
        'csv'   { ($labels -join ',') }
        'json'  { (@{ labels = @($labels); count = @($labels).Count } | ConvertTo-Json -Compress) }
        'lines' { $labels | ForEach-Object { $_ } }
    }

    if ($GitHubOutput) {
        $csv = ($labels -join ',')
        Add-Content -LiteralPath $GitHubOutput -Value "labels=$csv"
        Add-Content -LiteralPath $GitHubOutput -Value "count=$(@($labels).Count)"
    }
}
