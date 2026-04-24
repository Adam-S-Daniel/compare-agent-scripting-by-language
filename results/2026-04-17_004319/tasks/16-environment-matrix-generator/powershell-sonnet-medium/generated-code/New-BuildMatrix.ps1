# New-BuildMatrix.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration hashtable.
# TDD: stubs written first (all throw), then implemented green.

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$Config,

        [Parameter(Mandatory = $false)]
        [int]$DefaultMaxSize = 256
    )

    # --- Input validation ---
    if ($null -eq $Config) {
        throw "Config cannot be null or empty."
    }

    # Collect matrix dimensions (everything except control keys)
    $controlKeys = @('fail_fast', 'max_parallel', 'max_size', 'include', 'exclude')
    $dimensions = @{}
    foreach ($key in $Config.Keys) {
        if ($key -notin $controlKeys) {
            $dimensions[$key] = $Config[$key]
        }
    }

    if ($dimensions.Count -eq 0) {
        throw "Config must contain at least one matrix dimension (e.g. 'os', 'language')."
    }

    # --- Compute matrix size (Cartesian product of all dimension lengths) ---
    $maxSize = if ($Config.ContainsKey('max_size')) { [int]$Config['max_size'] } else { $DefaultMaxSize }

    $size = 1
    foreach ($dim in $dimensions.Values) {
        $size *= @($dim).Count
    }

    if ($size -gt $maxSize) {
        throw "Matrix size ($size) exceeds the maximum allowed ($maxSize). Reduce dimensions or raise max_size."
    }

    # --- Build the output object ---
    $output = [ordered]@{
        matrix = $dimensions
    }

    # fail-fast (GitHub Actions uses kebab-case)
    if ($Config.ContainsKey('fail_fast')) {
        $output['fail-fast'] = [bool]$Config['fail_fast']
    }

    # max-parallel
    if ($Config.ContainsKey('max_parallel')) {
        $output['max-parallel'] = [int]$Config['max_parallel']
    }

    # include / exclude pass-through
    if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        $output['include'] = $Config['include']
    }

    if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        $output['exclude'] = $Config['exclude']
    }

    return $output | ConvertTo-Json -Depth 10
}

function ConvertFrom-MatrixConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonConfig
    )

    # Will throw on invalid JSON — intentional
    $config = $JsonConfig | ConvertFrom-Json -AsHashtable
    return New-BuildMatrix -Config $config
}
