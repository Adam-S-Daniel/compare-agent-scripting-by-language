# MatrixGenerator.psm1
#
# Generates GitHub Actions strategy matrices from a structured config.
#
# Approach:
#   - The config describes "dimensions" (axes) as a map of name -> array of values.
#   - We compute the full cartesian product of those dimensions.
#   - `exclude` rules remove any combination whose keys all match the rule.
#     (Partial rules match broadly, mirroring GitHub Actions semantics.)
#   - `include` rules append extra combinations (possibly with extra keys
#     not present in the base dimensions).
#   - `max_size` caps the total combination count and raises a descriptive
#     error if exceeded (prevents accidental explosions from large products).
#   - `fail_fast` and `max_parallel` are echoed into the output so the caller
#     can splice them straight into `strategy:` in a workflow.
#
# The output shape, after ConvertTo-Json, is:
#
#   {
#     "matrix":      { "include": [ {...}, {...} ] },
#     "fail-fast":   true,
#     "max-parallel": 4,    // only present when > 0
#     "total":       12
#   }
#
# Downstream workflows can consume it via fromJson(outputs.matrix).include.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Builds a GitHub Actions strategy matrix from a config hashtable.
    .PARAMETER Config
        A hashtable (typically loaded from JSON via ConvertFrom-Json -AsHashtable)
        with keys: dimensions (required), include, exclude, fail_fast,
        max_parallel, max_size.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # --- Validate dimensions --------------------------------------------------
    if (-not $Config.ContainsKey('dimensions') -or $null -eq $Config.dimensions) {
        throw "Configuration must include a 'dimensions' section with at least one axis."
    }

    $dimensions = $Config.dimensions
    if ($dimensions -isnot [hashtable] -and $dimensions -isnot [System.Collections.IDictionary]) {
        throw "'dimensions' must be a mapping of axis names to arrays of values."
    }
    if ($dimensions.Keys.Count -eq 0) {
        throw "'dimensions' must contain at least one axis."
    }

    foreach ($axis in @($dimensions.Keys)) {
        $values = @($dimensions[$axis])
        if ($values.Count -eq 0) {
            throw "Dimension '$axis' has no values; every axis needs at least one value."
        }
    }

    # --- Build the cartesian product ----------------------------------------
    $combinations = Get-CartesianProduct -Dimensions $dimensions

    # --- Apply exclude filters ----------------------------------------------
    if ($Config.ContainsKey('exclude') -and $Config.exclude) {
        $excludeRules = @($Config.exclude)
        if ($excludeRules.Count -gt 0) {
            $combinations = @(
                $combinations | Where-Object {
                    -not (Test-MatchesAnyRule -Combination $_ -Rules $excludeRules)
                }
            )
        }
    }

    # --- Apply include rules (append as new combinations) ------------------
    if ($Config.ContainsKey('include') -and $Config.include) {
        $includeRules = @($Config.include)
        foreach ($rule in $includeRules) {
            $clone = [ordered]@{}
            foreach ($k in @($rule.Keys)) { $clone[$k] = $rule[$k] }
            $combinations = @($combinations) + ,$clone
        }
    }

    $combinations = @($combinations)

    # --- Size validation -----------------------------------------------------
    $maxSize = if ($Config.ContainsKey('max_size')) { [int]$Config.max_size } else { 256 }
    if ($combinations.Count -gt $maxSize) {
        throw "Matrix size $($combinations.Count) exceeds maximum allowed size $maxSize. Tighten dimensions or raise max_size."
    }

    # --- Assemble the result -------------------------------------------------
    $failFast = if ($Config.ContainsKey('fail_fast')) { [bool]$Config.fail_fast } else { $true }
    $result = [ordered]@{
        matrix       = [ordered]@{ include = $combinations }
        'fail-fast'  = $failFast
        total        = $combinations.Count
    }

    if ($Config.ContainsKey('max_parallel')) {
        $maxParallel = [int]$Config.max_parallel
        if ($maxParallel -gt 0) { $result['max-parallel'] = $maxParallel }
    }

    return $result
}

function Get-CartesianProduct {
    <#
    .SYNOPSIS
        Returns the cartesian product of a dimensions hashtable as an array
        of ordered hashtables (one per combination).
    #>
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Dimensions
    )

    # Seed with a single empty combination, then fold each axis in.
    $product = @([ordered]@{})
    foreach ($axis in @($Dimensions.Keys)) {
        $values = @($Dimensions[$axis])
        $next = @()
        foreach ($existing in $product) {
            foreach ($v in $values) {
                $clone = [ordered]@{}
                foreach ($k in @($existing.Keys)) { $clone[$k] = $existing[$k] }
                $clone[$axis] = $v
                $next += ,$clone
            }
        }
        $product = $next
    }
    return $product
}

function Test-MatchesAnyRule {
    <#
    .SYNOPSIS
        Returns $true if $Combination matches any of the provided $Rules.
        A rule matches when every key in the rule exists in the combination
        with an equal value. Partial rules match broadly.
    #>
    param(
        [Parameter(Mandatory)] $Combination,
        [Parameter(Mandatory)] [array]$Rules
    )
    foreach ($rule in $Rules) {
        $matchesThis = $true
        foreach ($k in @($rule.Keys)) {
            if (-not $Combination.Contains($k)) { $matchesThis = $false; break }
            if ($Combination[$k] -ne $rule[$k]) { $matchesThis = $false; break }
        }
        if ($matchesThis) { return $true }
    }
    return $false
}

Export-ModuleMember -Function New-BuildMatrix, Get-CartesianProduct, Test-MatchesAnyRule
