# MatrixGenerator — build a GitHub Actions strategy.matrix from a config.
#
# The config is a hashtable / object with:
#   axes         hashtable: axis name -> array of values (cartesian product inputs)
#   include      array of hashtables: extra entries (or augmentations of product entries)
#   exclude      array of hashtables: subsets to remove from the product
#   max-parallel integer passed through to strategy.max-parallel
#   fail-fast    boolean passed through to strategy.fail-fast (default: $true)
#   max-size     integer; throws if resulting matrix exceeds this

Set-StrictMode -Version Latest

function _AsHashtable {
    param($obj)
    if ($null -eq $obj) { return $null }
    if ($obj -is [hashtable]) { return $obj }
    # PSCustomObject (from ConvertFrom-Json) -> hashtable
    $h = @{}
    foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}

function _GetOrDefault {
    param($h, [string]$key, $default)
    if ($h -is [hashtable]) {
        if ($h.ContainsKey($key)) { return $h[$key] }
    } elseif ($h.PSObject.Properties.Name -contains $key) {
        return $h.$key
    }
    return $default
}

function _CartesianProduct {
    # Given ordered axis-name list and axis values, return an array of ordered hashtables.
    param([string[]]$Names, [hashtable]$Axes)
    $result = ,(@{})
    foreach ($name in $Names) {
        $next = @()
        foreach ($partial in $result) {
            foreach ($value in $Axes[$name]) {
                $combo = @{} + $partial
                $combo[$name] = $value
                $next += ,$combo
            }
        }
        $result = $next
    }
    return ,$result
}

function _EntriesMatch {
    # True when $subset's keys/values are all present in $entry.
    param([hashtable]$Entry, [hashtable]$Subset)
    foreach ($k in $Subset.Keys) {
        if (-not $Entry.ContainsKey($k)) { return $false }
        if ($Entry[$k] -ne $Subset[$k]) { return $false }
    }
    return $true
}

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Config
    )

    $cfg = _AsHashtable $Config

    # Validate axes
    if (-not ($cfg.ContainsKey('axes'))) {
        throw "Config is missing required 'axes' property."
    }
    $axes = _AsHashtable $cfg['axes']
    if ($axes.Keys.Count -eq 0) {
        throw "Config 'axes' must contain at least one axis."
    }
    foreach ($k in @($axes.Keys)) {
        $axes[$k] = @($axes[$k])  # coerce to array
        if ($axes[$k].Count -eq 0) {
            throw "Axis '$k' is empty; every axis must have at least one value."
        }
    }

    # 1. Cartesian product of all axes
    $names = @($axes.Keys | Sort-Object)
    $entries = [System.Collections.Generic.List[hashtable]]@()
    foreach ($e in (_CartesianProduct -Names $names -Axes $axes)) {
        $entries.Add([hashtable]$e) | Out-Null
    }

    # 2. Apply excludes
    $excludes = _GetOrDefault $cfg 'exclude' @()
    if ($excludes) {
        foreach ($ex in $excludes) {
            $exH = _AsHashtable $ex
            $kept = [System.Collections.Generic.List[hashtable]]@()
            foreach ($entry in $entries) {
                if (-not (_EntriesMatch -Entry $entry -Subset $exH)) {
                    $kept.Add($entry) | Out-Null
                }
            }
            $entries = $kept
        }
    }

    # 3. Apply includes. If an include matches an existing product entry on axis values,
    #    merge extra properties onto it; otherwise append as a new entry.
    $includes = _GetOrDefault $cfg 'include' @()
    if ($includes) {
        foreach ($inc in $includes) {
            $incH = _AsHashtable $inc
            $axisPart = @{}
            foreach ($n in $names) {
                if ($incH.ContainsKey($n)) { $axisPart[$n] = $incH[$n] }
            }

            $merged = $false
            if ($axisPart.Keys.Count -eq $names.Count) {
                foreach ($entry in $entries) {
                    if (_EntriesMatch -Entry $entry -Subset $axisPart) {
                        foreach ($k in $incH.Keys) { $entry[$k] = $incH[$k] }
                        $merged = $true
                        break
                    }
                }
            }
            if (-not $merged) {
                $entries.Add([hashtable]$incH) | Out-Null
            }
        }
    }

    # 4. Size validation
    $maxSize = _GetOrDefault $cfg 'max-size' 0
    if ($maxSize -gt 0 -and $entries.Count -gt $maxSize) {
        throw "Matrix size $($entries.Count) exceeds max-size of $maxSize."
    }

    # 5. Assemble result object
    $failFast   = _GetOrDefault $cfg 'fail-fast'    $true
    $maxPar     = _GetOrDefault $cfg 'max-parallel' $null

    # Convert entries to PSCustomObjects so consumers can use $entry.os without
    # hitting hashtable pitfalls (e.g. .Count returning the key count).
    $entryObjects = @($entries | ForEach-Object { [pscustomobject]$_ })

    $result = [ordered]@{
        matrix       = [ordered]@{ include = $entryObjects }
        'fail-fast'  = [bool]$failFast
    }
    if ($null -ne $maxPar) { $result['max-parallel'] = [int]$maxPar }

    return [pscustomobject]$result
}

function ConvertTo-MatrixJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $Matrix,
        [int]$Depth = 8
    )
    process {
        $Matrix | ConvertTo-Json -Depth $Depth -Compress:$false
    }
}

function Invoke-MatrixGenerator {
    # CLI entry: read a JSON config file, write matrix JSON to stdout.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ConfigPath
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $cfg = $raw | ConvertFrom-Json -AsHashtable
    } catch {
        throw "Invalid JSON in ${ConfigPath}: $($_.Exception.Message)"
    }
    New-BuildMatrix -Config $cfg | ConvertTo-MatrixJson
}

Export-ModuleMember -Function New-BuildMatrix, ConvertTo-MatrixJson, Invoke-MatrixGenerator
