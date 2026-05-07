# MatrixGenerator.psm1 — Environment Matrix Generator for GitHub Actions.
#
# Given a configuration (hashtable / parsed JSON) describing OS options,
# language versions, and feature flags, produce a fully-resolved build matrix
# suitable for `strategy.matrix` (after `fromJSON`) plus the surrounding
# strategy knobs (max-parallel, fail-fast).
#
# Public entry points:
#   New-BuildMatrix     -- compute resolved matrix from a config hashtable
#   ConvertTo-MatrixJson-- compact JSON for $GITHUB_OUTPUT consumption
#   Invoke-MatrixGenerator -- end-to-end CLI wrapper (file-in / file-out)
#
# GitHub Actions imposes a 256-job hard cap on a job's matrix expansion;
# we apply the same default and let callers tighten it via `max-size`.

Set-StrictMode -Version Latest

$script:DefaultMaxSize = 256

function _Get-AxesHashtable {
    # Normalize the `axes` block into a [hashtable]<string, string[]>.
    # Accept both PowerShell hashtables (from -Config) and PSCustomObjects
    # (from ConvertFrom-Json), and tolerate scalar values (turn them into
    # single-element arrays).
    param([Parameter(Mandatory)] $Axes)

    $result = [ordered]@{}
    if ($Axes -is [hashtable] -or $Axes -is [System.Collections.IDictionary]) {
        foreach ($k in $Axes.Keys) {
            $v = $Axes[$k]
            if ($null -eq $v) { $result[$k] = @() ; continue }
            $result[$k] = @($v | ForEach-Object { "$_" })
        }
    } elseif ($Axes -is [psobject]) {
        foreach ($p in $Axes.PSObject.Properties) {
            $v = $p.Value
            if ($null -eq $v) { $result[$p.Name] = @() ; continue }
            $result[$p.Name] = @($v | ForEach-Object { "$_" })
        }
    } else {
        throw "axes must be a mapping (hashtable or object), got [$($Axes.GetType().FullName)]"
    }
    return $result
}

function _Get-ListOfMaps {
    # Normalize an include / exclude list into [hashtable[]].
    # Returns the List<hashtable> object itself (NOT .ToArray()) so that
    # PowerShell's pipeline unrolling on single-element arrays does not
    # silently drop the .Count property at call sites.
    param($List)
    $out = New-Object System.Collections.Generic.List[hashtable]
    if ($null -eq $List) { return ,$out }
    foreach ($item in @($List)) {
        $h = @{}
        if ($item -is [hashtable] -or $item -is [System.Collections.IDictionary]) {
            foreach ($k in $item.Keys) {
                $v = $item[$k]
                if ($v -is [bool]) { $h[$k] = $v } else { $h[$k] = "$v" }
            }
        } elseif ($item -is [psobject]) {
            foreach ($p in $item.PSObject.Properties) {
                if ($p.Value -is [bool]) { $h[$p.Name] = $p.Value }
                else { $h[$p.Name] = "$($p.Value)" }
            }
        } else {
            throw "include/exclude entries must be objects, got [$($item.GetType().FullName)]"
        }
        $out.Add($h)
    }
    return ,$out
}

function _Test-ExcludeMatch {
    # An exclude rule matches a combination iff every key in the rule
    # equals the corresponding value in the combination. (GitHub semantics.)
    param([hashtable] $Combination, [hashtable] $Rule)
    foreach ($k in $Rule.Keys) {
        if (-not $Combination.ContainsKey($k))   { return $false }
        if ("$($Combination[$k])" -ne "$($Rule[$k])") { return $false }
    }
    return $true
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
    Resolve a matrix config into a list of concrete combinations.

    .PARAMETER Config
    Hashtable with keys:
      axes          : hashtable<string, string[]> of axis -> values
      include       : hashtable[] of extra combinations (appended)
      exclude       : hashtable[] of rules; combinations matching are removed
      max-parallel  : int (passed through verbatim)
      fail-fast     : bool (defaults to $true)
      max-size      : int (defaults to 256; throws if size exceeds)
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Config)

    if (-not ($Config -is [hashtable] -or $Config -is [System.Collections.IDictionary] -or $Config -is [psobject])) {
        throw "Config must be a hashtable or object."
    }

    # --- read axes (required) ---
    $axesRaw = if ($Config -is [psobject] -and -not ($Config -is [hashtable])) {
        $Config.PSObject.Properties['axes']?.Value
    } else { $Config['axes'] }
    if ($null -eq $axesRaw) { throw "Config is missing required 'axes' field." }
    $axes = _Get-AxesHashtable -Axes $axesRaw

    # --- cartesian product ---
    $combos = New-Object System.Collections.Generic.List[hashtable]
    $axisNames = @($axes.Keys)

    if ($axisNames.Count -eq 0) {
        # No axes -> empty matrix.
    } else {
        $hasEmpty = $false
        foreach ($n in $axisNames) {
            if ($axes[$n].Count -eq 0) { $hasEmpty = $true; break }
        }
        if (-not $hasEmpty) {
            $combos.Add(@{}) | Out-Null
            foreach ($name in $axisNames) {
                $next = New-Object System.Collections.Generic.List[hashtable]
                foreach ($acc in $combos) {
                    foreach ($val in $axes[$name]) {
                        $copy = @{}
                        foreach ($k in $acc.Keys) { $copy[$k] = $acc[$k] }
                        $copy[$name] = $val
                        $next.Add($copy) | Out-Null
                    }
                }
                $combos = $next
            }
        }
    }

    # --- exclude rules ---
    $excludeRules = if ($Config -is [psobject] -and -not ($Config -is [hashtable])) {
        $Config.PSObject.Properties['exclude']?.Value
    } else { $Config['exclude'] }
    $excludes = _Get-ListOfMaps -List $excludeRules
    if ($excludes.Count -gt 0) {
        $kept = New-Object System.Collections.Generic.List[hashtable]
        foreach ($c in $combos) {
            $skip = $false
            foreach ($r in $excludes) { if (_Test-ExcludeMatch -Combination $c -Rule $r) { $skip = $true; break } }
            if (-not $skip) { $kept.Add($c) | Out-Null }
        }
        $combos = $kept
    }

    # --- include rules: append as new combinations ---
    $includeRules = if ($Config -is [psobject] -and -not ($Config -is [hashtable])) {
        $Config.PSObject.Properties['include']?.Value
    } else { $Config['include'] }
    $includes = _Get-ListOfMaps -List $includeRules
    foreach ($extra in $includes) { $combos.Add($extra) | Out-Null }

    # --- max-size validation ---
    $maxSize = $script:DefaultMaxSize
    $cfgMax = if ($Config -is [psobject] -and -not ($Config -is [hashtable])) {
        $Config.PSObject.Properties['max-size']?.Value
    } else { $Config['max-size'] }
    if ($null -ne $cfgMax) { $maxSize = [int]$cfgMax }

    if ($combos.Count -gt $maxSize) {
        throw "Resolved matrix size ($($combos.Count)) exceeds max-size ($maxSize). Tighten exclude rules, prune axes, or raise max-size."
    }

    # --- strategy knobs ---
    $maxParallelRaw = if ($Config -is [psobject] -and -not ($Config -is [hashtable])) {
        $Config.PSObject.Properties['max-parallel']?.Value
    } else { $Config['max-parallel'] }
    $failFastRaw = if ($Config -is [psobject] -and -not ($Config -is [hashtable])) {
        $Config.PSObject.Properties['fail-fast']?.Value
    } else { $Config['fail-fast'] }

    $output = [ordered]@{
        include      = $combos.ToArray()
        'fail-fast'  = if ($null -eq $failFastRaw) { $true } else { [bool]$failFastRaw }
    }
    if ($null -ne $maxParallelRaw) { $output['max-parallel'] = [int]$maxParallelRaw }
    $output['size'] = $combos.Count
    return $output
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
    Serialize a resolved matrix to compact single-line JSON.

    Compact form is required for $GITHUB_OUTPUT consumption (each output
    must fit on one line of the file).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] $Matrix)
    return ($Matrix | ConvertTo-Json -Depth 10 -Compress)
}

function Invoke-MatrixGenerator {
    <#
    .SYNOPSIS
    File-in / file-out wrapper. Reads a JSON config, resolves the matrix,
    writes JSON to OutputPath, and emits the same JSON to stdout.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [Parameter(Mandatory)] [string] $OutputPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "config file not found: $ConfigPath"
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $cfg = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    } catch {
        throw "invalid JSON in config file '$ConfigPath': $($_.Exception.Message)"
    }

    $matrix = New-BuildMatrix -Config $cfg
    $json   = ConvertTo-MatrixJson -Matrix $matrix
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
    Write-Output $json
}

Export-ModuleMember -Function New-BuildMatrix, ConvertTo-MatrixJson, Invoke-MatrixGenerator
