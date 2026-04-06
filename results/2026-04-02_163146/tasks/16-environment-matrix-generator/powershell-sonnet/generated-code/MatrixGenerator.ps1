# MatrixGenerator.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration hashtable.
#
# Approach:
#   1. Validate the input configuration.
#   2. Separate "reserved" keys (fail_fast, max_parallel, include, exclude, max_size)
#      from "axis" keys (os, language, feature_flags, etc.).
#   3. Compute the cartesian product size (product of axis value counts) and
#      reject if it exceeds max_size (default 256).
#   4. Build the output object and serialize to JSON.

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix JSON from a configuration hashtable.
    .PARAMETER Config
        A hashtable describing the matrix. Recognised special keys:
          fail_fast     - bool   (default: $true)
          max_parallel  - int    (optional, must be > 0)
          max_size      - int    (default: 256, max combinations allowed)
          include       - array of hashtables (extra jobs)
          exclude       - array of hashtables (jobs to exclude)
        Every other key is treated as a matrix axis whose value must be a non-empty array.
    .OUTPUTS
        JSON string representing the strategy.matrix object.
    #>
    param(
        [hashtable]$Config
    )

    # -------------------------------------------------------
    # 1. Validate config is not null
    # -------------------------------------------------------
    if ($null -eq $Config) {
        throw "config must not be null."
    }

    # Reserved keys that are NOT matrix axes
    $reservedKeys = @('fail_fast', 'max_parallel', 'max_size', 'include', 'exclude')

    # -------------------------------------------------------
    # 2. Extract axis keys
    # -------------------------------------------------------
    $axisKeys = $Config.Keys | Where-Object { $_ -notin $reservedKeys }

    if (-not $axisKeys -or @($axisKeys).Count -eq 0) {
        throw "Config must define at least one axis (e.g. 'os', 'language')."
    }

    # -------------------------------------------------------
    # 3. Validate each axis has a non-empty value list
    # -------------------------------------------------------
    foreach ($key in $axisKeys) {
        $val = $Config[$key]
        if ($null -eq $val -or @($val).Count -eq 0) {
            throw "Axis '$key' must have a non-empty list of values."
        }
    }

    # -------------------------------------------------------
    # 4. Validate max_parallel if provided
    # -------------------------------------------------------
    if ($Config.ContainsKey('max_parallel')) {
        $mp = [int]$Config['max_parallel']
        if ($mp -le 0) {
            throw "max_parallel must be a positive integer."
        }
    }

    # -------------------------------------------------------
    # 5. Compute cartesian product size and validate
    # -------------------------------------------------------
    $maxSize = if ($Config.ContainsKey('max_size')) { [int]$Config['max_size'] } else { 256 }

    $matrixSize = 1
    foreach ($key in $axisKeys) {
        $matrixSize *= @($Config[$key]).Count
    }

    if ($matrixSize -gt $maxSize) {
        throw "Matrix size ($matrixSize) exceeds maximum allowed size ($maxSize)."
    }

    # -------------------------------------------------------
    # 6. Build the output object
    # -------------------------------------------------------
    $output = [ordered]@{}

    # Add axis arrays
    foreach ($key in ($axisKeys | Sort-Object)) {
        $output[$key] = @($Config[$key])
    }

    # fail_fast (default true)
    $failFast = if ($Config.ContainsKey('fail_fast')) { [bool]$Config['fail_fast'] } else { $true }
    $output['fail_fast'] = $failFast

    # max_parallel (optional)
    if ($Config.ContainsKey('max_parallel')) {
        $output['max_parallel'] = [int]$Config['max_parallel']
    }

    # include / exclude (default to empty array)
    $output['include'] = if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        @($Config['include'])
    } else {
        @()
    }

    $output['exclude'] = if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        @($Config['exclude'])
    } else {
        @()
    }

    # Expose computed matrix size for callers
    $output['matrix_size'] = $matrixSize

    # -------------------------------------------------------
    # 7. Serialize to JSON
    # -------------------------------------------------------
    return $output | ConvertTo-Json -Depth 10
}
