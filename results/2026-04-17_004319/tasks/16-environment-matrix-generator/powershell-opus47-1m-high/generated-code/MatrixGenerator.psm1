# MatrixGenerator.psm1
#
# Generates a GitHub Actions strategy.matrix object from a declarative config:
#   - cartesian product across N named dimensions (os, language version, feature flags, ...)
#   - include/exclude rules
#   - max-parallel + fail-fast strategy options
#   - max-size guard so a typo doesn't accidentally explode CI usage
#
# Public functions:
#   New-EnvironmentMatrix  - core builder, returns a PSCustomObject
#   ConvertTo-MatrixJson   - serialises that object as the strategy block GitHub Actions expects
#   Invoke-MatrixGeneration - load JSON config from disk and emit the JSON in one call

Set-StrictMode -Version Latest

function _Get-ConfigValue {
    # Helper: look up a key in either hashtable or PSCustomObject configs (we accept both
    # because Pester tests pass hashtables but JSON deserialises to PSCustomObject).
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name
    )
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $null
}

function _Test-HasKey {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $false }
    if ($Object -is [System.Collections.IDictionary]) { return $Object.Contains($Name) }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function _ConvertTo-Hashtable {
    # Normalise a record (hashtable or PSCustomObject) into a plain hashtable so we can
    # iterate keys uniformly when applying include/exclude rules.
    param($Record)
    if ($null -eq $Record) { return @{} }
    if ($Record -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in $Record.Keys) { $h[[string]$k] = $Record[$k] }
        return $h
    }
    $h = @{}
    foreach ($p in $Record.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}

function _Test-RuleMatches {
    # An exclude rule matches a combination if every key in the rule equals the
    # corresponding key in the combination. Keys not present in the rule are ignored
    # (this is the GitHub Actions semantics).
    param([hashtable]$Rule, [hashtable]$Combination)
    foreach ($k in $Rule.Keys) {
        if (-not $Combination.ContainsKey($k)) { return $false }
        if ([string]$Combination[$k] -ne [string]$Rule[$k]) { return $false }
    }
    return $true
}

function New-EnvironmentMatrix {
    <#
    .SYNOPSIS
    Build a strategy matrix from a config describing dimensions and rules.

    .DESCRIPTION
    Produces a PSCustomObject with:
      matrix       - hashtable of axis -> values (the dimensions)
      include      - array of extra combinations (passed through verbatim)
      exclude      - array of exclusion rules (passed through verbatim)
      combinations - the fully expanded list of combinations after include/exclude
      fail-fast    - optional bool
      max-parallel - optional int

    Validates max-size and rejects empty / malformed configs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Config
    )

    $dimensions = _Get-ConfigValue -Object $Config -Name 'dimensions'
    if ($null -eq $dimensions) {
        throw "Config must include a 'dimensions' object with at least one dimension."
    }

    # Normalise dimensions into an ordered hashtable so axis order is predictable
    # (matters for deterministic JSON output and stable test assertions).
    $dimMap = [ordered]@{}
    if ($dimensions -is [System.Collections.IDictionary]) {
        foreach ($k in $dimensions.Keys) { $dimMap[[string]$k] = @($dimensions[$k]) }
    } else {
        foreach ($p in $dimensions.PSObject.Properties) { $dimMap[$p.Name] = @($p.Value) }
    }

    if ($dimMap.Count -eq 0) {
        throw "Config must define at least one dimension (got an empty dimensions object)."
    }

    foreach ($axis in $dimMap.Keys) {
        if (@($dimMap[$axis]).Count -eq 0) {
            throw "Dimension '$axis' is empty; every dimension must have at least one value."
        }
    }

    # Cartesian product: start with [ {} ], then for each axis multiply the partial
    # combinations by the axis's values. Standard fold-style expansion.
    $combinations = @( @{} )
    foreach ($axis in $dimMap.Keys) {
        $next = New-Object System.Collections.Generic.List[hashtable]
        foreach ($partial in $combinations) {
            foreach ($value in $dimMap[$axis]) {
                $copy = @{}
                foreach ($k in $partial.Keys) { $copy[$k] = $partial[$k] }
                $copy[$axis] = $value
                $next.Add($copy) | Out-Null
            }
        }
        $combinations = $next.ToArray()
    }

    # Apply exclude rules. Even one matching rule removes the combination.
    $excludeRules = @()
    if (_Test-HasKey $Config 'exclude') {
        $excludeRaw = _Get-ConfigValue -Object $Config -Name 'exclude'
        if ($null -ne $excludeRaw) {
            $excludeRules = @($excludeRaw | ForEach-Object { _ConvertTo-Hashtable $_ })
        }
    }
    if ($excludeRules.Count -gt 0) {
        $combinations = @($combinations | Where-Object {
            $combo = $_
            $matched = $false
            foreach ($rule in $excludeRules) {
                if (_Test-RuleMatches -Rule $rule -Combination $combo) { $matched = $true; break }
            }
            -not $matched
        })
    }

    # Apply include rules: append each as a new combination. (GitHub Actions includes
    # can also merge into existing combinations when only one key is specified, but
    # the simple "append" form is enough for this generator and matches docs example.)
    $includeRules = @()
    if (_Test-HasKey $Config 'include') {
        $includeRaw = _Get-ConfigValue -Object $Config -Name 'include'
        if ($null -ne $includeRaw) {
            $includeRules = @($includeRaw | ForEach-Object { _ConvertTo-Hashtable $_ })
            foreach ($inc in $includeRules) { $combinations += , $inc }
        }
    }

    # Validate against max-size AFTER include/exclude — that's the real cost.
    if (_Test-HasKey $Config 'max-size') {
        $maxSize = [int](_Get-ConfigValue -Object $Config -Name 'max-size')
        if ($combinations.Count -gt $maxSize) {
            throw "Generated matrix has $($combinations.Count) combinations, which exceeds max-size=$maxSize."
        }
    }

    # Build the output object incrementally so optional strategy fields stay absent
    # when not configured (cleaner JSON, easier to assert on).
    $out = [ordered]@{
        matrix       = $dimMap
        include      = $includeRules
        exclude      = $excludeRules
        combinations = $combinations
    }

    if (_Test-HasKey $Config 'fail-fast') {
        $ff = _Get-ConfigValue -Object $Config -Name 'fail-fast'
        if ($ff -isnot [bool]) {
            throw "'fail-fast' must be a boolean (true/false), got: $ff"
        }
        $out['fail-fast'] = $ff
    }

    if (_Test-HasKey $Config 'max-parallel') {
        $mp = _Get-ConfigValue -Object $Config -Name 'max-parallel'
        # Accept any integer-valued numeric type (Int32 from PowerShell literals,
        # Int64 from JSON deserialisation, etc.). Reject strings, doubles, zero, negatives.
        $isInt = ($mp -is [int] -or $mp -is [long] -or $mp -is [short] -or $mp -is [byte])
        if (-not $isInt -or $mp -lt 1) {
            throw "'max-parallel' must be a positive integer, got: $mp"
        }
        $out['max-parallel'] = [int]$mp
    }

    return [pscustomobject]$out
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
    Serialise a matrix object as a GitHub Actions strategy block:
        { "strategy": { "matrix": { ... }, "fail-fast": ..., "max-parallel": ... } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Matrix,
        [int]$Depth = 8
    )

    # Build the matrix sub-object. Always include axis arrays; only attach
    # include/exclude when they are non-empty (mirrors how engineers usually
    # hand-write workflow files).
    $matrixBlock = [ordered]@{}
    foreach ($axis in $Matrix.matrix.Keys) {
        $matrixBlock[$axis] = @($Matrix.matrix[$axis])
    }
    if (@($Matrix.include).Count -gt 0) { $matrixBlock['include'] = @($Matrix.include) }
    if (@($Matrix.exclude).Count -gt 0) { $matrixBlock['exclude'] = @($Matrix.exclude) }

    $strategy = [ordered]@{ matrix = $matrixBlock }
    if ($Matrix.PSObject.Properties['fail-fast'])    { $strategy['fail-fast']    = $Matrix.'fail-fast' }
    if ($Matrix.PSObject.Properties['max-parallel']) { $strategy['max-parallel'] = $Matrix.'max-parallel' }

    return ([ordered]@{ strategy = $strategy } | ConvertTo-Json -Depth $Depth)
}

function Invoke-MatrixGeneration {
    <#
    .SYNOPSIS
    End-to-end: read a JSON config file, build the matrix, return the JSON string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON config '$ConfigPath': $($_.Exception.Message)"
    }

    $matrix = New-EnvironmentMatrix -Config $config
    return (ConvertTo-MatrixJson -Matrix $matrix)
}

Export-ModuleMember -Function New-EnvironmentMatrix, ConvertTo-MatrixJson, Invoke-MatrixGeneration
