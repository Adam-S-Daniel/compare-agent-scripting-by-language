Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Environment Matrix Generator for GitHub Actions strategy.matrix
# Generates cartesian product of configuration dimensions, applies include/exclude
# rules, enforces size limits, and outputs valid GitHub Actions matrix JSON.

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix from a configuration hashtable.
    .DESCRIPTION
        Takes a configuration with dimension arrays (os, version, etc.), optional
        include/exclude rules, max-parallel, and fail-fast settings. Produces the
        cartesian product of all dimensions, applies filtering, and validates size.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # Hashtable with dimension arrays (e.g., os, version) and optional
        # 'include', 'exclude', 'max-parallel', 'fail-fast', 'max-combinations' keys.
        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        # Maximum allowed combinations before erroring out (default 256, GitHub's limit).
        [int]$MaxCombinations = 256
    )

    # Separate control keys from dimension keys
    [string[]]$controlKeys = @('include', 'exclude', 'max-parallel', 'fail-fast', 'max-combinations')
    [hashtable]$dimensions = @{}
    foreach ($key in $Configuration.Keys) {
        if ($key -notin $controlKeys) {
            $dimensions[$key] = @($Configuration[$key])
        }
    }

    # Allow config to override max-combinations
    if ($Configuration.ContainsKey('max-combinations')) {
        $MaxCombinations = [int]$Configuration['max-combinations']
    }

    # Build cartesian product of all dimensions
    [array]$combinations = Get-CartesianProduct -Dimensions $dimensions

    # Apply exclude rules — remove matching combinations
    if ($Configuration.ContainsKey('exclude')) {
        [array]$excludeRules = @($Configuration['exclude'])
        $combinations = Remove-ExcludedCombinations -Combinations $combinations -ExcludeRules $excludeRules
    }

    # Apply include rules — add extra combinations (or augment existing ones)
    if ($Configuration.ContainsKey('include')) {
        [array]$includeRules = @($Configuration['include'])
        $combinations = Add-IncludedCombinations -Combinations $combinations -IncludeRules $includeRules -DimensionKeys ([string[]]$dimensions.Keys)
    }

    # Validate matrix size
    if ($combinations.Count -gt $MaxCombinations) {
        throw "Matrix size $($combinations.Count) exceeds maximum of $MaxCombinations combinations."
    }

    # Build the result
    [hashtable]$result = @{
        matrix = @{
            include = [array]$combinations
        }
    }

    # Apply fail-fast setting (default true per GitHub Actions)
    if ($Configuration.ContainsKey('fail-fast')) {
        $result['fail-fast'] = [bool]$Configuration['fail-fast']
    }

    # Apply max-parallel setting
    if ($Configuration.ContainsKey('max-parallel')) {
        $result['max-parallel'] = [int]$Configuration['max-parallel']
    }

    return $result
}

function Get-CartesianProduct {
    <#
    .SYNOPSIS
        Computes the cartesian product of dimension arrays.
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Dimensions
    )

    [string[]]$keys = @($Dimensions.Keys | Sort-Object)

    if ($keys.Count -eq 0) {
        return @(@{})
    }

    # Start with the first dimension, then fold in each subsequent one
    [array]$result = @()
    [string]$firstKey = $keys[0]
    foreach ($val in $Dimensions[$firstKey]) {
        $result += @(@{ $firstKey = $val })
    }

    for ([int]$i = 1; $i -lt $keys.Count; $i++) {
        [string]$currentKey = $keys[$i]
        [array]$newResult = @()
        foreach ($existing in $result) {
            foreach ($val in $Dimensions[$currentKey]) {
                [hashtable]$combo = @{}
                foreach ($k in $existing.Keys) {
                    $combo[$k] = $existing[$k]
                }
                $combo[$currentKey] = $val
                $newResult += @(, $combo)
            }
        }
        $result = $newResult
    }

    return $result
}

function Remove-ExcludedCombinations {
    <#
    .SYNOPSIS
        Removes combinations that match any exclude rule.
    .DESCRIPTION
        A combination matches an exclude rule if all key-value pairs in the rule
        are present in the combination (partial match).
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [array]$Combinations,

        [Parameter(Mandatory)]
        [array]$ExcludeRules
    )

    [array]$filtered = @()
    foreach ($combo in $Combinations) {
        [bool]$excluded = $false
        foreach ($rule in $ExcludeRules) {
            if (Test-CombinationMatchesRule -Combination $combo -Rule $rule) {
                $excluded = $true
                break
            }
        }
        if (-not $excluded) {
            $filtered += @(, $combo)
        }
    }

    return $filtered
}

function Test-CombinationMatchesRule {
    <#
    .SYNOPSIS
        Checks if a combination matches all key-value pairs in a rule.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Combination,

        [Parameter(Mandatory)]
        [hashtable]$Rule
    )

    foreach ($key in $Rule.Keys) {
        if (-not $Combination.ContainsKey($key)) {
            return $false
        }
        if ([string]$Combination[$key] -ne [string]$Rule[$key]) {
            return $false
        }
    }
    return $true
}

function Add-IncludedCombinations {
    <#
    .SYNOPSIS
        Processes include rules per GitHub Actions semantics.
    .DESCRIPTION
        If an include entry matches an existing combination on all dimension keys,
        it augments that combination with extra properties. Otherwise, it is appended
        as a new combination.
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory)]
        [array]$Combinations,

        [Parameter(Mandatory)]
        [array]$IncludeRules,

        [Parameter(Mandatory)]
        [string[]]$DimensionKeys
    )

    foreach ($rule in $IncludeRules) {
        # Check if this rule matches an existing combo on all dimension keys present in the rule
        [bool]$matched = $false
        for ([int]$i = 0; $i -lt $Combinations.Count; $i++) {
            [bool]$dimensionMatch = $true
            foreach ($dk in $DimensionKeys) {
                if ($rule.ContainsKey($dk)) {
                    if (-not $Combinations[$i].ContainsKey($dk) -or
                        [string]$Combinations[$i][$dk] -ne [string]$rule[$dk]) {
                        $dimensionMatch = $false
                        break
                    }
                }
            }
            if ($dimensionMatch -and ($rule.Keys | Where-Object { $_ -in $DimensionKeys }).Count -gt 0) {
                # Augment the existing combination with extra keys from the rule
                foreach ($key in $rule.Keys) {
                    $Combinations[$i][$key] = $rule[$key]
                }
                $matched = $true
            }
        }
        if (-not $matched) {
            # Append as a new combination
            [hashtable]$newCombo = @{}
            foreach ($key in $rule.Keys) {
                $newCombo[$key] = $rule[$key]
            }
            $Combinations += @(, $newCombo)
        }
    }

    return $Combinations
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
        Converts the matrix result to JSON suitable for GitHub Actions.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$MatrixResult
    )

    return ($MatrixResult | ConvertTo-Json -Depth 10 -Compress)
}
