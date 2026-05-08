#requires -Version 7.0
<#
    New-EnvironmentMatrix
    ---------------------
    Generates a GitHub Actions strategy.matrix from a declarative configuration.

    The configuration describes a set of axes (e.g. os, language version, feature
    flags) and optional include / exclude rules, plus strategy-level options like
    fail-fast and max-parallel. We expand the cartesian product of the axes,
    apply excludes, then apply includes (using GitHub's "extend or add" rule),
    validate the resulting size against a maximum, and emit a JSON document that
    can be consumed by `jobs.<id>.strategy: ${{ fromJson(...) }}`.

    Output shape:
        {
          "fail-fast":    <bool>,
          "max-parallel": <int>,
          "size":         <int>,
          "matrix": { "include": [ {<axis>: <value>, ...}, ... ] }
        }

    All structural errors (missing axes, oversize matrix, invalid JSON, ...) are
    raised as terminating errors with descriptive messages so callers can react.
#>

function Get-CartesianProduct {
    <#
        Cross-multiplies an ordered hashtable of axis -> array-of-values into a list
        of ordered hashtables, one per combination. The output preserves axis order.
    #>
    param([Parameter(Mandatory)] $Axes)

    $axisKeys = @($Axes.Keys)
    if ($axisKeys.Count -eq 0) { return @() }

    $combos = [System.Collections.Generic.List[object]]::new()
    $combos.Add([ordered]@{}) | Out-Null

    foreach ($key in $axisKeys) {
        $values = @($Axes[$key])
        $next = [System.Collections.Generic.List[object]]::new()
        foreach ($combo in $combos) {
            foreach ($value in $values) {
                $copy = [ordered]@{}
                foreach ($k in $combo.Keys) { $copy[$k] = $combo[$k] }
                $copy[$key] = $value
                $next.Add($copy) | Out-Null
            }
        }
        $combos = $next
    }
    # Return the array elements unrolled; the caller wraps with @(...) to recapture.
    # We avoid `,$combos.ToArray()` which triggers double-wrapping when re-collected.
    return $combos.ToArray()
}

function Test-RuleMatches {
    <#
        Returns $true if every key in $Rule exists in $Combination with an equal
        value. Used by both exclude and include "extend" semantics. Comparison is
        scalar equality (numbers, strings, booleans).
    #>
    param([Parameter(Mandatory)] $Combination, [Parameter(Mandatory)] $Rule)

    foreach ($key in $Rule.Keys) {
        if (-not $Combination.Contains($key)) { return $false }
        # Use -eq with explicit cast-to-string fallback for type-mixed numeric / string axes.
        if ("$($Combination[$key])" -ne "$($Rule[$key])") { return $false }
    }
    return $true
}

function New-EnvironmentMatrix {
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [object]$Configuration,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Json')]
        [string]$Json,

        # Hard ceiling for the expanded matrix. Configuration's "max-size" overrides this.
        [int]$MaxSize = 256
    )

    # --- Resolve configuration ---------------------------------------------------
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Configuration file not found: $Path"
        }
        $Json = Get-Content -LiteralPath $Path -Raw
    }
    if ($PSCmdlet.ParameterSetName -in @('Path', 'Json')) {
        try {
            $Configuration = $Json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            throw "Invalid configuration JSON: $($_.Exception.Message)"
        }
    }
    # Coerce non-dictionary input (typically a PSCustomObject from non-AsHashtable JSON parsing)
    # into a hashtable. We must check IDictionary FIRST because in PowerShell 7
    # `-is [pscustomobject]` is also true for OrderedHashtable, which would otherwise
    # send us down the wrong coercion path.
    if (-not ($Configuration -is [System.Collections.IDictionary])) {
        if ($Configuration -is [pscustomobject]) {
            $h = @{}
            foreach ($p in $Configuration.PSObject.Properties) { $h[$p.Name] = $p.Value }
            $Configuration = $h
        } else {
            throw "Configuration must be a hashtable or convertible JSON object."
        }
    }

    # --- Validate axes -----------------------------------------------------------
    if (-not $Configuration.Contains('axes')) {
        throw "Configuration must contain an 'axes' property."
    }
    $axes = $Configuration['axes']
    if (-not ($axes -is [System.Collections.IDictionary]) -and $axes -is [pscustomobject]) {
        $h = [ordered]@{}
        foreach ($p in $axes.PSObject.Properties) { $h[$p.Name] = $p.Value }
        $axes = $h
    }
    if (-not ($axes -is [System.Collections.IDictionary]) -or $axes.Count -eq 0) {
        throw "Configuration 'axes' must contain at least one axis with one or more values."
    }
    foreach ($key in @($axes.Keys)) {
        $vals = @($axes[$key])
        if ($vals.Count -eq 0) {
            throw "Axis '$key' must contain at least one value."
        }
    }

    # --- Cartesian product -------------------------------------------------------
    $combinations = @(Get-CartesianProduct -Axes $axes)

    # --- Apply excludes ----------------------------------------------------------
    $excludes = @()
    if ($Configuration.Contains('exclude') -and $Configuration['exclude']) {
        $excludes = @($Configuration['exclude'])
    }
    if ($excludes.Count -gt 0) {
        $combinations = @(
            $combinations | Where-Object {
                $combo = $_
                $isExcluded = $false
                foreach ($rule in $excludes) {
                    if (Test-RuleMatches -Combination $combo -Rule $rule) { $isExcluded = $true; break }
                }
                -not $isExcluded
            }
        )
    }

    # --- Apply includes ----------------------------------------------------------
    # GitHub Actions semantics: an include either extends every existing combination
    # whose axis values match (using only keys that ARE axis keys), or — if it doesn't
    # match any existing combination — gets added as a brand-new combination.
    $includes = @()
    if ($Configuration.Contains('include') -and $Configuration['include']) {
        $includes = @($Configuration['include'])
    }
    $axisKeySet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($k in $axes.Keys) { [void]$axisKeySet.Add([string]$k) }

    foreach ($inc in $includes) {
        # Split include keys into axis-key portion and extension portion.
        $axisFilter = [ordered]@{}
        $extension  = [ordered]@{}
        foreach ($k in $inc.Keys) {
            if ($axisKeySet.Contains([string]$k)) { $axisFilter[$k] = $inc[$k] }
            else { $extension[$k] = $inc[$k] }
        }

        $matchedAny = $false
        if ($axisFilter.Count -gt 0 -and $combinations.Count -gt 0) {
            for ($i = 0; $i -lt $combinations.Count; $i++) {
                if (Test-RuleMatches -Combination $combinations[$i] -Rule $axisFilter) {
                    $matchedAny = $true
                    foreach ($k in $extension.Keys) { $combinations[$i][$k] = $extension[$k] }
                }
            }
        }

        if (-not $matchedAny) {
            # New combination: copy the include verbatim, preserving order.
            $newCombo = [ordered]@{}
            foreach ($k in $inc.Keys) { $newCombo[$k] = $inc[$k] }
            $combinations = @($combinations) + ,$newCombo
        }
    }

    # --- Validate result ---------------------------------------------------------
    if ($combinations.Count -eq 0) {
        throw "Matrix is empty after applying excludes."
    }

    $effectiveMaxSize = $MaxSize
    if ($Configuration.Contains('max-size')) {
        try { $effectiveMaxSize = [int]$Configuration['max-size'] }
        catch { throw "Configuration 'max-size' must be an integer." }
    }
    if ($combinations.Count -gt $effectiveMaxSize) {
        throw "Matrix size ($($combinations.Count)) exceeds maximum allowed size ($effectiveMaxSize)."
    }

    # --- Emit JSON ---------------------------------------------------------------
    $failFast = $true
    if ($Configuration.Contains('fail-fast')) { $failFast = [bool]$Configuration['fail-fast'] }

    $maxParallel = $combinations.Count
    if ($Configuration.Contains('max-parallel')) {
        try { $maxParallel = [int]$Configuration['max-parallel'] }
        catch { throw "Configuration 'max-parallel' must be an integer." }
        if ($maxParallel -lt 1) { throw "Configuration 'max-parallel' must be >= 1." }
    }

    $payload = [ordered]@{
        'fail-fast'    = $failFast
        'max-parallel' = $maxParallel
        'size'         = $combinations.Count
        'matrix'       = [ordered]@{
            'include' = @($combinations)
        }
    }
    return ($payload | ConvertTo-Json -Depth 12 -Compress:$false)
}

# This file is intended to be dot-sourced; direct invocation is handled by the
# Invoke-MatrixGenerator.ps1 wrapper, not here.
