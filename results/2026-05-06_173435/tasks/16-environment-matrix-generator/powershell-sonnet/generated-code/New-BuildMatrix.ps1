# New-BuildMatrix.ps1
# Environment Matrix Generator for GitHub Actions
#
# Reads a JSON configuration file and emits a GitHub Actions strategy object
# (fail-fast, max-parallel, matrix with include/exclude) as JSON on stdout.
#
# Usage:
#   ./New-BuildMatrix.ps1 -ConfigFile config.json
#   ./New-BuildMatrix.ps1 -ConfigFile config.json -MaxMatrixSize 100

[CmdletBinding()]
param(
    # Path to JSON configuration file. Empty string means dot-sourced for testing.
    [string]$ConfigFile = "",

    # Global upper-bound on matrix size. Config's own maxMatrixSize overrides this.
    [int]$MaxMatrixSize = 256
)

# ---------------------------------------------------------------------------
# Public helpers (also exercised directly by Pester unit tests)
# ---------------------------------------------------------------------------

# Returns the Cartesian-product size (integer) of all dimensions in the
# provided hashtable.  Each value is assumed to be an array.
function Get-MatrixSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Dimensions
    )
    $size = 1
    foreach ($key in $Dimensions.Keys) {
        $values = $Dimensions[$key]
        $count  = if ($values -is [System.Collections.ICollection]) {
            $values.Count
        } else {
            1
        }
        $size *= $count
    }
    return $size
}

# Core generator: accepts a hashtable config, validates size, and returns a
# [pscustomobject] whose .strategy property mirrors GitHub Actions strategy shape.
function Invoke-MatrixGenerator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        # Default upper-bound; the config's own maxMatrixSize wins if present.
        [int]$MaxSize = 256
    )

    # --- collect matrix dimensions ---
    $dimensions = [ordered]@{}

    if ($Config.ContainsKey('os') -and $Config['os']) {
        $dimensions['os'] = $Config['os']
    }

    if ($Config.ContainsKey('versions') -and $Config['versions']) {
        foreach ($lang in $Config['versions'].Keys) {
            $dimensions[$lang] = $Config['versions'][$lang]
        }
    }

    if ($Config.ContainsKey('features') -and $Config['features']) {
        foreach ($feat in $Config['features'].Keys) {
            $dimensions[$feat] = $Config['features'][$feat]
        }
    }

    # --- size validation ---
    # Config's maxMatrixSize takes precedence over the parameter.
    $effectiveMax = if ($Config.ContainsKey('maxMatrixSize') -and
                        $null -ne $Config['maxMatrixSize']) {
        [int]$Config['maxMatrixSize']
    } else {
        $MaxSize
    }

    if ($dimensions.Count -gt 0) {
        $computedSize = Get-MatrixSize -Dimensions $dimensions
        if ($computedSize -gt $effectiveMax) {
            throw "Matrix size ($computedSize) exceeds maximum size ($effectiveMax). " +
                  "Reduce the number of dimensions or values."
        }
    }

    # --- build matrix ---
    $matrix = [ordered]@{}

    foreach ($key in $dimensions.Keys) {
        $matrix[$key] = $dimensions[$key]
    }

    if ($Config.ContainsKey('include') -and $Config['include'] -and
        @($Config['include']).Count -gt 0) {
        $matrix['include'] = $Config['include']
    }

    if ($Config.ContainsKey('exclude') -and $Config['exclude'] -and
        @($Config['exclude']).Count -gt 0) {
        $matrix['exclude'] = $Config['exclude']
    }

    # --- build strategy ---
    $strategy = [ordered]@{
        'fail-fast' = if ($Config.ContainsKey('failFast') -and
                          $null -ne $Config['failFast']) {
            [bool]$Config['failFast']
        } else {
            $false
        }
        'matrix' = $matrix
    }

    if ($Config.ContainsKey('maxParallel') -and $null -ne $Config['maxParallel']) {
        $strategy['max-parallel'] = [int]$Config['maxParallel']
    }

    return [pscustomobject]@{ strategy = $strategy }
}

# ---------------------------------------------------------------------------
# Entry point – only executes when script is invoked directly (not dot-sourced)
# ---------------------------------------------------------------------------
if ($ConfigFile) {
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Config file not found: $ConfigFile"
        exit 1
    }

    try {
        $raw    = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
        $config = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to parse config file '$ConfigFile': $_"
        exit 1
    }

    # Command-line -MaxMatrixSize overrides only when explicitly supplied and
    # the config doesn't already carry its own maxMatrixSize.
    if ($PSBoundParameters.ContainsKey('MaxMatrixSize') -and
        -not $config.ContainsKey('maxMatrixSize')) {
        $config['maxMatrixSize'] = $MaxMatrixSize
    }

    try {
        $result = Invoke-MatrixGenerator -Config $config -MaxSize $MaxMatrixSize
        $result | ConvertTo-Json -Depth 10
    }
    catch {
        Write-Error "Failed to generate matrix: $_"
        exit 1
    }
}
