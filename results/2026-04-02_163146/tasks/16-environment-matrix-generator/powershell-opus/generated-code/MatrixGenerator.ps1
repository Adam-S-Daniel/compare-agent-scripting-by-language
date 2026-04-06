# MatrixGenerator.ps1
# Generates GitHub Actions strategy.matrix JSON from a configuration.
#
# Approach:
#   1. Accept a config hashtable with matrix dimensions, include/exclude rules,
#      max-parallel, fail-fast, and max-size settings.
#   2. Compute the cartesian product of all matrix dimensions.
#   3. Apply exclude rules to remove unwanted combinations.
#   4. Merge in include rules (additional combinations).
#   5. Validate the resulting matrix size against a configurable maximum (GitHub default: 256).
#   6. Return a hashtable matching the GitHub Actions strategy schema.

function Get-CartesianProduct {
    <#
    .SYNOPSIS
        Computes the cartesian product of multiple arrays.
    .DESCRIPTION
        Given an ordered list of dimension names and a hashtable mapping each
        name to an array of values, returns an array of hashtables representing
        every combination.
    #>
    param(
        [string[]]$DimensionNames,
        [hashtable]$Dimensions
    )

    if ($DimensionNames.Count -eq 0) {
        return @(@{})
    }

    # Start with a single empty combination
    $combinations = @(@{})

    foreach ($dimName in $DimensionNames) {
        $values = $Dimensions[$dimName]
        $newCombinations = @()

        foreach ($combo in $combinations) {
            foreach ($val in $values) {
                # Clone the existing combination and add the new dimension
                $newCombo = @{}
                foreach ($key in $combo.Keys) {
                    $newCombo[$key] = $combo[$key]
                }
                $newCombo[$dimName] = $val
                $newCombinations += $newCombo
            }
        }
        $combinations = $newCombinations
    }

    # Return the array — caller should wrap in @() to preserve array type
    return $combinations
}

function Test-CombinationMatchesRule {
    <#
    .SYNOPSIS
        Checks if a matrix combination matches an include/exclude rule.
    .DESCRIPTION
        A rule matches a combination if every key in the rule exists in the
        combination with the same value.
    #>
    param(
        [hashtable]$Combination,
        [hashtable]$Rule
    )

    foreach ($key in $Rule.Keys) {
        if (-not $Combination.ContainsKey($key)) { return $false }
        if ($Combination[$key] -ne $Rule[$key]) { return $false }
    }
    return $true
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix configuration.
    .DESCRIPTION
        Accepts a configuration hashtable and produces the complete matrix
        JSON structure with all combinations, include/exclude rules applied,
        and strategy settings (max-parallel, fail-fast).
    .PARAMETER Config
        A hashtable with the following optional keys:
          - matrix: hashtable of dimension name -> array of values
          - include: array of hashtables for additional combinations
          - exclude: array of hashtables for combinations to remove
          - max_parallel: integer limiting concurrent jobs
          - fail_fast: boolean to stop all jobs on first failure
          - max_size: integer maximum number of matrix combinations (default 256)
    .OUTPUTS
        A hashtable representing the full GitHub Actions strategy object.
    #>
    param(
        [hashtable]$Config
    )

    # --- Validate input ---
    if (-not $Config) {
        throw "Config parameter is required."
    }
    if (-not $Config.ContainsKey('matrix') -or $null -eq $Config['matrix']) {
        throw "Config must contain a 'matrix' key with dimension definitions."
    }

    $matrixDef = $Config['matrix']
    if ($matrixDef -isnot [hashtable]) {
        throw "The 'matrix' value must be a hashtable of dimension names to value arrays."
    }

    # Validate each dimension has at least one value
    foreach ($key in $matrixDef.Keys) {
        $vals = $matrixDef[$key]
        if ($null -eq $vals -or ($vals -is [array] -and $vals.Count -eq 0)) {
            throw "Matrix dimension '$key' must have at least one value."
        }
    }

    # --- Build the cartesian product ---
    # Sort dimension names for deterministic ordering
    $dimNames = @($matrixDef.Keys | Sort-Object)
    $combinations = @(Get-CartesianProduct -DimensionNames $dimNames -Dimensions $matrixDef)

    # --- Apply exclude rules ---
    $excludeRules = @()
    if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        $excludeRules = @($Config['exclude'])
        if ($excludeRules.Count -gt 0) {
            $filtered = @()
            foreach ($combo in $combinations) {
                $excluded = $false
                foreach ($rule in $excludeRules) {
                    if (Test-CombinationMatchesRule -Combination $combo -Rule $rule) {
                        $excluded = $true
                        break
                    }
                }
                if (-not $excluded) {
                    $filtered += $combo
                }
            }
            $combinations = @($filtered)
        }
    }

    # --- Apply include rules ---
    # Include rules add extra combinations to the matrix.
    # If an include entry matches an existing combination on all its keys,
    # any additional keys in the include are merged into that combination.
    # If no existing combination matches, the include entry is added as a new row.
    if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        $includeRules = @($Config['include'])
        foreach ($rule in $includeRules) {
            # Check if this include rule matches any existing combination
            # An include matches if all keys that overlap with dimension names have matching values
            $matched = $false
            $overlapKeys = @($rule.Keys | Where-Object { $dimNames -contains $_ })

            if ($overlapKeys.Count -gt 0) {
                # Build a sub-rule with just the overlapping keys
                $overlapRule = @{}
                foreach ($k in $overlapKeys) {
                    $overlapRule[$k] = $rule[$k]
                }

                for ($i = 0; $i -lt $combinations.Count; $i++) {
                    if (Test-CombinationMatchesRule -Combination $combinations[$i] -Rule $overlapRule) {
                        # Merge extra keys from the include rule into the existing combination
                        foreach ($k in $rule.Keys) {
                            $combinations[$i][$k] = $rule[$k]
                        }
                        $matched = $true
                    }
                }
            }

            if (-not $matched) {
                # Add as a brand new combination
                $newCombo = @{}
                foreach ($k in $rule.Keys) {
                    $newCombo[$k] = $rule[$k]
                }
                $combinations += $newCombo
            }
        }
    }

    # --- Validate matrix size ---
    $maxSize = 256  # GitHub Actions default limit
    if ($Config.ContainsKey('max_size') -and $null -ne $Config['max_size']) {
        $maxSize = [int]$Config['max_size']
        if ($maxSize -le 0) {
            throw "max_size must be a positive integer, got: $maxSize"
        }
    }

    if ($combinations.Count -gt $maxSize) {
        throw "Matrix size ($($combinations.Count)) exceeds maximum allowed ($maxSize). Reduce dimensions or add exclude rules."
    }

    # --- Build output structure ---
    # The output mirrors the GitHub Actions strategy schema:
    #   strategy:
    #     fail-fast: bool
    #     max-parallel: int
    #     matrix:
    #       include: [ {combination}, ... ]
    $strategy = @{
        matrix = @{
            include = @($combinations)
        }
    }

    # Add fail-fast if specified
    if ($Config.ContainsKey('fail_fast')) {
        $strategy['fail-fast'] = [bool]$Config['fail_fast']
    }

    # Add max-parallel if specified
    if ($Config.ContainsKey('max_parallel') -and $null -ne $Config['max_parallel']) {
        $maxParallel = [int]$Config['max_parallel']
        if ($maxParallel -le 0) {
            throw "max_parallel must be a positive integer, got: $maxParallel"
        }
        $strategy['max-parallel'] = $maxParallel
    }

    return $strategy
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
        Convenience wrapper: accepts a config hashtable or JSON string and
        returns the matrix as a formatted JSON string.
    #>
    param(
        [Parameter(Mandatory)]
        $ConfigInput
    )

    if ($ConfigInput -is [string]) {
        $Config = $ConfigInput | ConvertFrom-Json -AsHashtable
    } else {
        $Config = $ConfigInput
    }

    $result = New-BuildMatrix -Config $Config
    return ($result | ConvertTo-Json -Depth 10)
}
