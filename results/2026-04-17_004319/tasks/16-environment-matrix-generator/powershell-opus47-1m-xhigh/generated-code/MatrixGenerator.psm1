# MatrixGenerator.psm1
#
# Generates a GitHub Actions strategy.matrix from a configuration describing
# dimensions (os, version, feature flags), plus optional include/exclude
# rules, max-parallel, fail-fast, and a maximum-size guard.
#
# Public functions:
#   Get-MatrixCombinations  - cartesian product over dimension arrays
#   Test-ExcludeMatch       - predicate: does a rule match a combination?
#   New-BuildMatrix         - assemble the final matrix object (hashtable)
#   Invoke-MatrixGenerator  - end-to-end: JSON in, JSON out
#
# Design notes:
# - We emit include-only matrices (i.e. a flat list of explicit combos under
#   'include') rather than raw dimension arrays. GitHub Actions supports this
#   form and it avoids surprises when excludes/includes interact.
# - Exclude rules use GitHub's subset-match semantics: a rule matches a combo
#   when every key in the rule is present in the combo with an equal value.
# - OrderedDictionary is IEnumerable, so any function returning one must wrap
#   with the unary comma operator ("return ,$x") or use Write-Output
#   -NoEnumerate — otherwise PowerShell's pipeline flattens it into a stream
#   of DictionaryEntry objects on the way out.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function ConvertTo-OrderedHashtable {
    # Normalize PSCustomObject or hashtable into an ordered hashtable so the
    # rest of the pipeline can rely on uniform types. Caller receives a single
    # IDictionary, not an enumerated sequence of DictionaryEntry objects.
    param([Parameter(Mandatory)] $InputObject)

    $result = [ordered]@{}
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($k in $InputObject.Keys) { $result[$k] = $InputObject[$k] }
    } elseif ($InputObject -is [psobject]) {
        foreach ($p in $InputObject.PSObject.Properties) { $result[$p.Name] = $p.Value }
    } else {
        throw "Cannot convert $($InputObject.GetType().FullName) to ordered hashtable"
    }

    # The unary comma prevents pipeline enumeration of the OrderedDictionary.
    return ,$result
}

function Get-MatrixCombinations {
    <#
    .SYNOPSIS
    Returns the cartesian product of the values in each dimension as an array
    of ordered hashtables (one per combination).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Dimensions
    )

    if ($Dimensions.Count -eq 0) {
        return @()
    }

    # Stable key ordering for deterministic output.
    $keys = @($Dimensions.Keys)

    # Seed with a single empty combination; fold each dimension in turn.
    $combos = [System.Collections.Generic.List[object]]::new()
    $combos.Add([ordered]@{}) | Out-Null

    foreach ($key in $keys) {
        $values = @($Dimensions[$key])
        $next = [System.Collections.Generic.List[object]]::new()
        foreach ($combo in $combos) {
            foreach ($value in $values) {
                $new = [ordered]@{}
                foreach ($k in $combo.Keys) { $new[$k] = $combo[$k] }
                $new[$key] = $value
                $next.Add($new) | Out-Null
            }
        }
        $combos = $next
    }

    # Return as a plain object[] array — the caller can re-wrap with @().
    # We intentionally DO NOT use `,` here, because we want the outer pipeline
    # to see an array of ordered hashtables, not a single array-wrapped item.
    return $combos.ToArray()
}

function Test-ExcludeMatch {
    <#
    .SYNOPSIS
    Returns $true if every key in $Rule exists in $Combination with the same
    value. Matches GitHub Actions' partial-key exclude semantics.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Combination,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Rule
    )

    if ($Rule.Count -eq 0) { return $false }

    foreach ($k in $Rule.Keys) {
        if (-not $Combination.Contains($k)) { return $false }
        if ($Combination[$k] -ne $Rule[$k]) { return $false }
    }
    return $true
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
    Build a matrix result object from a configuration hashtable.

    .DESCRIPTION
    Returns an ordered hashtable with keys:
      matrix        : @{ include = @(...) }
      max-parallel  : (optional) integer
      fail-fast     : boolean (default $true)
      size          : integer count of final combos

    Throws on invalid input and when size exceeds maxSize.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Config
    )

    if (-not $Config.Contains('dimensions')) {
        throw 'Configuration must include "dimensions" key.'
    }

    $dims = $Config['dimensions']
    if (-not ($dims -is [System.Collections.IDictionary])) {
        $dims = ConvertTo-OrderedHashtable -InputObject $dims
    }
    if ($dims.Count -eq 0) {
        throw 'Configuration must define at least one dimension.'
    }

    # Step 1: cartesian product.
    $combos = @(Get-MatrixCombinations -Dimensions $dims)

    # Step 2: apply excludes using an explicit loop to avoid pipeline
    # enumeration surprises with IDictionary.
    if ($Config.Contains('exclude') -and $null -ne $Config['exclude']) {
        $rules = foreach ($r in $Config['exclude']) {
            ConvertTo-OrderedHashtable -InputObject $r
        }
        $rules = @($rules)

        $kept = [System.Collections.Generic.List[object]]::new()
        foreach ($combo in $combos) {
            $matched = $false
            foreach ($rule in $rules) {
                if (Test-ExcludeMatch -Combination $combo -Rule $rule) {
                    $matched = $true
                    break
                }
            }
            if (-not $matched) { $kept.Add($combo) | Out-Null }
        }
        $combos = $kept.ToArray()
    }

    # Step 3: append includes (each is added verbatim; no product expansion).
    if ($Config.Contains('include') -and $null -ne $Config['include']) {
        $with = [System.Collections.Generic.List[object]]::new()
        foreach ($c in $combos) { $with.Add($c) | Out-Null }
        foreach ($inc in $Config['include']) {
            $with.Add((ConvertTo-OrderedHashtable -InputObject $inc)) | Out-Null
        }
        $combos = $with.ToArray()
    }

    # Step 4: size validation. maxSize defaults to 256 (GitHub Actions' cap).
    $maxSize = if ($Config.Contains('maxSize')) { [int]$Config['maxSize'] } else { 256 }
    if ($combos.Count -gt $maxSize) {
        throw "Matrix size $($combos.Count) exceeds maximum size $maxSize."
    }

    # Step 5: assemble result. Use an ordered hashtable so JSON output
    # preserves key ordering.
    $result = [ordered]@{}
    $inner  = [ordered]@{ include = $combos }
    $result['matrix'] = $inner

    if ($Config.Contains('maxParallel') -and $null -ne $Config['maxParallel']) {
        $result['max-parallel'] = [int]$Config['maxParallel']
    }

    # fail-fast defaults to $true (GitHub's default).
    $failFast = if ($Config.Contains('failFast')) { [bool]$Config['failFast'] } else { $true }
    $result['fail-fast'] = $failFast

    $result['size'] = $combos.Count

    # Wrap with `,` to prevent pipeline enumeration of the OrderedDictionary.
    return ,$result
}

function Invoke-MatrixGenerator {
    <#
    .SYNOPSIS
    End-to-end entrypoint: takes a JSON config string (or path) and returns
    JSON output text.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Json')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Json')] [string] $Json,
        [Parameter(Mandatory, ParameterSetName = 'Path')] [string] $Path,
        [int] $JsonDepth = 10
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Config file not found: $Path"
        }
        $Json = Get-Content -LiteralPath $Path -Raw
    }

    try {
        $parsed = $Json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    } catch {
        throw "Invalid JSON input: $($_.Exception.Message)"
    }

    if (-not ($parsed -is [System.Collections.IDictionary])) {
        throw 'Top-level JSON must be an object.'
    }

    $result = New-BuildMatrix -Config $parsed
    return ($result | ConvertTo-Json -Depth $JsonDepth)
}

Export-ModuleMember -Function `
    Get-MatrixCombinations, `
    Test-ExcludeMatch, `
    New-BuildMatrix, `
    Invoke-MatrixGenerator
