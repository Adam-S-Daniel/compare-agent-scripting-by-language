<#
.SYNOPSIS
  Generate a GitHub Actions strategy.matrix JSON from a declarative config.

.DESCRIPTION
  Takes a config with axes (os, language_version, feature_flags, ...),
  plus include/exclude rules, fail_fast, max_parallel, and max_size.
  Emits a PSCustomObject shaped like a GitHub Actions `strategy` block:

      {
        "matrix":       { os: [...], language_version: [...], include: [...], exclude: [...] },
        "fail-fast":    <bool>,
        "max-parallel": <int>
      }

  The size of the matrix is the product of axis lengths, minus excludes
  that match an existing cartesian combination, plus includes. If the
  computed size exceeds `max_size` the function throws.
#>

Set-StrictMode -Version Latest

# Reserved top-level config keys that are NOT matrix axes.
$script:ReservedKeys = @('include', 'exclude', 'fail_fast', 'max_parallel', 'max_size')

function ConvertTo-Hashtable {
    # JSON objects deserialize to PSCustomObject; convert recursively to hashtables
    # so axis values are plain arrays/hashtables easy to iterate.
    param([Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        # Primitives (incl. strings) pass through untouched.
        if ($InputObject -is [string] -or $InputObject -is [ValueType]) { return $InputObject }
        if ($InputObject -is [System.Collections.IDictionary]) {
            $h = @{}
            foreach ($k in $InputObject.Keys) { $h[$k] = ConvertTo-Hashtable $InputObject[$k] }
            return $h
        }
        if ($InputObject -is [pscustomobject]) {
            $h = @{}
            foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
            return $h
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            return @($InputObject | ForEach-Object { ConvertTo-Hashtable $_ })
        }
        return $InputObject
    }
}

function Get-MatrixAxes {
    # Extract user-defined axes (everything except reserved keys) in insertion-ish order.
    param([hashtable]$Config)
    $axes = [ordered]@{}
    foreach ($key in $Config.Keys) {
        if ($script:ReservedKeys -notcontains $key) {
            $axes[$key] = @($Config[$key])
        }
    }
    return $axes
}

function Test-ExcludeMatches {
    # True if every key in $exclude matches the corresponding value in $combo.
    param([hashtable]$Combo, [hashtable]$Exclude)
    foreach ($k in $Exclude.Keys) {
        if (-not $Combo.ContainsKey($k)) { return $false }
        if ($Combo[$k] -ne $Exclude[$k]) { return $false }
    }
    return $true
}

function Get-CartesianProduct {
    # Returns an array of hashtables: every combination of axis values.
    param([System.Collections.Specialized.OrderedDictionary]$Axes)
    $result = @(@{})
    foreach ($axisName in $Axes.Keys) {
        $next = @()
        foreach ($partial in $result) {
            foreach ($value in $Axes[$axisName]) {
                $copy = @{} + $partial
                $copy[$axisName] = $value
                $next += $copy
            }
        }
        $result = $next
    }
    return , $result
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
      Build the matrix object from a config hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Convert include/exclude entries (if any) to hashtables defensively.
    $includes = @()
    if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        $includes = @($Config['include'] | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    $excludes = @()
    if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        $excludes = @($Config['exclude'] | ForEach-Object { ConvertTo-Hashtable $_ })
    }

    $axes = Get-MatrixAxes -Config $Config

    if ($axes.Count -eq 0 -and $includes.Count -eq 0) {
        throw "Invalid config: provide at least one axis or an include entry."
    }

    if ($Config.ContainsKey('max_parallel')) {
        $mp = [int]$Config['max_parallel']
        if ($mp -le 0) { throw "Invalid config: max_parallel must be a positive integer, got $mp." }
    }

    # Compute size: cartesian - applicable excludes + includes.
    $cartesianSize = 1
    foreach ($name in $axes.Keys) { $cartesianSize *= $axes[$name].Count }
    if ($axes.Count -eq 0) { $cartesianSize = 0 }

    $excludedCount = 0
    if ($excludes.Count -gt 0 -and $axes.Count -gt 0) {
        $cart = Get-CartesianProduct -Axes $axes
        foreach ($combo in $cart) {
            foreach ($ex in $excludes) {
                if (Test-ExcludeMatches -Combo $combo -Exclude $ex) {
                    $excludedCount++
                    break
                }
            }
        }
    }

    $size = $cartesianSize - $excludedCount + $includes.Count

    if ($Config.ContainsKey('max_size')) {
        $maxSize = [int]$Config['max_size']
        if ($size -gt $maxSize) {
            throw "Matrix size ($size) exceeds max_size ($maxSize)."
        }
    }

    # Build matrix object (ordered) with axes, then include/exclude.
    $matrix = [ordered]@{}
    foreach ($name in $axes.Keys) { $matrix[$name] = $axes[$name] }
    if ($includes.Count -gt 0) { $matrix['include'] = $includes }
    if ($excludes.Count -gt 0) { $matrix['exclude'] = $excludes }

    $out = [ordered]@{ matrix = $matrix }
    if ($Config.ContainsKey('fail_fast')) { $out['fail-fast'] = [bool]$Config['fail_fast'] }
    if ($Config.ContainsKey('max_parallel')) { $out['max-parallel'] = [int]$Config['max_parallel'] }
    $out['size'] = $size

    return [pscustomobject]$out
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
      Serialize a matrix object to GitHub-Actions-compatible JSON.
      Drops the informational `size` field.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)]$Matrix)
    process {
        # Copy without size
        $copy = [ordered]@{}
        foreach ($p in $Matrix.PSObject.Properties) {
            if ($p.Name -ne 'size') { $copy[$p.Name] = $p.Value }
        }
        return ([pscustomobject]$copy | ConvertTo-Json -Depth 10)
    }
}

function Invoke-MatrixGenerator {
    <#
    .SYNOPSIS
      CLI entry point: read a JSON config file, emit matrix JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $parsed = $raw | ConvertFrom-Json
    } catch {
        throw "Config file is not valid JSON ($ConfigPath): $($_.Exception.Message)"
    }
    $cfg = ConvertTo-Hashtable $parsed
    $matrix = New-BuildMatrix -Config $cfg
    return (ConvertTo-MatrixJson -Matrix $matrix)
}

# Allow running directly: `pwsh MatrixGenerator.ps1 <config.json>`
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -ge 1) {
        Invoke-MatrixGenerator -ConfigPath $args[0]
    }
}
