# PR Label Assigner - assigns labels to PRs based on changed file paths and configurable rules

function Convert-GlobToRegex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $Pattern = $Pattern -replace '\\', '/'
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')

    $i = 0
    while ($i -lt $Pattern.Length) {
        $c = $Pattern[$i]
        if ($c -eq '*') {
            if (($i + 1) -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
                if (($i + 2) -lt $Pattern.Length -and $Pattern[$i + 2] -eq '/') {
                    # **/ matches zero or more directory segments
                    [void]$sb.Append('(.+/)?')
                    $i += 3
                } else {
                    # ** at end matches everything
                    [void]$sb.Append('.*')
                    $i += 2
                }
            } else {
                # * matches anything except path separator
                [void]$sb.Append('[^/]*')
                $i += 1
            }
        } elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
            $i += 1
        } else {
            [void]$sb.Append([regex]::Escape($c.ToString()))
            $i += 1
        }
    }

    [void]$sb.Append('$')
    return $sb.ToString()
}

function Get-PRLabels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Rules
    )

    if ($null -eq $ChangedFiles -or $ChangedFiles.Count -eq 0) {
        return
    }

    if ($null -eq $Rules -or $Rules.Count -eq 0) {
        throw "Rules collection must not be empty"
    }

    foreach ($rule in $Rules) {
        if (-not $rule.Pattern) {
            throw "Each rule must have a Pattern property"
        }
        if (-not $rule.Label) {
            throw "Each rule must have a Label property"
        }
        if ($null -eq $rule.Priority) {
            throw "Each rule must have a Priority property"
        }
    }

    # Sort rules by priority (lower number = higher priority)
    $sortedRules = @($Rules | Sort-Object { [int]$_.Priority })

    $labels = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($file in $ChangedFiles) {
        $normalizedFile = $file -replace '\\', '/'
        $exclusiveGroupWins = @{}

        foreach ($rule in $sortedRules) {
            $regex = Convert-GlobToRegex -Pattern $rule.Pattern
            if ($normalizedFile -match $regex) {
                $group = $rule.ExclusiveGroup
                if ($group) {
                    # Within an exclusive group, only the highest-priority match wins per file
                    if (-not $exclusiveGroupWins.ContainsKey($group)) {
                        $exclusiveGroupWins[$group] = $rule.Label
                        [void]$labels.Add($rule.Label)
                    }
                } else {
                    [void]$labels.Add($rule.Label)
                }
            }
        }
    }

    return @($labels | Sort-Object)
}

function Import-LabelRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Rules file not found: $Path"
    }

    $config = Get-Content $Path -Raw | ConvertFrom-Json

    if (-not $config.rules) {
        throw "Rules file must contain a 'rules' array"
    }

    return @($config.rules)
}
