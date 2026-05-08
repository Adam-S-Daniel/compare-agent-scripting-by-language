# New-BuildMatrix.ps1
# Generates a GitHub Actions strategy.matrix JSON document from a configuration.
# Supports dimensions (os/version/feature-flags), include/exclude rules,
# max-parallel, fail-fast, and a maximum-size guard.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Hashtable {
    # Recursively convert PSCustomObject (from ConvertFrom-Json) into hashtable/array
    # so we can iterate keys uniformly. Pass-through for primitives.
    param($Object)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in $Object.Keys) { $h[$k] = ConvertTo-Hashtable $Object[$k] }
        return $h
    }
    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $h
    }
    if ($Object -is [System.Collections.IEnumerable] -and -not ($Object -is [string])) {
        return @($Object | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    return $Object
}

function Get-CartesianProduct {
    # Compute the Cartesian product over a hashtable of axis-name -> value-array.
    # Returns an array of ordered hashtables (one per combination).
    param([hashtable]$Axes)

    $keys = @($Axes.Keys)
    if ($keys.Count -eq 0) { return @() }

    $result = [System.Collections.Generic.List[object]]::new()
    $result.Add([ordered]@{})
    foreach ($key in $keys) {
        $values = @($Axes[$key])
        if ($values.Count -eq 0) {
            throw "Axis '$key' must have at least one value."
        }
        $next = [System.Collections.Generic.List[object]]::new()
        foreach ($combo in $result) {
            foreach ($v in $values) {
                $copy = [ordered]@{}
                foreach ($k in $combo.Keys) { $copy[$k] = $combo[$k] }
                $copy[$key] = $v
                $next.Add($copy)
            }
        }
        $result = $next
    }
    return ,$result.ToArray()
}

function Test-ExcludeMatch {
    # An exclude entry matches a combination iff every key in the exclude entry
    # exists in the combination AND the values are equal.
    param([System.Collections.IDictionary]$Combo, [System.Collections.IDictionary]$Exclude)
    foreach ($k in $Exclude.Keys) {
        if (-not $Combo.Contains($k)) { return $false }
        if ($Combo[$k] -ne $Exclude[$k]) { return $false }
    }
    return $true
}

function Expand-Matrix {
    # Apply GitHub Actions' include/exclude semantics to compute the realised
    # set of jobs. Used for size validation only — the emitted matrix keeps
    # the include/exclude lists intact for GitHub to process.
    #
    # Simplified rules:
    #   - Start with Cartesian product of axes.
    #   - Remove combinations that match any exclude entry.
    #   - For each include entry: if its axis-keys (the subset of keys that
    #     are also axis names) match an existing combination, that combination
    #     gets the extra include-only keys merged in (no new row). Otherwise,
    #     the include adds a brand-new row.
    param([hashtable]$Axes, [array]$Include, [array]$Exclude)

    $combos = Get-CartesianProduct -Axes $Axes
    if ($Exclude) {
        $combos = @($combos | Where-Object {
            $c = $_
            -not ($Exclude | Where-Object { Test-ExcludeMatch -Combo $c -Exclude $_ })
        })
    }
    if ($Include) {
        $axisKeys = @($Axes.Keys)
        foreach ($inc in $Include) {
            $incAxisKeys = @($inc.Keys | Where-Object { $axisKeys -contains $_ })
            $matched = $false
            if ($incAxisKeys.Count -gt 0) {
                foreach ($c in $combos) {
                    $isMatch = $true
                    foreach ($k in $incAxisKeys) {
                        if ($c[$k] -ne $inc[$k]) { $isMatch = $false; break }
                    }
                    if ($isMatch) {
                        foreach ($k in $inc.Keys) {
                            if ($axisKeys -notcontains $k) { $c[$k] = $inc[$k] }
                        }
                        $matched = $true
                    }
                }
            }
            if (-not $matched) {
                $newRow = [ordered]@{}
                foreach ($k in $inc.Keys) { $newRow[$k] = $inc[$k] }
                $combos = @($combos) + ,$newRow
            }
        }
    }
    return ,$combos
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generate a GitHub Actions strategy matrix JSON document.
    .PARAMETER Config
        Hashtable, PSCustomObject, or JSON-string describing the matrix.
        Recognised keys: os, versions, features (any axis names accepted),
        include, exclude, max-parallel, fail-fast, max-size.
        Reserved top-level keys (include/exclude/max-parallel/fail-fast/max-size)
        are not treated as axes.
    .PARAMETER MaxSize
        Optional override for the maximum number of jobs allowed. Falls back
        to Config.max-size, then to 256.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        $Config,
        [int]$MaxSize = -1
    )

    if ($Config -is [string]) {
        try { $Config = $Config | ConvertFrom-Json -Depth 50 }
        catch { throw "Config is not valid JSON: $($_.Exception.Message)" }
    }
    $cfg = ConvertTo-Hashtable $Config
    if ($null -eq $cfg -or -not ($cfg -is [System.Collections.IDictionary])) {
        throw "Config must be an object/hashtable describing the matrix."
    }

    $reserved = @('include', 'exclude', 'max-parallel', 'fail-fast', 'max-size')
    $axes = [ordered]@{}
    foreach ($k in $cfg.Keys) {
        if ($reserved -notcontains $k) { $axes[$k] = @($cfg[$k]) }
    }
    if ($axes.Count -eq 0 -and -not ($cfg.Contains('include') -and $cfg['include'])) {
        throw "Config must define at least one axis (or a non-empty 'include' list)."
    }

    $include = @()
    if ($cfg.Contains('include') -and $cfg['include']) { $include = @($cfg['include']) }
    $exclude = @()
    if ($cfg.Contains('exclude') -and $cfg['exclude']) { $exclude = @($cfg['exclude']) }

    $effectiveMax = if ($MaxSize -ge 0) { $MaxSize }
                    elseif ($cfg.Contains('max-size')) { [int]$cfg['max-size'] }
                    else { 256 }

    $expanded = Expand-Matrix -Axes ([hashtable]$axes) -Include $include -Exclude $exclude
    $size = @($expanded).Count

    if ($size -eq 0) {
        throw "Generated matrix is empty after applying include/exclude rules."
    }
    if ($size -gt $effectiveMax) {
        throw "Generated matrix size $size exceeds maximum allowed $effectiveMax."
    }

    # Build the strategy object. include/exclude only included if non-empty
    # (matches GitHub's expectations and keeps output tidy).
    $matrix = [ordered]@{}
    foreach ($k in $axes.Keys) { $matrix[$k] = @($axes[$k]) }
    if ($include.Count -gt 0) { $matrix['include'] = $include }
    if ($exclude.Count -gt 0) { $matrix['exclude'] = $exclude }

    $strategy = [ordered]@{ matrix = $matrix }
    if ($cfg.Contains('fail-fast'))    { $strategy['fail-fast']    = [bool]$cfg['fail-fast'] }
    if ($cfg.Contains('max-parallel')) { $strategy['max-parallel'] = [int]$cfg['max-parallel'] }
    $strategy['size'] = $size

    return $strategy
}

function Invoke-BuildMatrixCli {
    # Thin CLI wrapper: read JSON from -InputPath (or stdin), write JSON to
    # -OutputPath (or stdout). Designed for use from GitHub Actions / act.
    [CmdletBinding()]
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [int]$MaxSize = -1
    )

    $json = if ($InputPath) {
        if (-not (Test-Path -LiteralPath $InputPath)) {
            throw "Input file not found: $InputPath"
        }
        Get-Content -LiteralPath $InputPath -Raw
    } else {
        [Console]::In.ReadToEnd()
    }

    $strategy = New-BuildMatrix -Config $json -MaxSize $MaxSize
    $out = $strategy | ConvertTo-Json -Depth 20

    if ($OutputPath) { $out | Set-Content -LiteralPath $OutputPath -NoNewline }
    else { Write-Output $out }
    return $strategy
}

# Entry-point: when invoked as a script (not dot-sourced), run the CLI.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # Re-parse args manually (simple flag parser)
        $parsed = @{ InputPath = $null; OutputPath = $null; MaxSize = -1 }
        for ($i = 0; $i -lt $args.Count; $i++) {
            switch ($args[$i]) {
                '-InputPath'  { $parsed.InputPath  = $args[++$i] }
                '-OutputPath' { $parsed.OutputPath = $args[++$i] }
                '-MaxSize'    { $parsed.MaxSize    = [int]$args[++$i] }
                default       { throw "Unknown argument: $($args[$i])" }
            }
        }
        Invoke-BuildMatrixCli @parsed | Out-Null
    }
}
