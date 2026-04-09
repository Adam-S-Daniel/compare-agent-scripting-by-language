<#
.SYNOPSIS
    Generates a GitHub Actions strategy.matrix JSON from a configuration file.

.DESCRIPTION
    Reads a JSON configuration describing OS options, language versions, feature flags,
    include/exclude rules, max-parallel limits, and fail-fast settings. Produces a
    complete matrix JSON suitable for GitHub Actions strategy.matrix.

.PARAMETER ConfigPath
    Path to the JSON configuration file.

.PARAMETER MaxMatrixSize
    Maximum allowed number of matrix combinations (default 256, GitHub's limit).

.OUTPUTS
    JSON string representing the complete strategy block (matrix, fail-fast, max-parallel).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [int]$MaxMatrixSize = 256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Read and parse the configuration file
function Read-MatrixConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Configuration file is empty: $Path"
    }

    try {
        $config = $content | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in configuration file: $Path - $_"
    }

    return $config
}

# Build the cartesian product of all matrix dimensions
function Get-CartesianProduct {
    param([hashtable]$Dimensions)

    if ($Dimensions.Count -eq 0) {
        return @()
    }

    $keys = @($Dimensions.Keys | Sort-Object)
    $result = @(@{})

    foreach ($key in $keys) {
        $values = @($Dimensions[$key])
        $newResult = @()
        foreach ($combo in $result) {
            foreach ($val in $values) {
                $newCombo = @{}
                foreach ($k in $combo.Keys) {
                    $newCombo[$k] = $combo[$k]
                }
                $newCombo[$key] = $val
                $newResult += $newCombo
            }
        }
        $result = $newResult
    }

    return $result
}

# Check if a combination matches a filter (all keys in filter must match)
function Test-CombinationMatch {
    param(
        [hashtable]$Combination,
        [hashtable]$Filter
    )

    foreach ($key in $Filter.Keys) {
        if (-not $Combination.ContainsKey($key)) {
            return $false
        }
        if ($Combination[$key] -ne $Filter[$key]) {
            return $false
        }
    }
    return $true
}

# Convert PSCustomObject to hashtable recursively
function ConvertTo-Hashtable {
    param($InputObject)

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [System.Collections.Hashtable]) {
        return $InputObject
    }

    $ht = @{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        $ht[$prop.Name] = $prop.Value
    }
    return $ht
}

# Main matrix generation logic
function New-BuildMatrix {
    param(
        [PSCustomObject]$Config,
        [int]$MaxSize = 256
    )

    # Extract matrix dimensions from the config
    $dimensions = @{}

    if ($null -eq $Config.matrix -and $null -eq $Config.dimensions) {
        throw "Configuration must contain a 'matrix' or 'dimensions' property with axis definitions."
    }

    $matrixDef = if ($null -ne $Config.matrix) { $Config.matrix } else { $Config.dimensions }

    # Collect dimensions (arrays of values), skip special keys
    $specialKeys = @('include', 'exclude')
    $matrixProps = @($matrixDef.PSObject.Properties)
    foreach ($prop in $matrixProps) {
        if ($prop.Name -notin $specialKeys) {
            $dimensions[$prop.Name] = @($prop.Value)
        }
    }

    # Generate cartesian product
    $combinations = @(Get-CartesianProduct -Dimensions $dimensions)

    # Apply exclude rules - check property existence safely
    $excludeRules = @()
    $matrixPropNames = @($matrixProps | ForEach-Object { $_.Name })
    $configPropNames = @($Config.PSObject.Properties | ForEach-Object { $_.Name })

    if ('exclude' -in $matrixPropNames -and $null -ne $matrixDef.exclude) {
        $excludeRules = @($matrixDef.exclude)
    }
    if ('exclude' -in $configPropNames -and $null -ne $Config.exclude) {
        $excludeRules = @($Config.exclude)
    }

    if ($excludeRules.Count -gt 0) {
        $filtered = @()
        foreach ($combo in $combinations) {
            $excluded = $false
            foreach ($rule in $excludeRules) {
                $ruleHt = ConvertTo-Hashtable $rule
                if (Test-CombinationMatch -Combination $combo -Filter $ruleHt) {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) {
                $filtered += $combo
            }
        }
        $combinations = $filtered
    }

    # Apply include rules (additional combinations merged or appended)
    $includeRules = @()
    if ('include' -in $matrixPropNames -and $null -ne $matrixDef.include) {
        $includeRules = @($matrixDef.include)
    }
    if ('include' -in $configPropNames -and $null -ne $Config.include) {
        $includeRules = @($Config.include)
    }

    if ($includeRules.Count -gt 0) {
        foreach ($rule in $includeRules) {
            $ruleHt = ConvertTo-Hashtable $rule

            # Check if this include matches any existing combination to augment it
            $matched = $false
            foreach ($combo in $combinations) {
                # Build a filter from the keys that overlap with dimension keys
                $overlapFilter = @{}
                foreach ($key in $ruleHt.Keys) {
                    if ($dimensions.ContainsKey($key)) {
                        $overlapFilter[$key] = $ruleHt[$key]
                    }
                }

                if ($overlapFilter.Count -gt 0 -and (Test-CombinationMatch -Combination $combo -Filter $overlapFilter)) {
                    # Merge extra keys into the matching combination
                    foreach ($key in $ruleHt.Keys) {
                        $combo[$key] = $ruleHt[$key]
                    }
                    $matched = $true
                }
            }

            # If no match, append as a new combination
            if (-not $matched) {
                $combinations += $ruleHt
            }
        }
    }

    # Validate matrix size
    if ($combinations.Count -gt $MaxSize) {
        throw "Matrix size ($($combinations.Count)) exceeds maximum allowed ($MaxSize). Reduce dimensions or add exclude rules."
    }

    if ($combinations.Count -eq 0) {
        throw "Matrix is empty after applying rules. Check your configuration."
    }

    # Build the output strategy object
    $matrixOutput = @{}

    # Add dimension keys with their values for the matrix property
    foreach ($key in $dimensions.Keys) {
        $matrixOutput[$key] = $dimensions[$key]
    }

    # Add include/exclude to matrix output if present
    if ($includeRules.Count -gt 0) {
        $includeList = @()
        foreach ($rule in $includeRules) {
            $includeList += (ConvertTo-Hashtable $rule)
        }
        $matrixOutput['include'] = $includeList
    }
    if ($excludeRules.Count -gt 0) {
        $excludeList = @()
        foreach ($rule in $excludeRules) {
            $excludeList += (ConvertTo-Hashtable $rule)
        }
        $matrixOutput['exclude'] = $excludeList
    }

    $strategy = [ordered]@{
        matrix = $matrixOutput
    }

    # fail-fast configuration
    if ('fail-fast' -in $configPropNames) {
        $strategy['fail-fast'] = [bool]$Config.'fail-fast'
    }
    elseif ('failFast' -in $configPropNames) {
        $strategy['fail-fast'] = [bool]$Config.failFast
    }

    # max-parallel configuration
    if ('max-parallel' -in $configPropNames) {
        $strategy['max-parallel'] = [int]$Config.'max-parallel'
    }
    elseif ('maxParallel' -in $configPropNames) {
        $strategy['max-parallel'] = [int]$Config.maxParallel
    }

    # Summary info
    $strategy['_summary'] = [ordered]@{
        totalCombinations = $combinations.Count
        dimensions        = @($dimensions.Keys | Sort-Object)
        maxSize           = $MaxSize
    }

    return $strategy
}

# --- Main execution ---
$config = Read-MatrixConfig -Path $ConfigPath
$strategy = New-BuildMatrix -Config $config -MaxSize $MaxMatrixSize
$json = $strategy | ConvertTo-Json -Depth 10
Write-Output $json
