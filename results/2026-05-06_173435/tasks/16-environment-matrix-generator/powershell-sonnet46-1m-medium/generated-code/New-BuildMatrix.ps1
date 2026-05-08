# New-BuildMatrix.ps1 - Generate a GitHub Actions build matrix from configuration
# Supports include/exclude rules, max-parallel limits, fail-fast, and size validation.

param(
    [string]$ConfigPath = "",
    [int]$MaxSize = 256
)

# Compute the number of combinations from a flat set of dimension arrays.
# The total is the cartesian product of all dimension sizes.
function Get-CartesianProductCount {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Dimensions
    )

    if ($Dimensions.Count -eq 0) { return 0 }

    $count = 1
    foreach ($key in $Dimensions.Keys) {
        $count *= @($Dimensions[$key]).Count
    }
    return $count
}

# Convert a configuration hashtable into a GitHub Actions strategy.matrix object.
function ConvertTo-BuildMatrix {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        # Overrides the MaxSize limit (lower values are tighter)
        [int]$MaxSize = 256
    )

    # Keys that control matrix behaviour but are not dimensions
    $reservedKeys = @('include', 'exclude', 'maxParallel', 'failFast', 'maxSize')

    # Collect matrix dimensions (everything that is not a reserved key)
    $dimensions = [ordered]@{}
    foreach ($key in $Config.Keys) {
        if ($key -notin $reservedKeys) {
            $dimensions[$key] = @($Config[$key])
        }
    }

    if ($dimensions.Count -eq 0) {
        throw "Configuration must contain at least one matrix dimension (e.g. 'os', 'language-version')"
    }

    # Count base combinations from the cartesian product
    $baseCombinations    = Get-CartesianProductCount -Dimensions $dimensions
    $includeCombinations = if ($Config.ContainsKey('include')) { @($Config['include']).Count } else { 0 }
    $totalCombinations   = $baseCombinations + $includeCombinations

    # Honour a per-config maxSize override, then fall back to the parameter
    $effectiveMax = if ($Config.ContainsKey('maxSize')) { [int]$Config['maxSize'] } else { $MaxSize }

    if ($totalCombinations -gt $effectiveMax) {
        throw "Matrix size ($totalCombinations combinations) exceeds the maximum allowed size ($effectiveMax). " +
              "Reduce dimensions, remove include entries, or raise the limit."
    }

    # Build the matrix object: dimensions first, then optional include/exclude
    $matrix = [ordered]@{}
    foreach ($key in $dimensions.Keys) {
        $matrix[$key] = $dimensions[$key]
    }

    if ($Config.ContainsKey('include') -and @($Config['include']).Count -gt 0) {
        $matrix['include'] = @($Config['include'])
    }

    if ($Config.ContainsKey('exclude') -and @($Config['exclude']).Count -gt 0) {
        $matrix['exclude'] = @($Config['exclude'])
    }

    # Build the top-level strategy result
    $strategy = [ordered]@{
        matrix               = $matrix
        'total-combinations' = $totalCombinations
    }

    if ($Config.ContainsKey('maxParallel')) {
        $strategy['max-parallel'] = [int]$Config['maxParallel']
    }

    if ($Config.ContainsKey('failFast')) {
        $strategy['fail-fast'] = [bool]$Config['failFast']
    }

    return $strategy
}

# Entry point: only execute when called with a config file path
if ($ConfigPath) {
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        exit 1
    }

    try {
        $raw    = Get-Content $ConfigPath -Raw
        $config = $raw | ConvertFrom-Json -AsHashtable
        $result = ConvertTo-BuildMatrix -Config $config -MaxSize $MaxSize
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
