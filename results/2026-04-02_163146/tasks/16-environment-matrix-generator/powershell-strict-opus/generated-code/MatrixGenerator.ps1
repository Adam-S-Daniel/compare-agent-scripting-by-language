Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# MatrixGenerator.ps1
#
# Generates a GitHub Actions strategy.matrix JSON from a configuration
# describing OS options, language versions, feature flags, include/exclude
# rules, max-parallel limits, and fail-fast settings.
#
# Built using TDD — each function corresponds to tests in MatrixGenerator.Tests.ps1
# =============================================================================

function Get-CartesianProduct {
    <#
    .SYNOPSIS
        Computes the cartesian product of multiple named dimension arrays.
    .DESCRIPTION
        Given a hashtable where keys are dimension names and values are arrays,
        returns an ArrayList of hashtables representing every combination.
        Uses comma operator to prevent pipeline unwrapping.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Dimensions
    )

    # Start with a single empty combination
    [System.Collections.ArrayList]$combinations = [System.Collections.ArrayList]::new()
    [void]$combinations.Add(@{})

    # For each dimension, expand the existing combinations
    foreach ($dimName in $Dimensions.Keys) {
        [array]$dimValues = @($Dimensions[$dimName])
        [System.Collections.ArrayList]$newCombinations = [System.Collections.ArrayList]::new()

        foreach ($combo in $combinations) {
            foreach ($val in $dimValues) {
                # Clone the existing combination and add the new dimension
                [hashtable]$newCombo = @{}
                foreach ($key in $combo.Keys) {
                    $newCombo[$key] = $combo[$key]
                }
                $newCombo[$dimName] = [string]$val
                [void]$newCombinations.Add($newCombo)
            }
        }

        $combinations = $newCombinations
    }

    # Comma operator prevents PowerShell from unwrapping the collection
    return ,$combinations
}

function Test-CombinationMatchesRule {
    <#
    .SYNOPSIS
        Tests whether a matrix combination matches a rule (include/exclude entry).
    .DESCRIPTION
        A rule matches if every key in the rule exists in the combination and
        the values are equal. Extra keys in the combination are ignored.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Combination,

        [Parameter(Mandatory)]
        [hashtable]$Rule
    )

    foreach ($ruleKey in $Rule.Keys) {
        if (-not $Combination.ContainsKey($ruleKey)) {
            return $false
        }
        if ([string]$Combination[$ruleKey] -ne [string]$Rule[$ruleKey]) {
            return $false
        }
    }

    return $true
}

function Invoke-ExcludeRules {
    <#
    .SYNOPSIS
        Removes combinations that match any exclude rule.
    .DESCRIPTION
        Iterates through the matrix and removes any combination that matches
        at least one exclude rule. Returns a new ArrayList with filtered results.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$Matrix,

        [Parameter(Mandatory)]
        [array]$ExcludeRules
    )

    [System.Collections.ArrayList]$filtered = [System.Collections.ArrayList]::new()

    foreach ($combo in $Matrix) {
        [bool]$excluded = $false

        foreach ($rule in $ExcludeRules) {
            if (Test-CombinationMatchesRule -Combination ([hashtable]$combo) -Rule ([hashtable]$rule)) {
                $excluded = $true
                break
            }
        }

        if (-not $excluded) {
            [void]$filtered.Add($combo)
        }
    }

    # Comma operator prevents PowerShell from unwrapping the collection
    return ,$filtered
}

function Invoke-IncludeRules {
    <#
    .SYNOPSIS
        Applies include rules: augments matching combos or adds new ones.
    .DESCRIPTION
        For each include rule, if it matches an existing combination on all
        base dimension keys, the extra properties are merged into that combo.
        If no existing combination matches, the include is added as a new entry.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.ArrayList]$Matrix,

        [Parameter(Mandatory)]
        [array]$IncludeRules,

        [Parameter(Mandatory)]
        [array]$DimensionKeys
    )

    foreach ($rule in $IncludeRules) {
        [hashtable]$ruleHash = [hashtable]$rule

        # Build a sub-rule containing only the base dimension keys
        [hashtable]$dimSubset = @{}
        foreach ($key in $DimensionKeys) {
            if ($ruleHash.ContainsKey($key)) {
                $dimSubset[$key] = $ruleHash[$key]
            }
        }

        # Find matching existing combinations
        [bool]$matchFound = $false
        if ($dimSubset.Count -eq $DimensionKeys.Count) {
            # The include specifies all dimension keys — check for exact match
            foreach ($combo in $Matrix) {
                if (Test-CombinationMatchesRule -Combination ([hashtable]$combo) -Rule $dimSubset) {
                    # Merge extra properties into the existing combination
                    foreach ($key in $ruleHash.Keys) {
                        $combo[$key] = [string]$ruleHash[$key]
                    }
                    $matchFound = $true
                }
            }
        }

        if (-not $matchFound) {
            # No match — add as a new combination
            [hashtable]$newCombo = @{}
            foreach ($key in $ruleHash.Keys) {
                $newCombo[$key] = [string]$ruleHash[$key]
            }
            [void]$Matrix.Add($newCombo)
        }
    }

    # Comma operator prevents PowerShell from unwrapping the collection
    return ,$Matrix
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions build matrix from a configuration hashtable.
    .DESCRIPTION
        Takes a config with dimensions, optional include/exclude rules,
        fail-fast, and max-parallel settings. Returns a hashtable with
        the matrix array and strategy settings.

        Validates that the final matrix does not exceed MaxSize (default 256,
        GitHub Actions' limit).
    .PARAMETER Config
        A hashtable with keys: dimensions (required), include, exclude,
        fail-fast, max-parallel.
    .PARAMETER MaxSize
        Maximum number of matrix combinations allowed (default 256).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter()]
        [int]$MaxSize = 256
    )

    # --- Validate config ---
    if (-not $Config.ContainsKey('dimensions')) {
        throw 'Config must contain a "dimensions" key with the matrix dimensions.'
    }

    if ($Config['dimensions'] -isnot [hashtable]) {
        throw 'Config "dimensions" must be a hashtable mapping dimension names to value arrays.'
    }

    [hashtable]$dimensions = [hashtable]$Config['dimensions']

    # Normalize dimensions: wrap scalar values in arrays and validate
    [hashtable]$normalizedDims = @{}
    foreach ($dimName in $dimensions.Keys) {
        $dimValue = $dimensions[$dimName]

        if ($dimValue -is [array]) {
            if ($dimValue.Count -eq 0) {
                throw "Dimension '$dimName' has an empty array of values."
            }
            $normalizedDims[$dimName] = $dimValue
        }
        elseif ($dimValue -is [System.Collections.IEnumerable] -and $dimValue -isnot [string]) {
            [array]$arr = @($dimValue)
            if ($arr.Count -eq 0) {
                throw "Dimension '$dimName' has an empty array of values."
            }
            $normalizedDims[$dimName] = $arr
        }
        else {
            # Scalar value — wrap in a single-element array
            $normalizedDims[$dimName] = @([string]$dimValue)
        }
    }

    # --- Generate cartesian product ---
    [System.Collections.ArrayList]$matrix = Get-CartesianProduct -Dimensions $normalizedDims
    [array]$dimensionKeys = @($normalizedDims.Keys)

    # --- Apply exclude rules (before includes, per GitHub Actions behavior) ---
    if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        [array]$excludeRules = @($Config['exclude'])
        $matrix = Invoke-ExcludeRules -Matrix $matrix -ExcludeRules $excludeRules
    }

    # --- Apply include rules ---
    if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        [array]$includeRules = @($Config['include'])
        $matrix = Invoke-IncludeRules -Matrix $matrix -IncludeRules $includeRules -DimensionKeys $dimensionKeys
    }

    # --- Validate matrix size ---
    if ($matrix.Count -gt $MaxSize) {
        throw "Matrix size ($($matrix.Count)) exceeds maximum allowed size ($MaxSize). Reduce dimensions or add exclude rules."
    }

    # --- Build result hashtable ---
    [hashtable]$result = @{
        'matrix'    = [array]$matrix
        'fail-fast' = $true
    }

    # Override fail-fast if explicitly set
    if ($Config.ContainsKey('fail-fast')) {
        $result['fail-fast'] = [bool]$Config['fail-fast']
    }

    # Set max-parallel only if specified
    if ($Config.ContainsKey('max-parallel') -and $null -ne $Config['max-parallel']) {
        $result['max-parallel'] = [int]$Config['max-parallel']
    }

    return $result
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
        Converts a matrix result hashtable to JSON suitable for GitHub Actions.
    .DESCRIPTION
        Takes the output of New-BuildMatrix and produces a JSON string with
        the strategy.matrix structure.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Matrix
    )

    # Build an ordered structure for clean JSON output
    $output = [ordered]@{}

    if ($Matrix.ContainsKey('fail-fast')) {
        $output['fail-fast'] = $Matrix['fail-fast']
    }

    if ($Matrix.ContainsKey('max-parallel')) {
        $output['max-parallel'] = $Matrix['max-parallel']
    }

    # Convert matrix entries from hashtables to ordered dictionaries for consistent output
    [System.Collections.ArrayList]$matrixEntries = [System.Collections.ArrayList]::new()
    foreach ($entry in $Matrix['matrix']) {
        $ordered = [ordered]@{}
        foreach ($key in ($entry.Keys | Sort-Object)) {
            $ordered[$key] = $entry[$key]
        }
        [void]$matrixEntries.Add($ordered)
    }

    $output['matrix'] = [array]$matrixEntries

    [string]$json = $output | ConvertTo-Json -Depth 10 -Compress:$false
    return $json
}

# =============================================================================
# Main entry point — when run directly (not dot-sourced for tests)
# =============================================================================
if ($MyInvocation.InvocationName -ne '.') {
    # Example usage: generates a matrix from a sample config and outputs JSON
    $exampleConfig = @{
        dimensions = @{
            os       = @('ubuntu-latest', 'windows-latest', 'macos-latest')
            language = @('3.9', '3.10', '3.11')
            feature  = @('enabled', 'disabled')
        }
        exclude = @(
            @{ os = 'macos-latest'; language = '3.9' }
        )
        include = @(
            @{ os = 'ubuntu-latest'; language = '3.12'; feature = 'beta' }
        )
        'fail-fast' = $false
        'max-parallel' = 4
    }

    try {
        [hashtable]$matrixResult = New-BuildMatrix -Config $exampleConfig
        [string]$json = ConvertTo-MatrixJson -Matrix $matrixResult
        Write-Output $json
    }
    catch {
        Write-Error "Error generating matrix: $_"
        exit 1
    }
}
