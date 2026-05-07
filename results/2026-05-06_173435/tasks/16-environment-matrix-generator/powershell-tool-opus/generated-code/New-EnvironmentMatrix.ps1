# Generates a GitHub Actions strategy.matrix JSON from a configuration hashtable or JSON file.
# Supports include/exclude rules, max-parallel, fail-fast, and matrix size validation.

function New-EnvironmentMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    if ($ConfigPath) {
        $raw = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        $Config = @{}
        foreach ($prop in $raw.PSObject.Properties) {
            $val = $prop.Value
            if ($val -is [System.Array] -or $val -is [System.Collections.IEnumerable] -and $val -isnot [string]) {
                $Config[$prop.Name] = @($val)
            } elseif ($val -is [PSCustomObject]) {
                $list = @()
                if ($prop.Name -eq 'include' -or $prop.Name -eq 'exclude') {
                    foreach ($item in @($val)) {
                        $ht = @{}
                        foreach ($p in $item.PSObject.Properties) { $ht[$p.Name] = $p.Value }
                        $list += $ht
                    }
                    $Config[$prop.Name] = $list
                } else {
                    $Config[$prop.Name] = $val
                }
            } else {
                $Config[$prop.Name] = $val
            }
        }
    }

    if (-not $Config -or $Config.Count -eq 0) {
        throw "Config must contain at least one matrix dimension."
    }

    $reservedKeys = @('include', 'exclude', 'max-parallel', 'fail-fast', 'max-combinations')
    $dimensions = @{}
    $include = $null
    $exclude = $null
    $maxParallel = $null
    $failFast = $true
    $maxCombinations = 256

    foreach ($key in $Config.Keys) {
        switch ($key) {
            'include'          { $include = $Config[$key] }
            'exclude'          { $exclude = $Config[$key] }
            'max-parallel'     { $maxParallel = $Config[$key] }
            'fail-fast'        { $failFast = $Config[$key] }
            'max-combinations' { $maxCombinations = $Config[$key] }
            default            { $dimensions[$key] = $Config[$key] }
        }
    }

    if ($dimensions.Count -eq 0) {
        throw "Config must contain at least one matrix dimension."
    }

    foreach ($key in $dimensions.Keys) {
        $arr = @($dimensions[$key])
        if ($arr.Count -eq 0) {
            throw "Dimension '$key' is empty. Each dimension must have at least one value."
        }
    }

    $product = 1
    foreach ($key in $dimensions.Keys) {
        $product *= @($dimensions[$key]).Count
    }
    if ($product -gt $maxCombinations) {
        throw "Matrix size $product exceeds max-combinations limit of $maxCombinations."
    }

    $matrix = [ordered]@{}
    foreach ($key in ($dimensions.Keys | Sort-Object)) {
        $matrix[$key] = @($dimensions[$key])
    }
    if ($include) { $matrix['include'] = @($include) }
    if ($exclude) { $matrix['exclude'] = @($exclude) }

    $output = [ordered]@{
        'fail-fast' = $failFast
        'matrix'    = $matrix
    }
    if ($null -ne $maxParallel) {
        $output['max-parallel'] = $maxParallel
    }

    return ($output | ConvertTo-Json -Depth 10 -Compress:$false)
}
