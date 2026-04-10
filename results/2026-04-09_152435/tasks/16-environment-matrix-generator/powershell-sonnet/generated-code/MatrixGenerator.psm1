# MatrixGenerator.psm1
# Module implementing GitHub Actions strategy.matrix generation logic.
#
# Design overview:
#   - Invoke-MatrixGeneration   : top-level entry point; accepts a config hashtable,
#                                 validates size, returns a strategy object.
#   - Get-MatrixSize            : computes the Cartesian-product size of the main axes.
#   - Build-MatrixDimensions    : extracts all named dimensions from the config.
#
# The returned object matches the GitHub Actions YAML structure:
#   strategy:
#     matrix:
#       os: [...]
#       node: [...]
#       include: [...]
#       exclude: [...]
#     max-parallel: N
#     fail-fast: bool


function Build-MatrixDimensions {
    <#
    .SYNOPSIS
        Extracts matrix dimensions from a config hashtable.
    .DESCRIPTION
        Pulls together:
        - config.os               -> matrix.os
        - config.language_versions.<lang>  -> matrix.<lang>
        - config.feature_flags.<flag>      -> matrix.<flag>
    Returns a hashtable of dimension-name -> value-array.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $dimensions = [ordered]@{}

    # OS dimension
    if ($Config.ContainsKey('os') -and $null -ne $Config.os) {
        $dimensions['os'] = @($Config.os)
    }

    # Language versions — each key becomes its own dimension
    if ($Config.ContainsKey('language_versions') -and $null -ne $Config.language_versions) {
        $langMap = $Config.language_versions
        # Support both hashtable and PSCustomObject (when deserialized from JSON)
        $keys = if ($langMap -is [hashtable]) { $langMap.Keys } else { $langMap.PSObject.Properties.Name }
        foreach ($lang in $keys) {
            $val = if ($langMap -is [hashtable]) { $langMap[$lang] } else { $langMap.$lang }
            $dimensions[$lang] = @($val)
        }
    }

    # Feature flags — each key becomes its own dimension
    if ($Config.ContainsKey('feature_flags') -and $null -ne $Config.feature_flags) {
        $flagMap = $Config.feature_flags
        $keys = if ($flagMap -is [hashtable]) { $flagMap.Keys } else { $flagMap.PSObject.Properties.Name }
        foreach ($flag in $keys) {
            $val = if ($flagMap -is [hashtable]) { $flagMap[$flag] } else { $flagMap.$flag }
            $dimensions[$flag] = @($val)
        }
    }

    return $dimensions
}


function Get-MatrixSize {
    <#
    .SYNOPSIS
        Computes the Cartesian-product size of the main matrix axes.
    .DESCRIPTION
        Does NOT count include/exclude adjustments — mirrors GitHub Actions'
        own limit check which applies before include/exclude expansion.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $dimensions = Build-MatrixDimensions -Config $Config

    if ($dimensions.Count -eq 0) { return 0 }

    $size = 1
    foreach ($key in $dimensions.Keys) {
        $size *= @($dimensions[$key]).Count
    }
    return $size
}


function Invoke-MatrixGeneration {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix object from a config hashtable.
    .DESCRIPTION
        Supports:
        - os, language_versions, feature_flags  (matrix dimensions)
        - include / exclude                      (combination overrides)
        - max_parallel / fail_fast              (strategy-level settings)
        - max_matrix_size                        (size guard; default 256)

        Throws if the Cartesian product exceeds max_matrix_size.
    .OUTPUTS
        Hashtable shaped as:
          @{
            strategy = @{
              matrix = @{ os=@(...); ... include=@(...); exclude=@(...) }
              'max-parallel' = N    # omitted if not configured
              'fail-fast'    = bool # omitted if not configured
            }
          }
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # --- Size validation ---
    $maxSize = if ($Config.ContainsKey('max_matrix_size') -and $null -ne $Config.max_matrix_size) {
        [int]$Config.max_matrix_size
    } else {
        256
    }

    $actualSize = Get-MatrixSize -Config $Config
    if ($actualSize -gt $maxSize) {
        throw "Matrix size $actualSize exceeds the maximum allowed size of $maxSize. " +
              "Reduce the number of OS options, language versions, or feature flags, " +
              "or increase max_matrix_size."
    }

    # --- Build the matrix object ---
    $dimensions = Build-MatrixDimensions -Config $Config
    # Use a regular hashtable so callers can use ContainsKey(); ordering is
    # preserved during JSON serialization via the dimension insertion order.
    $matrix = @{}

    foreach ($key in $dimensions.Keys) {
        $matrix[$key] = $dimensions[$key]
    }

    # Attach include/exclude rules verbatim
    if ($Config.ContainsKey('include') -and $null -ne $Config.include) {
        $matrix['include'] = @($Config.include)
    }
    if ($Config.ContainsKey('exclude') -and $null -ne $Config.exclude) {
        $matrix['exclude'] = @($Config.exclude)
    }

    # --- Build the strategy object (regular hashtable — ContainsKey supported) ---
    $strategy = @{ matrix = $matrix }

    if ($Config.ContainsKey('max_parallel') -and $null -ne $Config.max_parallel) {
        $strategy['max-parallel'] = [int]$Config.max_parallel
    }

    if ($Config.ContainsKey('fail_fast') -and $null -ne $Config.fail_fast) {
        $strategy['fail-fast'] = [bool]$Config.fail_fast
    }

    return @{ strategy = $strategy }
}


Export-ModuleMember -Function Invoke-MatrixGeneration, Get-MatrixSize
