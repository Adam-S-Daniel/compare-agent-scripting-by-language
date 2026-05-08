#Requires -Version 7

# MatrixGenerator: build a GitHub Actions strategy.matrix from a config object.
#
# Approach: take a hashtable describing matrix axes plus optional include /
# exclude / fail_fast / max_parallel / max_size keys, expand the cartesian
# product, apply excludes (partial filters allowed), apply includes with the
# documented GitHub Actions semantics (extend matching combos, otherwise add a
# new one), validate against max_size, and emit a strategy object whose JSON
# form is consumable by GitHub Actions matrix:.
#
# Reserved configuration keys (NOT treated as axes).
$script:ReservedConfigKeys = @('include', 'exclude', 'fail_fast', 'max_parallel', 'max_size')

function Read-MatrixConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        # AsHashtable so we get a real hashtable we can mutate / treat uniformly.
        $cfg = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON in '$Path': $($_.Exception.Message)"
    }

    if ($null -eq $cfg) {
        throw "Configuration file '$Path' is empty"
    }
    if ($cfg -isnot [hashtable]) {
        throw "Configuration root in '$Path' must be a JSON object"
    }
    return $cfg
}

function Get-MatrixAxis {
    # Split the config hashtable into (axes, options) so the rest of the
    # pipeline can treat each side cleanly.
    [CmdletBinding()]
    param([Parameter(Mandatory)] [hashtable] $Config)

    $axes = [ordered]@{}
    foreach ($key in $Config.Keys) {
        if ($key -in $script:ReservedConfigKeys) { continue }
        $values = @($Config[$key])
        if ($values.Count -eq 0) {
            throw "Axis '$key' has no values"
        }
        $axes[$key] = $values
    }
    return $axes
}

function Get-CartesianProduct {
    # Expand a hashtable of axisName -> values into the full list of combos.
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Axes)

    $axisNames = @($Axes.Keys)
    if ($axisNames.Count -eq 0) { return @() }

    # Seed with one empty combo, then layer each axis on top.
    $combos = @([ordered]@{})
    foreach ($name in $axisNames) {
        $values = @($Axes[$name])
        $next = New-Object System.Collections.Generic.List[object]
        foreach ($combo in $combos) {
            foreach ($value in $values) {
                $clone = [ordered]@{}
                foreach ($k in $combo.Keys) { $clone[$k] = $combo[$k] }
                $clone[$name] = $value
                $next.Add($clone) | Out-Null
            }
        }
        $combos = $next.ToArray()
    }
    return ,$combos
}

function Test-ComboMatchesFilter {
    # Returns $true when every key/value in the filter is present and equal in
    # the combo. Partial filters match (an exclude with only "os" matches every
    # combo with that os, regardless of other axis values).
    param(
        [Parameter(Mandatory)] $Combo,
        [Parameter(Mandatory)] $Filter
    )
    foreach ($key in $Filter.Keys) {
        if (-not $Combo.Contains($key)) { return $false }
        if ($Combo[$key] -ne $Filter[$key]) { return $false }
    }
    return $true
}

function Invoke-Excludes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        $Combos,
        $Excludes
    )
    if (-not $Excludes -or @($Excludes).Count -eq 0) { return ,$Combos }

    $kept = New-Object System.Collections.Generic.List[object]
    foreach ($combo in $Combos) {
        $excluded = $false
        foreach ($filter in $Excludes) {
            if (Test-ComboMatchesFilter -Combo $combo -Filter $filter) {
                $excluded = $true
                break
            }
        }
        if (-not $excluded) { $kept.Add($combo) | Out-Null }
    }
    return ,$kept.ToArray()
}

function Invoke-Includes {
    # GitHub Actions include semantics:
    #   1. Compute the cartesian product (and apply excludes) first.
    #   2. For each include, find existing combos whose AXIS keys all match
    #      the include's axis-key values. If any match, extend each matched
    #      combo with the include's NON-axis keys. Otherwise, add the include
    #      as a brand new combo.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        $Combos,
        $Includes,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        $AxisNames
    )
    if (-not $Includes -or @($Includes).Count -eq 0) { return ,$Combos }

    $list = New-Object System.Collections.Generic.List[object]
    foreach ($c in $Combos) { $list.Add($c) | Out-Null }

    foreach ($inc in $Includes) {
        $axisKeys  = @($inc.Keys | Where-Object { $AxisNames -contains $_ })
        $extraKeys = @($inc.Keys | Where-Object { $AxisNames -notcontains $_ })

        $extended = $false
        if ($axisKeys.Count -gt 0) {
            for ($i = 0; $i -lt $list.Count; $i++) {
                $combo = $list[$i]
                $allMatch = $true
                foreach ($k in $axisKeys) {
                    if (-not $combo.Contains($k) -or $combo[$k] -ne $inc[$k]) {
                        $allMatch = $false
                        break
                    }
                }
                if ($allMatch) {
                    foreach ($k in $extraKeys) {
                        $combo[$k] = $inc[$k]
                    }
                    $extended = $true
                }
            }
        }

        if (-not $extended) {
            # No matching combo (or no axis keys at all) -> add as a new combo.
            $newCombo = [ordered]@{}
            foreach ($k in $inc.Keys) { $newCombo[$k] = $inc[$k] }
            $list.Add($newCombo) | Out-Null
        }
    }
    return ,$list.ToArray()
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Build a GitHub Actions strategy object from a configuration hashtable.

    .DESCRIPTION
        Returns an [ordered] hashtable whose JSON form is consumable by GHA
        strategy.matrix. Includes the fully-expanded combination list under
        matrix.include and the strategy-level fail-fast / max-parallel keys.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    $axes = Get-MatrixAxis -Config $Config
    $axisNames = @($axes.Keys)

    $hasIncludes = $Config.Contains('include') -and @($Config['include']).Count -gt 0

    if ($axisNames.Count -eq 0 -and -not $hasIncludes) {
        throw "Configuration must define at least one matrix axis or an 'include' entry"
    }

    # Note: PowerShell collapses an else-returned @() to $null, so initialize
    # explicitly and only invoke the cartesian helper when there are axes.
    $combos = @()
    if ($axisNames.Count -gt 0) {
        $combos = Get-CartesianProduct -Axes $axes
    }

    $combos = Invoke-Excludes -Combos $combos -Excludes $Config['exclude']
    $combos = Invoke-Includes -Combos $combos -Includes $Config['include'] -AxisNames $axisNames

    if ($Config.Contains('max_size')) {
        $maxSize = [int]$Config['max_size']
        if (@($combos).Count -gt $maxSize) {
            throw "Matrix size $(@($combos).Count) exceeds max_size of $maxSize. Reduce axes or tighten exclude rules."
        }
    }

    $result = [ordered]@{}
    $result['fail-fast'] = if ($Config.Contains('fail_fast')) { [bool]$Config['fail_fast'] } else { $true }
    if ($Config.Contains('max_parallel')) {
        $result['max-parallel'] = [int]$Config['max_parallel']
    }
    $result['matrix'] = [ordered]@{
        include = @($combos)
    }
    return [pscustomobject]$result
}

function ConvertTo-MatrixJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Matrix,

        [int] $Depth = 10
    )
    process {
        return ($Matrix | ConvertTo-Json -Depth $Depth)
    }
}
