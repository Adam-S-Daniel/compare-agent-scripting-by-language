# Environment Matrix Generator for GitHub Actions
# Generates build matrices from configuration with support for include/exclude rules

function New-EnvironmentMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions matrix from a configuration object
    .PARAMETER Config
        Hashtable containing matrix dimensions and configuration options
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    # Validate that we have at least one dimension
    $dimensions = @($Config.Keys | Where-Object { $_ -notin @('include', 'exclude', 'maxParallel', 'failFast', 'maxSize') })

    if ($dimensions.Count -eq 0) {
        throw "Configuration must contain at least one matrix dimension (e.g., 'os', 'language')"
    }

    # Ensure all dimension arrays are non-empty
    foreach ($dim in $dimensions) {
        $values = $Config[$dim]
        if ($null -eq $values -or $values.Count -eq 0) {
            throw "Dimension '$dim' cannot be empty"
        }
    }

    # Generate cartesian product of all dimensions
    $baseMatrix = Get-CartesianProduct -Dimensions $Config -DimensionNames $dimensions

    # Apply exclude rules if specified
    if ($Config.exclude) {
        $baseMatrix = Remove-ExcludedCombinations -Matrix $baseMatrix -ExcludeRules $Config.exclude
    }

    # Build the final matrix object, with includes first
    $matrixInclude = @()

    if ($Config.include) {
        $matrixInclude += @($Config.include)
    }

    $matrixInclude += @($baseMatrix)

    $matrix = @{
        include = $matrixInclude
    }

    # Add max-parallel if specified
    if ($Config.maxParallel) {
        $matrix.'max-parallel' = $Config.maxParallel
    }

    # Add fail-fast if specified
    if ($null -ne $Config.failFast) {
        $matrix.'fail-fast' = $Config.failFast
    }

    # Validate matrix size
    $maxSize = if ($Config.maxSize) { $Config.maxSize } else { 256 }
    if ($matrix.include.Count -gt $maxSize) {
        throw "Matrix size ($($matrix.include.Count)) exceeds maximum allowed size ($maxSize)"
    }

    return $matrix
}

function Get-CartesianProduct {
    <#
    .SYNOPSIS
        Generates cartesian product of matrix dimensions
    #>
    param(
        [hashtable]$Dimensions,
        [string[]]$DimensionNames
    )

    # Start with first dimension
    $result = @()
    $firstDim = $DimensionNames[0]

    foreach ($value in $Dimensions[$firstDim]) {
        $result += @{ $firstDim = $value }
    }

    # Iterate through remaining dimensions
    for ($i = 1; $i -lt $DimensionNames.Count; $i++) {
        $dimName = $DimensionNames[$i]
        $dimValues = $Dimensions[$dimName]
        $newResult = @()

        foreach ($combo in $result) {
            foreach ($value in $dimValues) {
                $newCombo = $combo.Clone()
                $newCombo[$dimName] = $value
                $newResult += $newCombo
            }
        }

        $result = $newResult
    }

    return $result
}

function Remove-ExcludedCombinations {
    <#
    .SYNOPSIS
        Removes combinations that match exclude rules
    #>
    param(
        [object[]]$Matrix,
        [hashtable[]]$ExcludeRules
    )

    $filtered = @()

    foreach ($combo in $Matrix) {
        $isExcluded = $false

        foreach ($rule in $ExcludeRules) {
            # Check if this combo matches all properties of the exclude rule
            $matches = $true
            foreach ($key in $rule.Keys) {
                if ($combo[$key] -ne $rule[$key]) {
                    $matches = $false
                    break
                }
            }

            if ($matches) {
                $isExcluded = $true
                break
            }
        }

        if (-not $isExcluded) {
            $filtered += $combo
        }
    }

    return $filtered
}
