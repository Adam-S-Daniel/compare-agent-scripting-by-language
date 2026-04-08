# MatrixGenerator.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration hashtable.
# Supports include/exclude rules, max-parallel, fail-fast, and size validation.

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generate a GitHub Actions strategy.matrix object from a configuration.
    .PARAMETER Config
        Hashtable whose keys are dimension names and values are arrays of options.
    .PARAMETER Include
        Array of hashtables for extra combinations to merge into the matrix.
    .PARAMETER Exclude
        Array of hashtables for combinations to remove from the matrix.
    .PARAMETER MaxParallel
        Maximum number of parallel jobs (maps to strategy.max-parallel).
    .PARAMETER FailFast
        Whether to cancel remaining jobs when one fails (maps to strategy.fail-fast).
    .PARAMETER MaxSize
        Maximum allowed number of matrix combinations. Defaults to 256 (GitHub's limit).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [hashtable[]]$Include = @(),

        [hashtable[]]$Exclude = @(),

        [int]$MaxParallel = 0,

        [Nullable[bool]]$FailFast = $null,

        [int]$MaxSize = 256
    )

    # ── Build the cartesian product of all dimensions ────────────────
    $dimensions = @($Config.Keys | Sort-Object)  # sort for determinism
    if ($dimensions.Count -eq 0) {
        throw "Config must contain at least one dimension."
    }

    # Start with a single empty combination, then cross with each dimension
    $combinations = @(@{})
    foreach ($dim in $dimensions) {
        $values = @($Config[$dim])
        if ($values.Count -eq 0) {
            throw "Dimension '$dim' has no values."
        }
        $newCombinations = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($combo in $combinations) {
            foreach ($val in $values) {
                $newCombo = @{}
                foreach ($k in $combo.Keys) { $newCombo[$k] = $combo[$k] }
                $newCombo[$dim] = $val
                $newCombinations.Add($newCombo)
            }
        }
        $combinations = $newCombinations
    }

    # ── Apply exclude rules ──────────────────────────────────────────
    if ($Exclude.Count -gt 0) {
        $combinations = @($combinations | Where-Object {
            $combo = $_
            $excluded = $false
            foreach ($rule in $Exclude) {
                $match = $true
                foreach ($key in $rule.Keys) {
                    if ($combo[$key] -ne $rule[$key]) {
                        $match = $false
                        break
                    }
                }
                if ($match) { $excluded = $true; break }
            }
            -not $excluded
        })
    }

    # ── Apply include rules (merge extra entries) ────────────────────
    foreach ($inc in $Include) {
        # Check if this include matches an existing combination (partial match)
        $matched = $false
        foreach ($combo in $combinations) {
            $isMatch = $true
            foreach ($key in $inc.Keys) {
                if ($combo.ContainsKey($key) -and $combo[$key] -ne $inc[$key]) {
                    $isMatch = $false
                    break
                }
            }
            if ($isMatch) {
                # Merge extra keys into the existing combination
                foreach ($key in $inc.Keys) {
                    $combo[$key] = $inc[$key]
                }
                $matched = $true
            }
        }
        if (-not $matched) {
            # No existing combo matched — add as a standalone entry
            $newCombo = @{}
            foreach ($key in $inc.Keys) { $newCombo[$key] = $inc[$key] }
            $combinations = @($combinations) + @($newCombo)
        }
    }

    # ── Validate matrix size ─────────────────────────────────────────
    if ($combinations.Count -gt $MaxSize) {
        throw "Matrix size $($combinations.Count) exceeds maximum allowed size of $MaxSize."
    }

    # ── Convert hashtables to PSCustomObjects for clean JSON output ───
    $includeList = @(foreach ($combo in $combinations) {
        $ordered = [ordered]@{}
        foreach ($key in ($combo.Keys | Sort-Object)) {
            $ordered[$key] = $combo[$key]
        }
        [PSCustomObject]$ordered
    })

    # ── Build the strategy object ────────────────────────────────────
    $strategy = @{
        matrix = @{
            include = $includeList
        }
    }

    if ($MaxParallel -gt 0) {
        $strategy["max-parallel"] = $MaxParallel
    }

    if ($null -ne $FailFast) {
        $strategy["fail-fast"] = [bool]$FailFast
    }

    return $strategy
}

function ConvertTo-MatrixJson {
    <#
    .SYNOPSIS
        Convenience wrapper: builds the matrix and returns JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [hashtable[]]$Include = @(),
        [hashtable[]]$Exclude = @(),
        [int]$MaxParallel = 0,
        [Nullable[bool]]$FailFast = $null,
        [int]$MaxSize = 256
    )

    $strategy = New-BuildMatrix @PSBoundParameters
    return ($strategy | ConvertTo-Json -Depth 10)
}
