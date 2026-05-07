# Environment Matrix Generator - GitHub Actions matrix builder
# Generates build matrices from configuration with support for include/exclude rules

function New-EnvironmentMatrix {
    <#
    .SYNOPSIS
    Generates a GitHub Actions strategy matrix from configuration.

    .DESCRIPTION
    Takes a configuration hashtable describing OS options, language versions, and feature flags,
    then generates a matrix suitable for GitHub Actions strategy.matrix. Supports include/exclude
    rules, max-parallel limits, and fail-fast configuration.

    .PARAMETER Configuration
    Hashtable containing matrix configuration keys

    .OUTPUTS
    PSCustomObject representing the matrix in JSON-compatible format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    # Validate required fields and initialize
    $os = $Configuration['os']
    $language = $Configuration['language']

    if (-not $os -or $os.Count -eq 0) {
        throw "Configuration must include 'os' array with at least one value"
    }

    if ($Configuration.ContainsKey('language')) {
        if ($language -eq $null -or $language.Count -eq 0) {
            throw "Language array cannot be empty"
        }
    }

    # Initialize matrix structure
    $matrixInclude = @()

    # Generate cartesian product of primary dimensions
    if ($language) {
        foreach ($osValue in $os) {
            foreach ($langValue in $language) {
                $combination = @{
                    os = $osValue
                    language = $langValue
                }
                $matrixInclude += $combination
            }
        }
    } else {
        # If no language specified, just use OS
        foreach ($osValue in $os) {
            $combination = @{
                os = $osValue
            }
            $matrixInclude += $combination
        }
    }

    # Add feature flags as additional dimensions
    if ($Configuration['features'] -and $Configuration['features'].Count -gt 0) {
        $features = $Configuration['features']
        $newInclude = @()

        foreach ($feature in $features) {
            foreach ($combo in $matrixInclude) {
                $newCombo = $combo.Clone()
                $newCombo['features'] = $feature
                $newInclude += $newCombo
            }
        }

        $matrixInclude = $newInclude
    }

    # Validate matrix size
    $maxSize = $Configuration['maxSize']
    if ($maxSize -and $matrixInclude.Count -gt $maxSize) {
        throw "Matrix size ($($matrixInclude.Count)) exceeds maximum allowed size ($maxSize)"
    }

    # Apply exclude rules
    $matrixExclude = @()
    if ($Configuration['exclude'] -and $Configuration['exclude'].Count -gt 0) {
        foreach ($excludeRule in $Configuration['exclude']) {
            $matrixExclude += $excludeRule

            # Remove matching combinations from include list
            $matrixInclude = @($matrixInclude | Where-Object {
                -not (Test-MatrixRuleMatch -Combination $_ -Rule $excludeRule)
            })
        }
    }

    # Add include rules
    if ($Configuration['include'] -and $Configuration['include'].Count -gt 0) {
        foreach ($includeRule in $Configuration['include']) {
            # Check if this combination already exists
            $exists = $false
            foreach ($existing in $matrixInclude) {
                if (Test-MatrixRuleMatch -Combination $existing -Rule $includeRule) {
                    $exists = $true
                    break
                }
            }

            if (-not $exists) {
                $matrixInclude += $includeRule
            }
        }
    }

    # Build result object
    $result = @{
        include = $matrixInclude
    }

    # Add exclude rules if any
    if ($matrixExclude.Count -gt 0) {
        $result['exclude'] = $matrixExclude
    }

    # Add optional configuration
    if ($Configuration.ContainsKey('maxParallel')) {
        $result['max-parallel'] = $Configuration['maxParallel']
    }

    if ($Configuration.ContainsKey('failFast')) {
        $result['fail-fast'] = $Configuration['failFast']
    }

    # Convert to PSCustomObject for JSON serialization
    return $result | ConvertTo-PSObject
}

function Test-MatrixRuleMatch {
    <#
    .SYNOPSIS
    Tests if a matrix combination matches a rule.

    .DESCRIPTION
    Checks if all properties specified in the rule match the corresponding
    properties in the combination.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Combination,

        [Parameter(Mandatory = $true)]
        [hashtable]$Rule
    )

    foreach ($key in $Rule.Keys) {
        if ($Combination[$key] -ne $Rule[$key]) {
            return $false
        }
    }

    return $true
}

function ConvertTo-PSObject {
    <#
    .SYNOPSIS
    Recursively converts hashtables to PSCustomObject for proper JSON serialization.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject
    )

    if ($InputObject -is [hashtable]) {
        $psobj = New-Object PSCustomObject
        foreach ($key in $InputObject.Keys) {
            $value = $InputObject[$key]
            if ($value -is [hashtable]) {
                $value = ConvertTo-PSObject -InputObject $value
            } elseif ($value -is [array]) {
                $value = @($value | ForEach-Object {
                    if ($_ -is [hashtable]) {
                        ConvertTo-PSObject -InputObject $_
                    } else {
                        $_
                    }
                })
            }
            $psobj | Add-Member -NotePropertyName $key -NotePropertyValue $value
        }
        return $psobj
    } elseif ($InputObject -is [array]) {
        return @($InputObject | ForEach-Object {
            if ($_ -is [hashtable]) {
                ConvertTo-PSObject -InputObject $_
            } else {
                $_
            }
        })
    } else {
        return $InputObject
    }
}

Export-ModuleMember -Function @('New-EnvironmentMatrix')
