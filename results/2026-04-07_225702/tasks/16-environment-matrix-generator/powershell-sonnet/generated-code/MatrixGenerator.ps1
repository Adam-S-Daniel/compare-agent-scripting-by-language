# MatrixGenerator.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration hashtable.
#
# Approach:
#   1. Build the cartesian product of all axes in the config.
#   2. Remove any combination that matches an exclude rule (partial matches apply).
#   3. Append extra entries from include rules, skipping duplicates.
#   4. Validate the total count against MaxSize (default 256 — GitHub's limit).
#   5. Wrap in a strategy object with fail-fast / max-parallel settings.

# ---------------------------------------------------------------------------
# Helper: cartesian product of an arbitrary list of value arrays
# ---------------------------------------------------------------------------
function Get-CartesianProduct {
    param(
        [hashtable] $Axes   # key → array of values
    )

    $keys = @($Axes.Keys)

    # Seed with a single "empty" combination
    $result = @( @{} )

    # Iterate axes directly — avoids the pipeline-unrolling bug that would
    # occur if we tried to store an array-of-arrays via ForEach-Object.
    foreach ($key in $keys) {
        $vals    = @($Axes[$key])   # ensure array even if caller passed 1 item
        $newRows = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($existing in $result) {
            foreach ($v in $vals) {
                $row = @{}
                foreach ($k in $existing.Keys) { $row[$k] = $existing[$k] }
                $row[$key] = $v
                $newRows.Add($row)
            }
        }

        $result = $newRows.ToArray()
    }

    return $result
}

# ---------------------------------------------------------------------------
# Helper: check whether a combination matches a rule (partial hashtable match)
# ---------------------------------------------------------------------------
function Test-RuleMatch {
    param(
        [hashtable] $Combination,
        [hashtable] $Rule
    )

    foreach ($key in $Rule.Keys) {
        if (-not $Combination.ContainsKey($key)) { return $false }
        if ($Combination[$key] -ne $Rule[$key])   { return $false }
    }
    return $true
}

# ---------------------------------------------------------------------------
# Helper: check if two combinations are identical (same keys and values)
# ---------------------------------------------------------------------------
function Test-CombinationEquals {
    param(
        [hashtable] $A,
        [hashtable] $B
    )

    if ($A.Count -ne $B.Count) { return $false }
    foreach ($key in $A.Keys) {
        if (-not $B.ContainsKey($key))  { return $false }
        if ($A[$key] -ne $B[$key])      { return $false }
    }
    return $true
}

# ---------------------------------------------------------------------------
# Main function: New-BuildMatrix
# ---------------------------------------------------------------------------
function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix from a configuration object.

    .PARAMETER Config
        Hashtable of axis-name → array-of-values.
        Example: @{ os = @("ubuntu-latest","windows-latest"); python = @("3.10","3.11") }

    .PARAMETER Excludes
        Array of hashtables. Any combination that is a superset of an exclude entry
        is removed from the matrix.

    .PARAMETER Includes
        Array of hashtables added as extra entries (duplicates are skipped).

    .PARAMETER FailFast
        Maps to strategy.fail-fast. Defaults to $false.

    .PARAMETER MaxParallel
        Maps to strategy.max-parallel. Omitted from output when not set.

    .PARAMETER MaxSize
        Maximum allowed matrix entries. Throws if exceeded. Defaults to 256.

    .OUTPUTS
        Hashtable with keys 'strategy' and 'matrix'.
    #>
    param(
        [hashtable]   $Config,
        [hashtable[]] $Excludes    = @(),
        [hashtable[]] $Includes    = @(),
        [bool]        $FailFast    = $false,
        [int]         $MaxParallel = 0,       # 0 = not set
        [int]         $MaxSize     = 256
    )

    # --- 1. Build cartesian product ---
    $combinations = Get-CartesianProduct -Axes $Config

    # --- 2. Apply exclude rules ---
    if ($Excludes.Count -gt 0) {
        $combinations = $combinations | Where-Object {
            $combo    = $_
            $excluded = $false
            foreach ($rule in $Excludes) {
                if (Test-RuleMatch -Combination $combo -Rule $rule) {
                    $excluded = $true
                    break
                }
            }
            -not $excluded
        }
    }

    # Ensure we always have an array (Where-Object can return $null for empty)
    if ($null -eq $combinations) { $combinations = @() }
    $combinations = @($combinations)

    # --- 3. Append include extras (skip exact duplicates) ---
    foreach ($extra in $Includes) {
        $isDuplicate = $false
        foreach ($existing in $combinations) {
            if (Test-CombinationEquals -A $existing -B $extra) {
                $isDuplicate = $true
                break
            }
        }
        if (-not $isDuplicate) {
            $combinations += $extra
        }
    }

    # --- 4. Validate size ---
    $total = $combinations.Count
    if ($total -gt $MaxSize) {
        throw "Matrix size $total exceeds the maximum allowed size of $MaxSize."
    }

    # --- 5. Build strategy object ---
    $strategy = @{
        'fail-fast' = $FailFast
    }
    if ($MaxParallel -gt 0) {
        $strategy['max-parallel'] = $MaxParallel
    }

    return @{
        strategy = $strategy
        matrix   = @{
            include = $combinations
        }
    }
}

# ---------------------------------------------------------------------------
# Output helper: ConvertTo-MatrixJson
# ---------------------------------------------------------------------------
function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
        Serializes a matrix result to a JSON string suitable for GitHub Actions.

    .PARAMETER MatrixResult
        The hashtable returned by New-BuildMatrix.

    .PARAMETER Depth
        JSON serialisation depth. Defaults to 10.
    #>
    param(
        [hashtable] $MatrixResult,
        [int]       $Depth = 10
    )

    return $MatrixResult | ConvertTo-Json -Depth $Depth
}
