# PR Label Assigner
# Applies labels to a PR based on path-to-label rules with glob support.
# Rules are objects with: Pattern (string), Labels (string[]), Priority (int, optional).
# Lower Priority number = higher priority (sorts first in output).
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$FilesPath,
    [ValidateSet('Lines', 'Json')]
    [string]$OutputFormat = 'Lines'
)

function ConvertTo-GlobRegex {
    param([Parameter(Mandatory)][string]$Glob)

    # Use a placeholder for ** so it survives the single-* replacement.
    $escaped = [regex]::Escape($Glob)
    $escaped = $escaped -replace '\\\*\\\*', '<<DSTAR>>'
    $escaped = $escaped -replace '\\\*', '[^/]*'
    $escaped = $escaped -replace '<<DSTAR>>', '.*'
    $escaped = $escaped -replace '\\\?', '.'
    return "^$escaped$"
}

function Test-GlobMatch {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Pattern
    )
    $regex = ConvertTo-GlobRegex -Glob $Pattern
    return $Path -match $regex
}

function Get-PrLabels {
    <#
    .SYNOPSIS
        Returns the set of labels that apply to a list of changed files.
    .PARAMETER ChangedFiles
        Paths of changed files (forward-slash separated).
    .PARAMETER Rules
        Array of rule objects. Each rule must have Pattern and Labels; Priority is optional (default 100).
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedFiles,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rules
    )

    foreach ($r in $Rules) {
        if (-not $r.Pattern) { throw "Rule missing required 'Pattern' property." }
        if (-not $r.Labels)  { throw "Rule '$($r.Pattern)' missing required 'Labels' property." }
    }

    # Track best (lowest) priority seen for each label so we can order output deterministically.
    $labelPriority = @{}

    foreach ($file in $ChangedFiles) {
        foreach ($rule in $Rules) {
            if (Test-GlobMatch -Path $file -Pattern $rule.Pattern) {
                $prio = if ($null -ne $rule.Priority) { [int]$rule.Priority } else { 100 }
                foreach ($label in $rule.Labels) {
                    if (-not $labelPriority.ContainsKey($label) -or $labelPriority[$label] -gt $prio) {
                        $labelPriority[$label] = $prio
                    }
                }
            }
        }
    }

    return @($labelPriority.GetEnumerator() |
        Sort-Object @{Expression='Value'}, @{Expression='Key'} |
        ForEach-Object { $_.Key })
}

function Read-Rules {
    param([Parameter(Mandatory)][string]$ConfigPath)
    if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Config file not found: $ConfigPath" }
    try {
        return @((Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop))
    } catch {
        throw "Failed to parse config '$ConfigPath': $_"
    }
}

function Read-ChangedFiles {
    param([Parameter(Mandatory)][string]$FilesPath)
    if (-not (Test-Path -LiteralPath $FilesPath)) { throw "Changed files list not found: $FilesPath" }
    return @(Get-Content -LiteralPath $FilesPath |
        Where-Object { $_ -and $_.Trim() -ne '' } |
        ForEach-Object { $_.Trim() })
}

# CLI entrypoint: only when invoked as a script (not dot-sourced).
if ($MyInvocation.InvocationName -ne '.' -and $ConfigPath -and $FilesPath) {
    $rules = Read-Rules -ConfigPath $ConfigPath
    $files = Read-ChangedFiles -FilesPath $FilesPath
    $labels = Get-PrLabels -ChangedFiles $files -Rules $rules

    if ($OutputFormat -eq 'Json') {
        Write-Output (ConvertTo-Json -InputObject $labels -Compress)
    } else {
        foreach ($l in $labels) { Write-Output $l }
    }
}
