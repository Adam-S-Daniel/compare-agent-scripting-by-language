<#
.SYNOPSIS
    PR Label Assigner – applies labels to a PR based on changed file paths.
.DESCRIPTION
    Reads a list of changed file paths and a set of label-mapping rules.
    Each rule has a glob pattern, a label name, and a priority number (lower = higher priority).
    Supports glob wildcards: * (non-separator chars), ** (any chars incl. /), ? (single char).
    Multiple labels may be assigned per PR; priority determines output ordering.
.PARAMETER Files
    Array of changed file paths to evaluate.
.PARAMETER RulesFile
    Path to a JSON file containing the label rules. Defaults to fixtures/rules.json.
.EXAMPLE
    .\Invoke-PrLabelAssigner.ps1 -Files @("docs/README.md","src/api/routes.js")
#>
param(
    [string[]]$Files,
    [string]$RulesFile = "$PSScriptRoot/fixtures/rules.json"
)

# ── Glob helpers ─────────────────────────────────────────────────────────────

# Convert a glob pattern string into a .NET regular expression string.
# Supports:  **/ (any path prefix)   /**  (any path under dir)
#            **  (any chars)          *   (non-separator chars)   ?  (single non-separator char)
function ConvertTo-GlobRegex {
    param([string]$Glob)

    # Normalize directory separators to forward-slash
    $p = $Glob -replace '\\', '/'

    # Escape all regex metacharacters except * and ? (those are our wildcards).
    # Note: / is not a regex metachar and does not need escaping.
    $p = $p -replace '([.+^${}()\[\]|])', '\$1'

    # Replace ** sequences before single *, using placeholders to avoid
    # double-replacement when the same segment contains multiple wildcards.
    # Order matters: "**/" must come before lone "**" which must come before "*".
    $p = $p -replace '\*\*/',  '§PFX§'   # any optional path prefix
    $p = $p -replace '/\*\*',  '§SFX§'   # any path under a directory
    $p = $p -replace '\*\*',   '§ANY§'   # bare ** (matches anything incl. /)

    # Single wildcards (after ** placeholders are removed)
    $p = $p -replace '\*', '[^/]*'        # any chars except /
    $p = $p -replace '\?', '[^/]'         # one char except /

    # Expand placeholders
    $p = $p -replace '§PFX§', '(?:.+/)?'  # zero or more path segments + /
    $p = $p -replace '§SFX§', '/.*'       # / then anything
    $p = $p -replace '§ANY§', '.*'        # anything

    return "^$p$"
}

# Return $true if $Path matches the glob $Glob (case-sensitive, / normalised).
function Test-GlobMatch {
    param(
        [string]$Path,
        [string]$Glob
    )

    $normalised = $Path -replace '\\', '/'
    $regex      = ConvertTo-GlobRegex -Glob $Glob
    return $normalised -match $regex
}

# ── Core label logic ─────────────────────────────────────────────────────────

# Given a list of changed file paths and an array of rule objects
# ({pattern, label, priority}), return the sorted set of matching labels.
# Labels are sorted by the highest-priority (lowest numeric value) rule that
# triggered them, with alphabetical ordering as a tiebreaker.
function Get-PrLabels {
    param(
        [string[]]$Files,
        [object[]]$Rules
    )

    if (-not $Files -or $Files.Count -eq 0) {
        return @()
    }
    if (-not $Rules -or $Rules.Count -eq 0) {
        return @()
    }

    # Map: label -> best priority seen so far (lowest number = highest priority)
    $matched = @{}

    foreach ($file in $Files) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Glob $rule.pattern) {
                $label    = [string]$rule.label
                $priority = [int]$rule.priority

                if (-not $matched.ContainsKey($label) -or $priority -lt $matched[$label]) {
                    $matched[$label] = $priority
                }
            }
        }
    }

    # Sort ascending by priority value, then alphabetically within the same priority
    return @(
        $matched.GetEnumerator() |
        Sort-Object @{ Expression = { $_.Value }; Ascending = $true },
                    @{ Expression = { $_.Key };   Ascending = $true } |
        Select-Object -ExpandProperty Key
    )
}

# ── Entry point (run directly, not dot-sourced) ───────────────────────────────
if ($Files -and $Files.Count -gt 0) {
    if (-not (Test-Path $RulesFile)) {
        Write-Error "Rules file not found: $RulesFile"
        exit 1
    }

    $rules  = Get-Content $RulesFile -Raw | ConvertFrom-Json
    $labels = Get-PrLabels -Files $Files -Rules $rules

    if ($labels.Count -eq 0) {
        Write-Output "No labels matched."
    } else {
        Write-Output "Assigned labels:"
        $labels | ForEach-Object { Write-Output "  - $_" }
    }
}
