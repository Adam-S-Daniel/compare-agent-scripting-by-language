# MatrixGenerator.psm1
# Environment Matrix Generator for GitHub Actions strategy.matrix
#
# Strict-mode PowerShell module following TDD red/green/refactor cycle.
# Each exported function is fully typed and declares OutputType.

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helper: compute Cartesian-product combination count for a config hashtable
# ---------------------------------------------------------------------------
function Get-CombinationCount {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    [int]$count = 1
    foreach ($key in $Config.Keys) {
        $values = $Config[$key]
        # Each dimension must have at least one value
        [int]$len = ([array]$values).Count
        $count = $count * $len
    }
    return $count
}

# ---------------------------------------------------------------------------
# Helper: determine how many combinations are removed by exclude rules.
# An exclude entry is a hashtable; a generated combination matches the entry
# if every key/value pair in the entry is present in the combination.
# ---------------------------------------------------------------------------
function Get-ExcludedCount {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Excludes
    )

    if ($Excludes.Count -eq 0) { return 0 }

    # Build all combinations as an array of hashtables
    [hashtable[]]$allCombos = @(Get-AllCombinations -Config $Config)

    [int]$excluded = 0
    foreach ($combo in $allCombos) {
        [bool]$matchedAny = $false
        foreach ($rule in $Excludes) {
            [bool]$matchesRule = $true
            foreach ($key in $rule.Keys) {
                if (-not $combo.ContainsKey([string]$key)) {
                    $matchesRule = $false
                    break
                }
                if ($combo[[string]$key] -ne $rule[$key]) {
                    $matchesRule = $false
                    break
                }
            }
            if ($matchesRule) {
                $matchedAny = $true
                break
            }
        }
        if ($matchedAny) { $excluded++ }
    }
    return $excluded
}

# ---------------------------------------------------------------------------
# Helper: enumerate every combination in the Cartesian product of Config.
# Returns an array of hashtables, each representing one combination.
# ---------------------------------------------------------------------------
function Get-AllCombinations {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Start with a single empty combination
    [hashtable[]]$combos = @(@{})

    foreach ($key in $Config.Keys) {
        [array]$values = [array]$Config[$key]
        [hashtable[]]$newCombos = @()

        foreach ($existing in $combos) {
            foreach ($value in $values) {
                # Clone the existing combination and add this dimension's value
                [hashtable]$next = @{}
                foreach ($k in $existing.Keys) {
                    $next[[string]$k] = $existing[$k]
                }
                $next[[string]$key] = $value
                $newCombos += $next
            }
        }
        $combos = $newCombos
    }

    return $combos
}

# ---------------------------------------------------------------------------
# New-BuildMatrix
# Main public function. Accepts a configuration hashtable and optional
# include/exclude rules, max-parallel, fail-fast, and size limit.
# Returns a PSCustomObject with the matrix structure and metadata.
# ---------------------------------------------------------------------------
function New-BuildMatrix {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # Dimensions to expand: each key is a dimension name, value is an array
        [Parameter(Mandatory)]
        [hashtable]$Config,

        # Extra entries added verbatim to matrix.include
        [Parameter()]
        [AllowEmptyCollection()]
        [hashtable[]]$Include = @(),

        # Combinations to suppress from the expanded matrix
        [Parameter()]
        [AllowEmptyCollection()]
        [hashtable[]]$Exclude = @(),

        # GitHub Actions strategy.max-parallel; omitted from output when not supplied
        # No default — absence detected via $PSBoundParameters
        [Parameter()]
        [int]$MaxParallel,

        # GitHub Actions strategy.fail-fast; omitted from output when not supplied
        [Parameter()]
        [bool]$FailFast,

        # Maximum allowed combination count (default 256, matching GHA limit)
        [Parameter()]
        [int]$MaxSize = 256
    )

    # ------ Input validation ------------------------------------------------

    if ($PSBoundParameters.ContainsKey('MaxParallel') -and $MaxParallel -le 0) {
        throw "MaxParallel must be a positive integer; got $MaxParallel."
    }

    if ($MaxSize -le 0) {
        throw "MaxSize must be a positive integer; got $MaxSize."
    }

    if ($Config.Keys.Count -eq 0) {
        throw "Config must contain at least one dimension (at least one key with values)."
    }

    foreach ($key in $Config.Keys) {
        [array]$vals = [array]$Config[$key]
        if ($vals.Count -eq 0) {
            throw "Config dimension '$key' has an empty array of values. Each dimension must have at least one value."
        }
    }

    # ------ Combination count and size check --------------------------------

    [int]$rawCount    = Get-CombinationCount -Config $Config
    [int]$excCount    = Get-ExcludedCount    -Config $Config -Excludes $Exclude
    [int]$finalCount  = $rawCount - $excCount

    if ($rawCount -gt $MaxSize) {
        throw "Matrix combination count ($rawCount) exceeds the maximum allowed size ($MaxSize). " +
              "Reduce the number of dimensions/values or increase -MaxSize."
    }

    # ------ Build matrix object ---------------------------------------------

    # Start with the dimension arrays from Config
    [hashtable]$matrixBody = @{}
    foreach ($key in $Config.Keys) {
        $matrixBody[[string]$key] = [array]$Config[$key]
    }

    # Add include / exclude sub-arrays if provided
    if ($Include.Count -gt 0) {
        $matrixBody['include'] = $Include
    }
    if ($Exclude.Count -gt 0) {
        $matrixBody['exclude'] = $Exclude
    }

    # Build the result object; add optional fields only when requested
    [PSCustomObject]$result = [PSCustomObject]@{
        matrix           = $matrixBody
        combinationCount = $finalCount
    }

    if ($PSBoundParameters.ContainsKey('MaxParallel')) {
        $result | Add-Member -MemberType NoteProperty -Name 'maxParallel' -Value $MaxParallel
    }

    if ($PSBoundParameters.ContainsKey('FailFast')) {
        $result | Add-Member -MemberType NoteProperty -Name 'failFast' -Value $FailFast
    }

    return $result
}

# ---------------------------------------------------------------------------
# ConvertTo-MatrixJson
# Serialises a New-BuildMatrix result to a formatted JSON string.
# ---------------------------------------------------------------------------
function ConvertTo-MatrixJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$MatrixResult
    )

    # Build a clean ordered hashtable so the JSON output is predictable
    [System.Collections.Specialized.OrderedDictionary]$output =
        [System.Collections.Specialized.OrderedDictionary]::new()

    $output['matrix'] = $MatrixResult.matrix

    if ($MatrixResult.PSObject.Properties.Name -contains 'failFast') {
        $output['failFast'] = $MatrixResult.failFast
    }

    if ($MatrixResult.PSObject.Properties.Name -contains 'maxParallel') {
        $output['maxParallel'] = $MatrixResult.maxParallel
    }

    return ($output | ConvertTo-Json -Depth 10)
}

Export-ModuleMember -Function New-BuildMatrix, ConvertTo-MatrixJson
