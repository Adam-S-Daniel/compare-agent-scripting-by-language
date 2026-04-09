<#
.SYNOPSIS
    Generates a GitHub Actions strategy.matrix JSON from a configuration file.

.DESCRIPTION
    TDD GREEN: This implementation was written to make failing Pester tests pass.
    Tests were written first (RED) in New-BuildMatrix.Tests.ps1.

    Given a configuration JSON describing OS options, language versions, and
    feature flags, generates a build matrix suitable for GitHub Actions
    strategy.matrix.  Supports include/exclude rules, max-parallel limits,
    fail-fast configuration, and maximum matrix-size validation.

    Output format (written to stdout):
        MATRIX_OUTPUT: <compact-json>   on success
        MATRIX_ERROR:  <message>        on validation failure (exit 1)

.PARAMETER ConfigPath
    Path to the JSON configuration file.  Required.

.PARAMETER MaxMatrixSize
    Hard cap on the Cartesian-product combination count.
    Default: 256 (GitHub Actions limit).
    Can also be set per-config via the "maxMatrixSize" key.

.EXAMPLE
    pwsh -File New-BuildMatrix.ps1 -ConfigPath matrix-config.json

.EXAMPLE
    pwsh -File New-BuildMatrix.ps1 -ConfigPath matrix-config.json -MaxMatrixSize 50
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [int]$MaxMatrixSize = 256
)

# ============================================================================
# New-BuildMatrix  — core function
# ============================================================================
# Accepts a hashtable (parsed from JSON with -AsHashtable) and returns a
# strategy hashtable.  Throws on validation failure so the caller can catch
# and emit MATRIX_ERROR with a clean exit-code.
# ============================================================================
function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [int]$MaxMatrixSize = 256
    )

    # ----------------------------------------------------------------
    # Step 1 (RED→GREEN): Build matrix dimensions from OS, language
    # versions, and feature flags.
    # ----------------------------------------------------------------
    $dimensions = [ordered]@{}

    # OS dimension
    if ($Config.ContainsKey('os') -and $null -ne $Config['os'] -and
        @($Config['os']).Count -gt 0) {
        $dimensions['os'] = @($Config['os'])
    }

    # Language-version dimensions — each language key becomes its own axis
    if ($Config.ContainsKey('languageVersions') -and
        $null -ne $Config['languageVersions']) {
        $lv = $Config['languageVersions']
        foreach ($lang in $lv.Keys) {
            if ($null -ne $lv[$lang] -and @($lv[$lang]).Count -gt 0) {
                $dimensions[$lang] = @($lv[$lang])
            }
        }
    }

    # Feature-flag dimensions — each flag key becomes its own axis
    if ($Config.ContainsKey('featureFlags') -and
        $null -ne $Config['featureFlags']) {
        $ff = $Config['featureFlags']
        foreach ($flag in $ff.Keys) {
            if ($null -ne $ff[$flag] -and @($ff[$flag]).Count -gt 0) {
                $dimensions[$flag] = @($ff[$flag])
            }
        }
    }

    # ----------------------------------------------------------------
    # Step 2 (RED→GREEN): Validate Cartesian product size
    # ----------------------------------------------------------------
    # Per-config override takes precedence over the parameter.
    $effectiveMax = if ($Config.ContainsKey('maxMatrixSize') -and
                        $null -ne $Config['maxMatrixSize']) {
        [int]$Config['maxMatrixSize']
    } else {
        $MaxMatrixSize
    }

    $count = 1
    foreach ($vals in $dimensions.Values) { $count *= $vals.Count }

    if ($count -gt $effectiveMax) {
        throw "Matrix size ($count combinations) exceeds maximum allowed size ($effectiveMax). " +
              "Reduce the number of dimensions or their values."
    }

    # ----------------------------------------------------------------
    # Step 3 (RED→GREEN): Build output matrix object
    # ----------------------------------------------------------------
    $matrix = [ordered]@{}

    # Dimension arrays (os, node, experimental, …)
    foreach ($key in $dimensions.Keys) {
        $matrix[$key] = $dimensions[$key]
    }

    # Exclude rules pass through verbatim
    if ($Config.ContainsKey('exclude') -and $null -ne $Config['exclude']) {
        $matrix['exclude'] = $Config['exclude']
    }

    # Include rules pass through verbatim
    if ($Config.ContainsKey('include') -and $null -ne $Config['include']) {
        $matrix['include'] = $Config['include']
    }

    # ----------------------------------------------------------------
    # Step 4 (RED→GREEN): Build strategy wrapper
    # ----------------------------------------------------------------
    $strategy = [ordered]@{ matrix = $matrix }

    # max-parallel limit
    if ($Config.ContainsKey('maxParallel') -and $null -ne $Config['maxParallel']) {
        $strategy['max-parallel'] = [int]$Config['maxParallel']
    }

    # fail-fast flag
    if ($Config.ContainsKey('failFast') -and $null -ne $Config['failFast']) {
        $strategy['fail-fast'] = [bool]$Config['failFast']
    }

    return $strategy
}

# ============================================================================
# Script entry point
# ============================================================================
try {
    if (-not (Test-Path $ConfigPath)) {
        Write-Output "MATRIX_ERROR: Configuration file not found: $ConfigPath"
        exit 1
    }

    # -AsHashtable makes nested objects hashtables too (PowerShell 7+)
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable

    $strategy = New-BuildMatrix -Config $config -MaxMatrixSize $MaxMatrixSize

    # Emit compact single-line JSON with a parseable prefix so test harnesses
    # can extract it reliably from act output.
    $json = $strategy | ConvertTo-Json -Compress -Depth 10
    Write-Output "MATRIX_OUTPUT: $json"

} catch {
    Write-Output "MATRIX_ERROR: $($_.Exception.Message)"
    exit 1
}
