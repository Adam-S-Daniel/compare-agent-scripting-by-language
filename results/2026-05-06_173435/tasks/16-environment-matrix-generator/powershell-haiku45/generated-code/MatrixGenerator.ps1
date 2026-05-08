function New-EnvironmentMatrix {
    <#
    .SYNOPSIS
    Generates a GitHub Actions build matrix from OS options, language versions, and feature flags.

    .DESCRIPTION
    Creates a matrix configuration suitable for GitHub Actions strategy.matrix that combines
    multiple dimensions (OS, language versions, features) with support for include/exclude rules,
    max-parallel limits, and fail-fast configuration.

    .PARAMETER Configuration
    Hashtable containing:
    - os: array of OS strings
    - language: array of language version strings
    - features: (optional) array of feature flags
    - include: (optional) array of custom combinations to add
    - exclude: (optional) array of combinations to remove
    - max_parallel: (optional) max parallel jobs
    - fail_fast: (optional) whether to fail fast
    - max_size: (optional) maximum matrix size allowed

    .OUTPUTS
    Hashtable representing the matrix configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    # Initialize result
    $matrix = @{
        include = @()
    }

    # Extract dimensions
    $osArray = $Configuration.os -as [array]
    $languageArray = $Configuration.language -as [array]
    $featureArray = $Configuration.features -as [array]
    $excludeArray = $Configuration.exclude -as [array]
    $includeArray = $Configuration.include -as [array]
    $maxSize = $Configuration.max_size -as [int]
    $maxParallel = $Configuration.max_parallel -as [int]
    $failFast = $Configuration.fail_fast

    # Validate inputs
    if ($null -eq $osArray -or $osArray.Count -eq 0) {
        throw "Configuration must include 'os' array"
    }
    if ($null -eq $languageArray -or $languageArray.Count -eq 0) {
        throw "Configuration must include 'language' array"
    }

    # Generate cartesian product of dimensions
    foreach ($os in $osArray) {
        foreach ($lang in $languageArray) {
            if ($featureArray -and $featureArray.Count -gt 0) {
                # If features exist, create a combination for each feature
                foreach ($feature in $featureArray) {
                    $combination = @{
                        os = $os
                        language = $lang
                        feature = $feature
                    }
                    # Add to matrix if not excluded
                    if (-not (Test-ExcludedCombination -Combination $combination -ExcludeArray $excludeArray)) {
                        $matrix.include += [hashtable]$combination
                    }
                }
            } else {
                # No features, just create base combination
                $combination = @{
                    os = $os
                    language = $lang
                }
                # Add to matrix if not excluded
                if (-not (Test-ExcludedCombination -Combination $combination -ExcludeArray $excludeArray)) {
                    $matrix.include += [hashtable]$combination
                }
            }
        }
    }

    # Add explicit includes
    if ($includeArray) {
        foreach ($item in $includeArray) {
            $matrix.include += $item
        }
    }

    # Validate matrix size
    $matrixSize = $matrix.include.Count
    if ($maxSize -gt 0 -and $matrixSize -gt $maxSize) {
        throw "Matrix size ($matrixSize) exceeds maximum allowed size ($maxSize)"
    }

    # Add optional configuration
    if ($maxParallel -gt 0) {
        $matrix["max-parallel"] = $maxParallel
    }

    if ($null -ne $failFast) {
        $matrix["fail-fast"] = $failFast
    }

    return $matrix
}

function Test-ExcludedCombination {
    <#
    .SYNOPSIS
    Tests if a combination matches any exclude rule.

    .PARAMETER Combination
    Hashtable representing a single matrix combination

    .PARAMETER ExcludeArray
    Array of hashtables representing exclusion rules
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Combination,

        [Parameter(Mandatory = $false)]
        [array]$ExcludeArray
    )

    if ($null -eq $ExcludeArray -or $ExcludeArray.Count -eq 0) {
        return $false
    }

    foreach ($excludeRule in $ExcludeArray) {
        # Check if all keys in the exclude rule match the combination
        $matches = $true
        foreach ($key in $excludeRule.Keys) {
            if ($Combination[$key] -ne $excludeRule[$key]) {
                $matches = $false
                break
            }
        }

        if ($matches) {
            return $true
        }
    }

    return $false
}

function Export-MatrixJson {
    <#
    .SYNOPSIS
    Exports matrix as JSON suitable for GitHub Actions.

    .PARAMETER Matrix
    The matrix hashtable to export

    .PARAMETER OutputPath
    Optional file path to save JSON output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Matrix,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    $json = $Matrix | ConvertTo-Json -Depth 10

    if ($OutputPath) {
        $json | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "Matrix exported to: $OutputPath"
    }

    return $json
}
