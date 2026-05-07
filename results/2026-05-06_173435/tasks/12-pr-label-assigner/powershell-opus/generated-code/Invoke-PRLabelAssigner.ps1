# PR Label Assigner - assigns labels based on path-to-label mapping rules with glob support

function ConvertTo-LikePattern {
    param([string]$GlobPattern)
    # PowerShell's -like treats * as crossing path separators, so ** collapses to *
    $GlobPattern -replace '\*\*/', '*' -replace '\*\*', '*'
}

function Get-PRLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable[]]$Rules
    )

    if ($ChangedFiles.Count -eq 0) { return }

    foreach ($rule in $Rules) {
        if (-not $rule.ContainsKey('Pattern') -or -not $rule.ContainsKey('Label')) {
            throw "Each rule must have 'Pattern' and 'Label' keys"
        }
        if (-not $rule.ContainsKey('Priority')) {
            $rule['Priority'] = 0
        }
    }

    $sortedRules = $Rules | Sort-Object { [int]$_.Priority } -Descending
    $emitted = [System.Collections.Generic.List[string]]::new()

    foreach ($rule in $sortedRules) {
        $likePattern = ConvertTo-LikePattern -GlobPattern $rule.Pattern
        foreach ($file in $ChangedFiles) {
            if ($file -like $likePattern) {
                if ($rule.Label -notin $emitted) {
                    $emitted.Add($rule.Label)
                    $rule.Label
                }
                break
            }
        }
    }
}

function Invoke-PRLabelAssigner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [string[]]$ChangedFiles
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    if (-not $config.rules -or $config.rules.Count -eq 0) {
        throw "Config must contain a non-empty 'rules' array"
    }

    $rules = @()
    foreach ($r in $config.rules) {
        $rules += @{
            Pattern  = $r.pattern
            Label    = $r.label
            Priority = if ($null -ne $r.priority) { [int]$r.priority } else { 0 }
        }
    }

    Get-PRLabels -ChangedFiles $ChangedFiles -Rules $rules
}
