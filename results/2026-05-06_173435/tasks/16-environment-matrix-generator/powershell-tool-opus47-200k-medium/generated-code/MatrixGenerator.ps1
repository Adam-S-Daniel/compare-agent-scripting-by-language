# MatrixGenerator.ps1
# Build a GitHub Actions strategy.matrix from a high-level config (axes,
# include, exclude, max-parallel, fail-fast, max-size). The shape mirrors
# what GHA accepts so the JSON output can be dropped straight into
# `strategy: { matrix: <here> }` (with max-parallel/fail-fast siblings).

Set-StrictMode -Version Latest

# Convert any input (PSCustomObject from JSON, hashtable, ordered dict) into
# a plain hashtable so the rest of the code can treat keys uniformly.
function ConvertTo-Hashtable {
    param([Parameter(Mandatory)] $InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [hashtable]) { return $InputObject }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in $InputObject.Keys) { $h[$k] = $InputObject[$k] }
        return $h
    }
    if ($InputObject -is [pscustomobject]) {
        $h = @{}
        foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = $p.Value }
        return $h
    }
    return $InputObject
}

# Cartesian product of axes -> list of hashtables, one per combination.
function Expand-Axes {
    param([hashtable] $Axes)
    if (-not $Axes -or $Axes.Count -eq 0) { return @() }

    $combos = @(@{})
    foreach ($key in $Axes.Keys) {
        $values = @($Axes[$key])
        if ($values.Count -eq 0) { continue }
        $next = @()
        foreach ($combo in $combos) {
            foreach ($v in $values) {
                if ($null -eq $v) {
                    throw "Axis '$key' contains a null value, which is not allowed."
                }
                $clone = @{}
                foreach ($k in $combo.Keys) { $clone[$k] = $combo[$k] }
                $clone[$key] = $v
                $next += ,$clone
            }
        }
        $combos = $next
    }
    return ,$combos
}

# True iff every key/value in $rule is present and equal in $combo.
function Test-RuleMatchesCombo {
    param([hashtable] $Combo, [hashtable] $Rule)
    foreach ($k in $Rule.Keys) {
        if (-not $Combo.ContainsKey($k)) { return $false }
        if ($Combo[$k] -ne $Rule[$k]) { return $false }
    }
    return $true
}

# Apply GHA include semantics: if every key in the include entry that's also
# an axis matches an existing combo, add the extra (non-axis) keys to that
# combo. Otherwise append the include entry as a fresh standalone combination.
function Add-Includes {
    param([System.Collections.Generic.List[hashtable]] $Combos, [array] $Includes, [string[]] $AxisKeys)
    foreach ($incRaw in $Includes) {
        $inc = ConvertTo-Hashtable $incRaw
        $axisPart  = @{}
        $extraPart = @{}
        foreach ($k in $inc.Keys) {
            if ($AxisKeys -contains $k) { $axisPart[$k] = $inc[$k] }
            else                        { $extraPart[$k] = $inc[$k] }
        }

        $extended = $false
        if ($axisPart.Count -gt 0 -and $extraPart.Count -gt 0) {
            foreach ($combo in $Combos) {
                if (Test-RuleMatchesCombo -Combo $combo -Rule $axisPart) {
                    foreach ($k in $extraPart.Keys) { $combo[$k] = $extraPart[$k] }
                    $extended = $true
                }
            }
        }
        if (-not $extended) {
            $clone = @{}
            foreach ($k in $inc.Keys) { $clone[$k] = $inc[$k] }
            $Combos.Add($clone)
        }
    }
}

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Config
    )

    $cfg = ConvertTo-Hashtable $Config

    # Axes can come in as either a nested 'axes' map or as top-level scalars
    # alongside include/exclude/max-parallel/fail-fast. We normalize to 'axes'.
    $reserved = @('axes','include','exclude','max-parallel','fail-fast','max-size')
    $axes = @{}
    if ($cfg.ContainsKey('axes') -and $cfg.axes) {
        $axesRaw = ConvertTo-Hashtable $cfg.axes
        foreach ($k in $axesRaw.Keys) { $axes[$k] = @($axesRaw[$k]) }
    } else {
        foreach ($k in $cfg.Keys) {
            if ($reserved -notcontains $k) { $axes[$k] = @($cfg[$k]) }
        }
    }

    $combosArr = Expand-Axes -Axes $axes
    $combos = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($c in $combosArr) { $combos.Add($c) }

    # Excludes drop any combo where every key in the rule matches.
    if ($cfg.ContainsKey('exclude') -and $cfg.exclude) {
        $excludes = @($cfg.exclude)
        $kept = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($combo in $combos) {
            $drop = $false
            foreach ($exRaw in $excludes) {
                $ex = ConvertTo-Hashtable $exRaw
                if (Test-RuleMatchesCombo -Combo $combo -Rule $ex) { $drop = $true; break }
            }
            if (-not $drop) { $kept.Add($combo) }
        }
        $combos = $kept
    }

    if ($cfg.ContainsKey('include') -and $cfg.include) {
        Add-Includes -Combos $combos -Includes @($cfg.include) -AxisKeys @($axes.Keys)
    }

    if ($cfg.ContainsKey('max-size') -and $cfg.'max-size') {
        $maxSize = [int] $cfg.'max-size'
        if ($combos.Count -gt $maxSize) {
            throw "Generated matrix size $($combos.Count) exceeds max-size $maxSize."
        }
    }

    $failFast = $true
    if ($cfg.ContainsKey('fail-fast')) { $failFast = [bool] $cfg.'fail-fast' }

    $result = [ordered]@{
        matrix      = [ordered]@{ include = @($combos) }
        'fail-fast' = $failFast
    }
    if ($cfg.ContainsKey('max-parallel') -and $null -ne $cfg.'max-parallel') {
        $result['max-parallel'] = [int] $cfg.'max-parallel'
    }
    return $result
}

function Invoke-MatrixGeneration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [string] $OutputPath
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON in '$ConfigPath': $($_.Exception.Message)"
    }
    $matrix = New-BuildMatrix -Config $config
    $json = $matrix | ConvertTo-Json -Depth 10
    if ($OutputPath) { Set-Content -LiteralPath $OutputPath -Value $json }
    return $json
}

# CLI entry point - only fires when the file is invoked directly, not dot-sourced.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -ge 1) {
        $configPath = $args[0]
        $outputPath = if ($args.Count -ge 2) { $args[1] } else { $null }
        Invoke-MatrixGeneration -ConfigPath $configPath -OutputPath $outputPath
    }
}
