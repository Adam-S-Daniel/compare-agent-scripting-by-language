# MatrixGenerator: build a GitHub Actions strategy.matrix from a config.
#
# A config has:
#   axes        - hashtable of axis-name -> array of values (cartesian product)
#   include     - optional array of extra combinations appended verbatim
#   exclude     - optional array of partial-match filters; combinations whose
#                 named keys all match are removed
#   max_parallel- optional int -> emitted as max-parallel
#   fail_fast   - optional bool, default $true -> emitted as fail-fast
#   max_size    - optional int; throws if generated matrix exceeds this

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertFrom-AxisHashtable {
    param([object]$Axes)
    # Normalise to an ordered dictionary so output is deterministic.
    if ($Axes -is [System.Collections.Specialized.OrderedDictionary]) { return $Axes }
    $ordered = [ordered]@{}
    foreach ($key in ($Axes.Keys | Sort-Object)) { $ordered[$key] = $Axes[$key] }
    return $ordered
}

function Get-CartesianProduct {
    param([System.Collections.Specialized.OrderedDictionary]$Axes)
    $combinations = @([ordered]@{})
    foreach ($key in $Axes.Keys) {
        $values = @($Axes[$key])
        $next = New-Object System.Collections.Generic.List[object]
        foreach ($combo in $combinations) {
            foreach ($v in $values) {
                $copy = [ordered]@{}
                foreach ($k in $combo.Keys) { $copy[$k] = $combo[$k] }
                $copy[$key] = $v
                $next.Add($copy)
            }
        }
        $combinations = $next.ToArray()
    }
    return $combinations
}

function Test-ExcludeMatches {
    param($Combo, $ExcludeRule)
    foreach ($k in $ExcludeRule.Keys) {
        if (-not $Combo.Contains($k)) { return $false }
        if ($Combo[$k] -ne $ExcludeRule[$k]) { return $false }
    }
    return $true
}

function ConvertTo-OrderedHashtable {
    param($InputObject)
    $h = [ordered]@{}
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($k in $InputObject.Keys) { $h[[string]$k] = $InputObject[$k] }
    } else {
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = $p.Value }
    }
    return $h
}

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Config
    )

    if (-not ($Config.Contains('axes'))) {
        throw "Config is missing required 'axes' key"
    }
    $axes = ConvertFrom-AxisHashtable $Config['axes']
    if ($axes.Count -eq 0) { throw "'axes' must define at least one axis" }
    foreach ($k in $axes.Keys) {
        if (@($axes[$k]).Count -eq 0) { throw "Axis '$k' is empty" }
    }

    # Cartesian product, then drop excludes, then append includes.
    $combos = Get-CartesianProduct $axes

    if ($Config.Contains('exclude') -and $null -ne $Config['exclude']) {
        $rules = @($Config['exclude'] | ForEach-Object { ConvertTo-OrderedHashtable $_ })
        $combos = @($combos | Where-Object {
            $combo = $_
            -not ($rules | Where-Object { Test-ExcludeMatches $combo $_ } | Select-Object -First 1)
        })
    }

    if ($Config.Contains('include') -and $null -ne $Config['include']) {
        $extra = @($Config['include'] | ForEach-Object { ConvertTo-OrderedHashtable $_ })
        $combos = @($combos) + @($extra)
    }

    $size = @($combos).Count
    if ($Config.Contains('max_size') -and $size -gt [int]$Config['max_size']) {
        throw "Generated matrix size $size exceeds max_size $($Config['max_size'])"
    }

    # Convert each combo (OrderedDictionary) to PSCustomObject so JSON keys stay
    # as object properties rather than a dictionary serialisation.
    $includeArr = @($combos | ForEach-Object { [pscustomobject]$_ })

    $matrixObj = [pscustomobject][ordered]@{ include = $includeArr }
    $resultProps = [ordered]@{ matrix = $matrixObj }

    if ($Config.Contains('fail_fast')) {
        $resultProps['fail-fast'] = [bool]$Config['fail_fast']
    } else {
        $resultProps['fail-fast'] = $true
    }
    if ($Config.Contains('max_parallel')) {
        $resultProps['max-parallel'] = [int]$Config['max_parallel']
    }
    return [pscustomobject]$resultProps
}

function ConvertTo-MatrixJson {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)] $Matrix)
    process {
        $Matrix | ConvertTo-Json -Depth 10
    }
}

function Read-MatrixConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Config file not found: $Path" }
    $raw = Get-Content -LiteralPath $Path -Raw
    $obj = $raw | ConvertFrom-Json -AsHashtable
    return $obj
}

Export-ModuleMember -Function New-BuildMatrix, ConvertTo-MatrixJson, Read-MatrixConfig
