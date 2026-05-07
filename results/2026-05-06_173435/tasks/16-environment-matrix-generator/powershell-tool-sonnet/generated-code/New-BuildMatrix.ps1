<#
.SYNOPSIS
    Generates a build matrix (as JSON) for GitHub Actions strategy.matrix.

.DESCRIPTION
    Reads a JSON configuration describing OS options, language versions, and feature
    flags and outputs a complete strategy.matrix-compatible JSON structure. Supports
    include/exclude rules, max-parallel limits, fail-fast configuration, and validates
    that the matrix Cartesian product does not exceed a configurable maximum size.

    Development followed red/green TDD: tests in New-BuildMatrix.Tests.ps1 were
    written first (failing), then this implementation was written to make them pass.

.PARAMETER ConfigFile
    Path to a JSON config file. Used when the script is executed directly (CLI mode).
    Default: fixture.json

.EXAMPLE
    pwsh -File New-BuildMatrix.ps1 -ConfigFile fixtures/basic-matrix.json

.EXAMPLE
    # In Pester tests (dot-sourced):
    . ./New-BuildMatrix.ps1
    $result = New-BuildMatrix -Config @{ os = @("ubuntu-latest") }
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "fixture.json"
)

# Keys that control strategy behaviour — not matrix dimensions.
$script:ControlKeys = @('max-parallel', 'fail-fast', 'max-size', 'include', 'exclude')

# =============================================================================
# TDD Cycle 1 (Green): basic matrix generation from array-valued config keys
# TDD Cycle 2 (Green): include/exclude pass-through
# TDD Cycle 3 (Green): max-parallel and fail-fast at top level
# TDD Cycle 4 (Green): matrix size validation with meaningful error
# =============================================================================
function New-BuildMatrix {
    <#
    .SYNOPSIS
        Builds a GitHub Actions strategy.matrix structure from a configuration hashtable.

    .PARAMETER Config
        Hashtable describing the matrix. Array-valued keys (except control keys) become
        matrix dimensions. Supported control keys:
          include      — array of extra combination objects to inject
          exclude      — array of combination objects to suppress
          max-parallel — integer limit on concurrent jobs
          fail-fast    — boolean; default behaviour if omitted
          max-size     — integer; Cartesian product must not exceed this value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    # --- Extract control parameters ----------------------------------------
    $maxParallel = $Config['max-parallel']
    $failFast    = $Config['fail-fast']
    $maxSize     = $Config['max-size']
    $include     = $Config['include']
    $exclude     = $Config['exclude']

    # --- Build matrix dimensions from non-control array keys ----------------
    # Use regular hashtable (not OrderedDictionary) so .ContainsKey() works in tests.
    $matrix = @{}
    foreach ($key in $Config.Keys) {
        if ($key -notin $script:ControlKeys -and $Config[$key] -is [array]) {
            $matrix[$key] = $Config[$key]
        }
    }

    # --- Validate Cartesian product size ------------------------------------
    # Size is the product of each dimension's element count.
    $matrixSize = 1
    foreach ($values in $matrix.Values) {
        $matrixSize *= $values.Count
    }

    if ($null -ne $maxSize -and $matrixSize -gt $maxSize) {
        throw "Matrix size ($matrixSize) exceeds maximum allowed size ($maxSize)"
    }

    # --- Add include/exclude into the matrix object -------------------------
    # These are placed inside 'matrix', matching GitHub Actions strategy format.
    if ($null -ne $include) { $matrix['include'] = $include }
    if ($null -ne $exclude) { $matrix['exclude'] = $exclude }

    # --- Assemble the top-level result --------------------------------------
    # max-parallel and fail-fast are siblings of matrix (strategy-level), not
    # nested inside matrix itself. Use regular hashtable so .ContainsKey() works.
    $result = @{
        matrix = $matrix
    }

    if ($null -ne $maxParallel) { $result['max-parallel'] = $maxParallel }
    if ($null -ne $failFast)    { $result['fail-fast']    = $failFast    }

    return $result
}

# =============================================================================
# CLI entry point — runs only when executed directly, not when dot-sourced.
# Pester dot-sources this script to import New-BuildMatrix; the block below
# will NOT execute in that context because InvocationName will be '.'.
# =============================================================================
if ($MyInvocation.InvocationName -ne '.') {
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Config file not found: $ConfigFile"
        exit 1
    }

    try {
        $rawJson   = Get-Content -Path $ConfigFile -Raw -ErrorAction Stop
        $configObj = $rawJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        $result    = New-BuildMatrix -Config $configObj
        $jsonOutput = $result | ConvertTo-Json -Depth 10 -Compress

        # Emit in a parseable format so the outer test harness can extract
        # the exact value for assertion.
        Write-Host "MATRIX_OUTPUT: $jsonOutput"
    }
    catch {
        Write-Error "Error generating matrix: $_"
        exit 1
    }
}
