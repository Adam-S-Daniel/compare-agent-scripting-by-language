# MatrixGenerator.psm1
# Generates a GitHub Actions strategy.matrix from a structured config.
# Supports cartesian expansion across axes, exclude rules (full and partial-key
# match), include rules (appended as additional matrix entries), max-parallel
# and fail-fast strategy options, and a max-size guard to prevent runaway
# matrices.

Set-StrictMode -Version 3.0

function ConvertTo-Hashtable {
    # Normalize PSCustomObject (from ConvertFrom-Json) into hashtable form so
    # the rest of the module only deals with one shape.
    param([Parameter(ValueFromPipeline)] $InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        # Pipeline output is what survives hashtable assignment; we use
        # `Write-Output -NoEnumerate` to keep single-element arrays from
        # being unwrapped to scalars.
        if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.IDictionary]) {
            $h = [ordered]@{}
            foreach ($k in $InputObject.Keys) {
                $h[$k] = ConvertTo-Hashtable $InputObject[$k]
            }
            return ,$h
        }
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $h = [ordered]@{}
            foreach ($p in $InputObject.PSObject.Properties) {
                $h[$p.Name] = ConvertTo-Hashtable $p.Value
            }
            return ,$h
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $arr = [System.Collections.ArrayList]::new()
            foreach ($item in $InputObject) {
                [void]$arr.Add((ConvertTo-Hashtable $item))
            }
            return ,@($arr.ToArray())
        }
        return $InputObject
    }
}

function Get-CartesianProduct {
    # Expand axes into all combinations. Returns an array of ordered hashtables.
    param([System.Collections.IDictionary] $Axes)

    $keys = @($Axes.Keys)
    if ($keys.Count -eq 0) { return @() }

    # Validate each axis is a list.
    foreach ($k in $keys) {
        $v = $Axes[$k]
        if ($v -is [string] -or -not ($v -is [System.Collections.IEnumerable])) {
            throw "Axis '$k' must be an array of values, got: $($v.GetType().Name)"
        }
    }

    $combos = [System.Collections.ArrayList]::new()
    [void]$combos.Add([ordered]@{})
    foreach ($k in $keys) {
        $values = @($Axes[$k])
        $next = [System.Collections.ArrayList]::new()
        foreach ($combo in $combos) {
            foreach ($v in $values) {
                $copy = [ordered]@{}
                foreach ($ek in $combo.Keys) { $copy[$ek] = $combo[$ek] }
                $copy[$k] = $v
                [void]$next.Add($copy)
            }
        }
        $combos = $next
    }
    return ,@($combos.ToArray())
}

function Test-ComboMatchesRule {
    # A combo matches an exclude/include rule when every key the rule names is
    # present and equal in the combo (partial match — empty rule matches all).
    param(
        [System.Collections.IDictionary] $Combo,
        [System.Collections.IDictionary] $Rule
    )
    foreach ($k in $Rule.Keys) {
        if (-not $Combo.Contains($k)) { return $false }
        if ($Combo[$k] -ne $Rule[$k]) { return $false }
    }
    return $true
}

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Config
    )

    $cfg = ConvertTo-Hashtable $Config
    if (-not $cfg.Contains('axes')) {
        throw "Config is missing required key 'axes'."
    }

    $axes = $cfg['axes']
    if ($null -eq $axes) { $axes = [ordered]@{} }

    $combos = [System.Collections.ArrayList]::new()
    foreach ($c in (Get-CartesianProduct -Axes $axes)) { [void]$combos.Add($c) }

    # Apply exclude rules.
    if ($cfg.Contains('exclude') -and $null -ne $cfg['exclude']) {
        foreach ($rule in @($cfg['exclude'])) {
            $kept = [System.Collections.ArrayList]::new()
            foreach ($combo in $combos) {
                if (-not (Test-ComboMatchesRule -Combo $combo -Rule $rule)) {
                    [void]$kept.Add($combo)
                }
            }
            $combos = $kept
        }
    }

    # Append include entries verbatim.
    if ($cfg.Contains('include') -and $null -ne $cfg['include']) {
        foreach ($extra in @($cfg['include'])) {
            [void]$combos.Add($extra)
        }
    }

    # Validate against max-size before returning.
    if ($cfg.Contains('max-size') -and $null -ne $cfg['max-size']) {
        $max = [int]$cfg['max-size']
        $size = $combos.Count
        if ($size -gt $max) {
            throw "Generated matrix size ($size) exceeds max-size ($max)."
        }
    }

    # Build the result with strategy options. Force include to an array so
    # ConvertTo-Json emits `[ ... ]` even for a single entry.
    $includeArray = @($combos.ToArray())
    $result = [ordered]@{
        matrix = [ordered]@{ include = $includeArray }
    }

    $failFast = $true
    if ($cfg.Contains('fail-fast')) { $failFast = [bool]$cfg['fail-fast'] }
    $result['fail-fast'] = $failFast

    if ($cfg.Contains('max-parallel') -and $null -ne $cfg['max-parallel']) {
        $result['max-parallel'] = [int]$cfg['max-parallel']
    }

    # Convert to PSCustomObject so dotted-property access works in tests/output.
    return [pscustomobject]$result
}

function ConvertTo-MatrixJson {
    param(
        [Parameter(Mandatory)] $Matrix,
        [int] $Depth = 10,
        [switch] $Compress
    )
    return ($Matrix | ConvertTo-Json -Depth $Depth -Compress:$Compress)
}

function Invoke-MatrixGenerator {
    # Entry-point driver: read a JSON config from disk, return matrix JSON.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [switch] $Compress
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8
    try {
        $config = $raw | ConvertFrom-Json -Depth 20
    } catch {
        throw "Failed to parse config JSON at '$ConfigPath': $($_.Exception.Message)"
    }
    $matrix = New-BuildMatrix -Config $config
    return ConvertTo-MatrixJson -Matrix $matrix -Compress:$Compress
}

Export-ModuleMember -Function New-BuildMatrix, ConvertTo-MatrixJson, Invoke-MatrixGenerator
