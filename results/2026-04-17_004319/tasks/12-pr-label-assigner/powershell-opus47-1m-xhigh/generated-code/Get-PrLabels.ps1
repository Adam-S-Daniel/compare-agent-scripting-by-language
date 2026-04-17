<#
.SYNOPSIS
    Assigns labels to a PR based on a list of changed file paths and a set of
    glob-pattern -> label rules.

.DESCRIPTION
    Reads a list of changed files (one per line) and a JSON config of rules,
    then emits the deduplicated set of labels that apply.

    Each rule has:
        pattern  : glob (supports *, **, ?), gitignore-style basename match
                   when no '/' is present
        labels   : one or more label names to attach when the pattern matches
        priority : optional integer; higher priorities sort earlier in output.
                   When the same label is emitted by multiple rules, the
                   maximum priority across those rules is used.

    The script can be dot-sourced (so the inner functions are reusable in
    Pester tests) or invoked directly from the CLI / a workflow step.

.EXAMPLE
    pwsh -File ./Get-PrLabels.ps1 -ChangedFilesPath files.txt -ConfigPath labels.json

    Outputs one label per line on stdout.
#>

[CmdletBinding()]
param(
    [string]$ChangedFilesPath,
    [string]$ConfigPath
)

# ----------------------------------------------------------------------------
# Test-GlobMatch : glob-to-regex matcher.
# ----------------------------------------------------------------------------
# We deliberately roll our own matcher rather than using PowerShell's -like
# operator because -like has no notion of '**' (cross-directory wildcard) and
# treats '*' as crossing path separators, which is incompatible with the
# common gitignore / GitHub-actions semantics this tool is mimicking.
#
# Semantics:
#   *   - any chars except '/'
#   **  - any chars (including '/'). When followed by '/', the slash is
#         consumed so 'docs/**/*.md' also matches 'docs/foo.md' (zero dirs).
#   ?   - any single char except '/'
#   If the pattern contains no '/', it is treated as a basename match (i.e.
#   internally prefixed with '**/') so '*.test.*' matches at any depth.
function Test-GlobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )

    # Basename-style: no slash in pattern means "match anywhere".
    $effectivePattern = if ($Pattern -notmatch '/') { "**/$Pattern" } else { $Pattern }

    # Hand-build a regex from the pattern. Doing it character-by-character is
    # the most defensible way to handle '**' vs '*' without false positives.
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $effectivePattern.Length) {
        $c = $effectivePattern[$i]
        if ($c -eq '*' -and ($i + 1) -lt $effectivePattern.Length -and $effectivePattern[$i + 1] -eq '*') {
            # '**' - greedy any, including '/'
            [void]$sb.Append('.*')
            $i += 2
            # Consume an optional trailing '/' so 'a/**/b' matches 'a/b'.
            if ($i -lt $effectivePattern.Length -and $effectivePattern[$i] -eq '/') {
                $i++
            }
        } elseif ($c -eq '*') {
            [void]$sb.Append('[^/]*')
            $i++
        } elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
            $i++
        } elseif ('.\+()[]{}|^$'.Contains([string]$c)) {
            # Escape regex metacharacters so they are matched literally.
            [void]$sb.Append('\').Append($c)
            $i++
        } else {
            [void]$sb.Append($c)
            $i++
        }
    }
    [void]$sb.Append('$')

    return [bool]([regex]::IsMatch($Path, $sb.ToString()))
}

# ----------------------------------------------------------------------------
# Read-LabelConfig : load and validate a JSON config file.
# ----------------------------------------------------------------------------
function Read-LabelConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON config '$Path': $($_.Exception.Message)"
    }

    if (-not $parsed.PSObject.Properties['rules']) {
        throw "Config file '$Path' must contain a 'rules' array."
    }

    # Normalize: every rule must have pattern + labels; priority defaults to 0.
    $rules = @()
    foreach ($r in $parsed.rules) {
        if (-not $r.PSObject.Properties['pattern']) {
            throw "Rule is missing required field 'pattern' in $Path"
        }
        if (-not $r.PSObject.Properties['labels']) {
            throw "Rule '$($r.pattern)' is missing required field 'labels' in $Path"
        }
        $priority = if ($r.PSObject.Properties['priority']) { [int]$r.priority } else { 0 }
        $rules += [pscustomobject]@{
            pattern  = [string]$r.pattern
            labels   = @($r.labels)
            priority = $priority
        }
    }
    return ,$rules  # comma-prefix preserves the array shape on return
}

# ----------------------------------------------------------------------------
# Read-ChangedFiles : load file paths, one per line, ignoring blank lines.
# ----------------------------------------------------------------------------
function Read-ChangedFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Changed-files list not found: $Path"
    }
    $lines = Get-Content -LiteralPath $Path -ErrorAction Stop
    return @($lines | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

# ----------------------------------------------------------------------------
# Get-PrLabels : core resolver.
# ----------------------------------------------------------------------------
# For each (file, rule) pair where the pattern matches, every label on the
# rule is recorded with the rule's priority. When the same label is emitted
# by multiple rules we keep the MAX priority - that lets a high-priority rule
# override the ordering implied by a lower-priority rule emitting the same
# label. Output is sorted by priority descending, then by label name ascending
# for determinism.
function Get-PrLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rules
    )

    $labelPriority = @{}  # label name -> highest priority observed

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.pattern) {
                $p = if ($rule.PSObject.Properties['priority']) { [int]$rule.priority } else { 0 }
                foreach ($lbl in @($rule.labels)) {
                    if (-not $labelPriority.ContainsKey($lbl) -or $labelPriority[$lbl] -lt $p) {
                        $labelPriority[$lbl] = $p
                    }
                }
            }
        }
    }

    # Sort by priority desc, then label name asc, and project to plain strings.
    $sorted = $labelPriority.GetEnumerator() |
        Sort-Object -Property @{Expression = 'Value'; Descending = $true}, @{Expression = 'Key'; Descending = $false} |
        ForEach-Object { $_.Key }

    return @($sorted)
}

# ----------------------------------------------------------------------------
# CLI entry point: only runs when this file is executed directly with the
# required parameters (i.e. NOT when it is dot-sourced from a Pester test).
# ----------------------------------------------------------------------------
if ($PSBoundParameters.ContainsKey('ChangedFilesPath') -and $PSBoundParameters.ContainsKey('ConfigPath')) {
    try {
        $rules = Read-LabelConfig -Path $ConfigPath
        $files = Read-ChangedFiles -Path $ChangedFilesPath
        $labels = Get-PrLabels -ChangedFiles $files -Rules $rules
        # Emit one label per line so downstream tools can parse easily.
        foreach ($l in $labels) { [Console]::Out.WriteLine($l) }
        exit 0
    } catch {
        [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
        exit 1
    }
}
