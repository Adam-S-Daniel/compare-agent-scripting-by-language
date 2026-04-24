# New-BuildMatrix.ps1
# Generates a GitHub Actions strategy.matrix from a configuration hashtable.

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix from a config hashtable.
    .PARAMETER Config
        Hashtable with keys: os, language, feature_flag (optional),
        include (optional), exclude (optional), failFast (optional), maxParallel (optional).
    .PARAMETER MaxMatrixSize
        Maximum allowed number of matrix combinations (cross-product). Default 256.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [int]$MaxMatrixSize = 256
    )

    # Validate required keys
    if (-not $Config.ContainsKey('os')) {
        throw "Config must contain 'os' key"
    }
    if ($Config.os.Count -eq 0) {
        throw "Config 'os' list must not be empty"
    }
    if (-not $Config.ContainsKey('language') -or $Config.language.Count -eq 0) {
        throw "Config 'language' list must not be empty"
    }

    # Compute cross-product size to validate against maximum
    $size = $Config.os.Count * $Config.language.Count
    if ($Config.ContainsKey('feature_flag') -and $Config.feature_flag.Count -gt 0) {
        $size *= $Config.feature_flag.Count
    }

    if ($size -gt $MaxMatrixSize) {
        throw "Matrix size $size exceeds maximum allowed size of $MaxMatrixSize"
    }

    # Build the matrix dimension object
    $matrix = [ordered]@{
        os       = $Config.os
        language = $Config.language
    }

    if ($Config.ContainsKey('feature_flag') -and $Config.feature_flag.Count -gt 0) {
        $matrix['feature_flag'] = $Config.feature_flag
    }

    if ($Config.ContainsKey('include') -and $Config.include.Count -gt 0) {
        $matrix['include'] = $Config.include
    }

    if ($Config.ContainsKey('exclude') -and $Config.exclude.Count -gt 0) {
        $matrix['exclude'] = $Config.exclude
    }

    # Build the top-level strategy object
    $strategy = [ordered]@{
        matrix       = $matrix
        'fail-fast'  = if ($Config.ContainsKey('failFast')) { $Config.failFast } else { $true }
    }

    if ($Config.ContainsKey('maxParallel')) {
        $strategy['max-parallel'] = $Config.maxParallel
    }

    return $strategy
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
        Serializes a strategy hashtable to a compact JSON string.
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Strategy
    )
    process {
        return $Strategy | ConvertTo-Json -Depth 10 -Compress
    }
}

function Invoke-MatrixGenerator {
    <#
    .SYNOPSIS
        Accepts a JSON config string and returns a JSON strategy string.
        This is the main entry point for the workflow.
    .PARAMETER JsonConfig
        JSON string describing the matrix configuration.
    .PARAMETER MaxMatrixSize
        Maximum allowed matrix size. Default 256.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$JsonConfig,

        [int]$MaxMatrixSize = 256
    )

    $parsed = $JsonConfig | ConvertFrom-Json -AsHashtable

    # ConvertFrom-Json with -AsHashtable gives PSCustomObject arrays for nested objects;
    # normalize include/exclude arrays to hashtables for consistent handling
    foreach ($key in @('include', 'exclude')) {
        if ($parsed.ContainsKey($key)) {
            $parsed[$key] = @($parsed[$key] | ForEach-Object {
                if ($_ -is [hashtable]) { $_ }
                else {
                    $ht = @{}
                    $_.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
                    $ht
                }
            })
        }
    }

    $strategy = New-BuildMatrix -Config $parsed -MaxMatrixSize $MaxMatrixSize
    return $strategy | ConvertTo-MatrixJson
}
