# MatrixGenerator.ps1
# Library of functions for generating GitHub Actions strategy.matrix configurations.
# Functions are pure so they are easy to test with Pester.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Expand-Matrix {
    <#
    .SYNOPSIS
    Expands a hashtable of dimension arrays into a cartesian product of combinations.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Dimensions
    )

    if ($Dimensions.Count -eq 0) {
        return ,@()
    }

    # Sort keys for deterministic output.
    $keys = @($Dimensions.Keys | Sort-Object)
    $combos = [System.Collections.Generic.List[hashtable]]::new()
    $combos.Add(@{})

    foreach ($key in $keys) {
        $values = @($Dimensions[$key])
        if ($values.Count -eq 0) {
            throw "Dimension '$key' has no values."
        }
        $next = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($combo in $combos) {
            foreach ($v in $values) {
                $new = @{}
                foreach ($k in $combo.Keys) { $new[$k] = $combo[$k] }
                $new[$key] = $v
                $next.Add($new)
            }
        }
        $combos = $next
    }

    Write-Output -NoEnumerate ([hashtable[]]$combos.ToArray())
}

function Test-ComboMatches {
    <#
    .SYNOPSIS
    Returns $true if every key in $Filter is present in $Combo with the same value.
    #>
    param(
        [Parameter(Mandatory)] $Combo,
        [Parameter(Mandatory)] $Filter
    )
    foreach ($k in $Filter.Keys) {
        if (-not $Combo.Contains($k)) { return $false }
        if ($Combo[$k] -ne $Filter[$k]) { return $false }
    }
    return $true
}

function Remove-ExcludedCombos {
    param(
        [Parameter(Mandatory)] [array]$Combos,
        [array]$Excludes
    )
    if (-not $Excludes -or $Excludes.Count -eq 0) { Write-Output -NoEnumerate ([hashtable[]]$Combos); return }
    $result = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($c in $Combos) {
        $skip = $false
        foreach ($x in $Excludes) {
            if (Test-ComboMatches -Combo $c -Filter $x) { $skip = $true; break }
        }
        if (-not $skip) { $result.Add($c) }
    }
    Write-Output -NoEnumerate ([hashtable[]]$result.ToArray())
}

function Add-IncludedCombos {
    <#
    .SYNOPSIS
    Applies GitHub-style include rules. An include either augments an existing combo
    (if every matching key matches and none of the added keys conflict) or is added
    as a brand-new combo when it does not match any existing entry.
    #>
    param(
        [Parameter(Mandatory)] [array]$Combos,
        [array]$Includes,
        [Parameter(Mandatory)] [string[]]$DimensionKeys
    )
    if (-not $Includes -or $Includes.Count -eq 0) { Write-Output -NoEnumerate ([hashtable[]]$Combos); return }

    # Work on a mutable list of hashtables so we can augment them.
    $list = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($c in $Combos) {
        $copy = @{}
        foreach ($k in $c.Keys) { $copy[$k] = $c[$k] }
        $list.Add($copy)
    }

    foreach ($inc in $Includes) {
        # Separate include keys into "matches an existing dimension" vs "new key".
        $matchKeys = @()
        $newKeys = @()
        foreach ($k in $inc.Keys) {
            if ($DimensionKeys -contains $k) { $matchKeys += $k } else { $newKeys += $k }
        }

        $matchedAny = $false
        for ($i = 0; $i -lt $list.Count; $i++) {
            $combo = $list[$i]
            $ok = $true
            foreach ($mk in $matchKeys) {
                if ($combo[$mk] -ne $inc[$mk]) { $ok = $false; break }
            }
            if (-not $ok) { continue }

            # Augment only if new keys don't conflict with existing values.
            $conflict = $false
            foreach ($nk in $newKeys) {
                if ($combo.Contains($nk) -and $combo[$nk] -ne $inc[$nk]) {
                    $conflict = $true; break
                }
            }
            if ($conflict) { continue }

            $matchedAny = $true
            foreach ($nk in $newKeys) { $combo[$nk] = $inc[$nk] }
        }

        if (-not $matchedAny) {
            # No existing combo matched — add the include as a stand-alone entry.
            $new = @{}
            foreach ($k in $inc.Keys) { $new[$k] = $inc[$k] }
            $list.Add($new)
        }
    }

    Write-Output -NoEnumerate ([hashtable[]]$list.ToArray())
}

function ConvertTo-PlainHashtable {
    param($obj)
    $h = [ordered]@{}
    if ($null -eq $obj) { return $h }
    if ($obj -is [hashtable] -or $obj -is [System.Collections.Specialized.OrderedDictionary]) {
        foreach ($k in $obj.Keys) { $h[$k] = $obj[$k] }
        return $h
    }
    # PSCustomObject
    foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
    Generate a build matrix from a configuration object.
    .DESCRIPTION
    Input: a hashtable with keys:
      dimensions  : hashtable of name -> array
      include     : array of hashtables (optional)
      exclude     : array of hashtables (optional)
      fail_fast   : bool (optional, default $true)
      max_parallel: int (optional)
      max_size    : int (optional) — throws if generated combos exceed this limit
    Output: PSCustomObject with 'fail-fast', 'max-parallel', 'matrix'.
    #>
    param(
        [Parameter(Mandatory)] [hashtable]$Config
    )

    if (-not $Config.Contains('dimensions')) {
        throw "Config must contain a 'dimensions' section."
    }
    $dims = ConvertTo-PlainHashtable $Config['dimensions']
    if ($dims.Count -eq 0) {
        throw "At least one dimension is required."
    }

    $includes = @()
    if ($Config.Contains('include') -and $Config['include']) {
        foreach ($i in $Config['include']) { $includes += (ConvertTo-PlainHashtable $i) }
    }
    $excludes = @()
    if ($Config.Contains('exclude') -and $Config['exclude']) {
        foreach ($x in $Config['exclude']) { $excludes += (ConvertTo-PlainHashtable $x) }
    }

    $failFast = $true
    if ($Config.Contains('fail_fast')) { $failFast = [bool]$Config['fail_fast'] }

    $maxParallel = $null
    if ($Config.Contains('max_parallel')) { $maxParallel = [int]$Config['max_parallel'] }

    $combos = Expand-Matrix -Dimensions $dims
    $combos = Remove-ExcludedCombos -Combos $combos -Excludes $excludes
    $combos = Add-IncludedCombos -Combos $combos -Includes $includes -DimensionKeys ([string[]]$dims.Keys)

    if ($Config.Contains('max_size') -and $null -ne $Config['max_size']) {
        $maxSize = [int]$Config['max_size']
        if ($combos.Count -gt $maxSize) {
            throw "Generated matrix size $($combos.Count) exceeds max_size $maxSize."
        }
    }

    # Build the GHA matrix object. The "matrix" sub-object contains dimensions,
    # plus native include/exclude arrays — but we've already resolved them, so
    # for the effective output we provide the final dimension values plus an
    # 'include' list that captures the resolved combos for clarity.
    $matrixOut = [ordered]@{}
    foreach ($k in ($dims.Keys | Sort-Object)) {
        $matrixOut[$k] = @($dims[$k])
    }
    if ($excludes.Count -gt 0) {
        $matrixOut['exclude'] = @($excludes | ForEach-Object { [pscustomobject]$_ })
    }
    if ($includes.Count -gt 0) {
        $matrixOut['include'] = @($includes | ForEach-Object { [pscustomobject]$_ })
    }

    $out = [ordered]@{
        'fail-fast'    = $failFast
        'matrix'       = [pscustomobject]$matrixOut
        'combinations' = @($combos | ForEach-Object { [pscustomobject]$_ })
        'count'        = $combos.Count
    }
    if ($null -ne $maxParallel) { $out['max-parallel'] = $maxParallel }

    return [pscustomobject]$out
}

function ConvertFrom-MatrixConfigFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    $obj = $raw | ConvertFrom-Json -AsHashtable
    return $obj
}
