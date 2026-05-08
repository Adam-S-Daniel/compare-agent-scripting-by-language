<#
.SYNOPSIS
    Generates a GitHub Actions strategy.matrix object from a JSON config.

.DESCRIPTION
    Reads a config that describes:
        - axes: `os`, `versions` (named language versions), `features` (named flags)
        - mutators: `include` (additive) and `exclude` (filter)
        - strategy: `max_parallel`, `fail_fast`, `max_size` (validation cap)

    Computes the Cartesian product of the axes, applies excludes, then merges /
    appends includes the way GitHub Actions does (overlapping keys merge into
    matching combinations; otherwise add as a new combination). If the resulting
    matrix exceeds `max_size`, the script throws.

    Output is the JSON shape GitHub Actions expects (axis arrays + include +
    exclude, with `max-parallel` / `fail-fast` siblings) plus an integer `size`
    field for downstream sanity checks.

.PARAMETER ConfigPath
    Path to a JSON config file. Required when invoked as a script.

.PARAMETER OutputPath
    Optional path to write the generated matrix JSON. The JSON is also written
    to stdout regardless.

.EXAMPLE
    pwsh ./Generate-Matrix.ps1 -ConfigPath fixtures/basic.json
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$OutputPath
)

# --- helpers ----------------------------------------------------------------

# Load and parse a JSON config file into a hashtable. We use -AsHashtable so
# downstream code can treat axes / filters uniformly as hashtables.
function Get-MatrixConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }
    try {
        $raw = Get-Content -Raw -LiteralPath $Path
        return ($raw | ConvertFrom-Json -AsHashtable -Depth 32)
    } catch {
        throw "Failed to parse JSON config '$Path': $($_.Exception.Message)"
    }
}

# Returns $true when every key/value in $Filter is present in $Combination
# with the same value (string-compare). Used by both the exclude pass and
# the include "does this overlap an existing combination?" check.
function Test-CombinationMatchesFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Combination,
        [Parameter(Mandatory)][hashtable]$Filter
    )
    foreach ($key in $Filter.Keys) {
        if (-not $Combination.ContainsKey($key)) { return $false }
        # ConvertFrom-Json yields .NET primitives so direct -ne is fine for
        # strings/bools/ints. We normalise to string when types disagree to
        # avoid '20' vs 20 false negatives.
        $a = $Combination[$key]
        $b = $Filter[$key]
        if ($a -is [string] -or $b -is [string]) {
            if ([string]$a -ne [string]$b) { return $false }
        } elseif ($a -ne $b) {
            return $false
        }
    }
    return $true
}

# Build the Cartesian product of an ordered list of axes. Each axis is a
# single-key hashtable (name -> array of values). Returns an array of
# hashtable combinations.
function Get-CartesianProduct {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable[]]$Axes)

    $result = @( @{} )
    foreach ($axis in $Axes) {
        $name   = @($axis.Keys)[0]
        $values = @($axis[$name])
        $next   = @()
        foreach ($combo in $result) {
            foreach ($value in $values) {
                $newCombo = @{} + $combo
                $newCombo[$name] = $value
                $next += ,$newCombo
            }
        }
        $result = $next
    }
    return @($result)
}

# --- main entry point -------------------------------------------------------

function New-BuildMatrix {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Config)

    # 1. Collect axes in a stable order: os first, then named versions, then
    #    named features. The order matters only for the deterministic shape of
    #    the cartesian-product output (it doesn't change correctness).
    $axes = New-Object System.Collections.Generic.List[hashtable]

    if ($Config.ContainsKey('os')) {
        $values = @($Config['os'])
        if ($values.Count -eq 0) {
            throw "Axis 'os' must contain at least one value"
        }
        $axes.Add(@{ os = $values })
    }

    foreach ($groupName in @('versions', 'features')) {
        if (-not $Config.ContainsKey($groupName)) { continue }
        $group = $Config[$groupName]
        if ($null -eq $group) { continue }
        foreach ($k in $group.Keys) {
            $values = @($group[$k])
            if ($values.Count -eq 0) {
                throw "Axis '$groupName.$k' must contain at least one value"
            }
            $axes.Add(@{ $k = $values })
        }
    }

    if ($axes.Count -eq 0) {
        throw "Configuration must define at least one axis (os, versions, or features)"
    }

    # 2. Compute the base Cartesian product across all axes.
    $base = Get-CartesianProduct -Axes $axes.ToArray()

    # 3. Apply excludes. An exclude entry removes any combination whose values
    #    match the exclude on every key the exclude specifies.
    $excludeFilters = @()
    if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        foreach ($entry in @($Config['exclude'])) {
            if (-not ($entry -is [hashtable])) {
                throw "Each 'exclude' entry must be a JSON object; got: $($entry.GetType().Name)"
            }
            $excludeFilters += ,$entry
        }
    }

    $afterExclude = @()
    foreach ($combo in $base) {
        $skip = $false
        foreach ($filter in $excludeFilters) {
            if (Test-CombinationMatchesFilter -Combination $combo -Filter $filter) {
                $skip = $true
                break
            }
        }
        if (-not $skip) { $afterExclude += ,$combo }
    }

    # 4. Apply includes. The GitHub Actions semantics we mirror:
    #      * If the include's overlap with axis keys matches an existing
    #        combination, MERGE the include's extra keys into that combination.
    #      * Otherwise, append the include as a new combination.
    $axisKeys = @()
    foreach ($a in $axes) { $axisKeys += @($a.Keys) }

    $extraIncludes = @()
    if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        foreach ($entry in @($Config['include'])) {
            if (-not ($entry -is [hashtable])) {
                throw "Each 'include' entry must be a JSON object; got: $($entry.GetType().Name)"
            }

            $axisOverlap = @($entry.Keys | Where-Object { $axisKeys -contains $_ })

            $matched = $false
            $merged  = @()
            foreach ($combo in $afterExclude) {
                $allMatch = $axisOverlap.Count -gt 0
                foreach ($k in $axisOverlap) {
                    $a = $combo[$k]
                    $b = $entry[$k]
                    if ($a -is [string] -or $b -is [string]) {
                        if ([string]$a -ne [string]$b) { $allMatch = $false; break }
                    } elseif ($a -ne $b) { $allMatch = $false; break }
                }
                if ($allMatch) {
                    $newCombo = @{} + $combo
                    foreach ($k in $entry.Keys) { $newCombo[$k] = $entry[$k] }
                    $merged += ,$newCombo
                    $matched = $true
                } else {
                    $merged += ,$combo
                }
            }
            $afterExclude = $merged
            if (-not $matched) { $extraIncludes += ,$entry }
        }
    }

    $finalCombinations = @($afterExclude) + @($extraIncludes)
    $size = $finalCombinations.Count

    # 5. Validate against max_size before returning anything.
    if ($Config.ContainsKey('max_size')) {
        $maxSize = [int]$Config['max_size']
        if ($size -gt $maxSize) {
            throw "Generated matrix size ($size) exceeds maximum allowed ($maxSize)"
        }
    }

    # 6. Build the GitHub-Actions-shaped strategy object.
    $matrix = [ordered]@{}
    foreach ($axis in $axes) {
        $k = @($axis.Keys)[0]
        # Wrap with @() so single-element axes still serialize as JSON arrays.
        $matrix[$k] = @($axis[$k])
    }
    if ($Config.ContainsKey('include') -and @($Config['include']).Count -gt 0) {
        $matrix['include'] = @($Config['include'])
    }
    if ($Config.ContainsKey('exclude') -and @($Config['exclude']).Count -gt 0) {
        $matrix['exclude'] = @($Config['exclude'])
    }

    $result = [ordered]@{
        matrix = $matrix
        size   = $size
    }
    if ($Config.ContainsKey('max_parallel')) {
        $result['max-parallel'] = [int]$Config['max_parallel']
    }
    if ($Config.ContainsKey('fail_fast')) {
        $result['fail-fast'] = [bool]$Config['fail_fast']
    }

    return $result
}

# --- script entry point -----------------------------------------------------

# Detect "running as a script" vs "dot-sourced by Pester". When dot-sourced,
# $MyInvocation.InvocationName equals '.'.
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $ConfigPath) {
        Write-Error "ConfigPath is required when running this script directly."
        exit 2
    }
    try {
        $config = Get-MatrixConfig -Path $ConfigPath
        $matrix = New-BuildMatrix -Config $config
        $json   = $matrix | ConvertTo-Json -Depth 32
        if ($OutputPath) {
            Set-Content -LiteralPath $OutputPath -Value $json
        }
        Write-Output $json
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
