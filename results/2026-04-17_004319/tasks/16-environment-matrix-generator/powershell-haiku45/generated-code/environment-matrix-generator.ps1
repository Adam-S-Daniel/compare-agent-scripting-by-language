#Requires -Version 7.0

<#
.SYNOPSIS
Generates a GitHub Actions build matrix from a configuration object.

.DESCRIPTION
Creates a cartesian product of all matrix dimensions, applies include/exclude rules,
validates size constraints, and outputs valid GitHub Actions strategy.matrix JSON.

.PARAMETER Configuration
Hashtable containing:
  - Dimension arrays (e.g., os, language, features)
  - include: array of extra combinations to add
  - exclude: array of combinations to remove
  - max-parallel: max jobs to run concurrently
  - fail-fast: whether to cancel other jobs on failure
  - max-matrix-size: max allowed matrix size (default: 256)

.EXAMPLE
$config = @{
    os = @('ubuntu-latest', 'windows-latest')
    language = @('1.0', '1.1')
}
ConvertTo-GitHubActionsMatrix -Configuration $config | ConvertTo-Json
#>

function ConvertTo-GitHubActionsMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [hashtable]$Configuration
    )

    # Validate configuration has at least one dimension
    $dimensions = @($Configuration.Keys | Where-Object {
        $_ -notin @('include', 'exclude', 'max-parallel', 'fail-fast', 'max-matrix-size')
    })

    if ($dimensions.Count -eq 0) {
        throw "Configuration must include at least one matrix dimension (e.g., 'os', 'language')"
    }

    # Get max matrix size constraint
    $maxMatrixSize = $Configuration['max-matrix-size'] ?? 256

    # Build initial matrix from cartesian product
    $matrixCombinations = @()

    # Get all dimension keys and their values
    $dimensionArrays = @()
    $dimensionKeys = @()

    foreach ($key in $dimensions) {
        $value = $Configuration[$key]

        # Handle both direct arrays and feature hashtables
        if ($value -is [hashtable]) {
            # Features: each key in the hashtable is a separate dimension
            foreach ($featureKey in $value.Keys) {
                $dimensionKeys += $featureKey
                $dimensionArrays += , @($value[$featureKey])
            }
        } else {
            $dimensionKeys += $key
            $dimensionArrays += , @($value)
        }
    }

    # Generate cartesian product
    if ($dimensionArrays.Count -gt 0) {
        $cartesianProduct = Get-CartesianProduct -Arrays $dimensionArrays -Keys $dimensionKeys
        $matrixCombinations = @($cartesianProduct)
    }

    # Check matrix size before include/exclude
    if ($matrixCombinations.Count -gt $maxMatrixSize) {
        throw "Matrix size ($($matrixCombinations.Count)) exceeds maximum allowed ($maxMatrixSize)"
    }

    # Apply exclude rules
    if ($Configuration['exclude']) {
        $matrixCombinations = Remove-ExcludedCombinations -Combinations $matrixCombinations -ExcludeRules $Configuration['exclude']
    }

    # Apply include rules
    if ($Configuration['include']) {
        $matrixCombinations = @($matrixCombinations) + @($Configuration['include'])
    }

    # Final size check
    if ($matrixCombinations.Count -gt $maxMatrixSize) {
        throw "Matrix size ($($matrixCombinations.Count)) exceeds maximum allowed ($maxMatrixSize)"
    }

    # Build result object
    $result = @{
        matrix = @{
            include = $matrixCombinations
        }
    }

    # Add optional settings
    if ($Configuration.ContainsKey('max-parallel')) {
        $result['max-parallel'] = $Configuration['max-parallel']
    }

    if ($Configuration.ContainsKey('fail-fast')) {
        $result['fail-fast'] = $Configuration['fail-fast']
    }

    return $result
}

<#
.SYNOPSIS
Generates cartesian product of arrays
#>
function Get-CartesianProduct {
    param(
        [array]$Arrays,
        [array]$Keys
    )

    if ($Arrays.Count -eq 0) {
        return @()
    }

    # Start with first array
    $product = @()
    foreach ($item in $Arrays[0]) {
        $product += @{ $Keys[0] = $item }
    }

    # Combine with remaining arrays
    for ($i = 1; $i -lt $Arrays.Count; $i++) {
        $newProduct = @()
        foreach ($existing in $product) {
            foreach ($item in $Arrays[$i]) {
                $newItem = $existing.Clone()
                $newItem[$Keys[$i]] = $item
                $newProduct += $newItem
            }
        }
        $product = $newProduct
    }

    return $product
}

<#
.SYNOPSIS
Removes combinations matching exclude rules
#>
function Remove-ExcludedCombinations {
    param(
        [array]$Combinations,
        [array]$ExcludeRules
    )

    return $Combinations | Where-Object {
        $current = $_
        $isExcluded = $false

        foreach ($rule in $ExcludeRules) {
            $ruleMatches = $true
            foreach ($key in $rule.Keys) {
                if (-not $current.ContainsKey($key) -or $current[$key] -ne $rule[$key]) {
                    $ruleMatches = $false
                    break
                }
            }
            if ($ruleMatches) {
                $isExcluded = $true
                break
            }
        }

        return -not $isExcluded
    }
}

