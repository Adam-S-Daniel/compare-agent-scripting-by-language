# New-BuildMatrix.ps1
# Core library for generating GitHub Actions build matrices.
# Dot-source this file in tests and in the CLI entry point.

function Get-MatrixSize {
    # Returns the total number of combinations (cartesian product) for the given dimensions hashtable.
    param(
        [Parameter(Mandatory)]
        [hashtable]$Dimensions
    )

    if ($Dimensions.Count -eq 0) { return 1 }

    $size = 1
    foreach ($key in $Dimensions.Keys) {
        $count = @($Dimensions[$key]).Count
        if ($count -gt 0) { $size *= $count }
    }
    return $size
}

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Generates a GitHub Actions strategy.matrix from a configuration hashtable.
    .PARAMETER Config
        Hashtable with keys:
          - dimensions   : hashtable of axis-name => array of values
          - include      : array of hashtables for matrix includes (optional)
          - exclude      : array of hashtables for matrix excludes (optional)
          - maxParallel  : integer max-parallel limit; omitted from output if 0 (optional)
          - failFast     : bool; defaults to $true (optional)
          - maxSize      : int maximum allowed matrix size; defaults to 256 (optional)
    .OUTPUTS
        Ordered hashtable suitable for ConvertTo-Json -Depth 10.
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $dimensions  = if ($Config.ContainsKey('dimensions'))  { $Config.dimensions }  else { @{} }
    # Avoid if-expression assignment — PowerShell unrolls single-element arrays from if-expression results.
    # Use two-statement form so the right-hand side is a direct @() assignment, not streamed output.
    $include = @(); if ($Config.ContainsKey('include'))     { $include = @($Config.include) }
    $exclude = @(); if ($Config.ContainsKey('exclude'))     { $exclude = @($Config.exclude) }
    $maxParallel = if ($Config.ContainsKey('maxParallel')) { $Config.maxParallel } else { 0 }
    $failFast    = if ($Config.ContainsKey('failFast'))    { $Config.failFast }    else { $true }
    $maxSize     = if ($Config.ContainsKey('maxSize'))     { $Config.maxSize }     else { 256 }

    # Validate size before building the result
    $matrixSize = Get-MatrixSize -Dimensions $dimensions
    if ($matrixSize -gt $maxSize) {
        throw "Matrix size $matrixSize exceeds maximum allowed size of $maxSize. Reduce the number of dimensions or their value counts."
    }

    # Build the matrix sub-object
    $matrix = @{}
    foreach ($key in $dimensions.Keys) {
        $matrix[$key] = @($dimensions[$key])
    }
    if ($include.Count -gt 0) { $matrix['include'] = $include }
    if ($exclude.Count -gt 0) { $matrix['exclude'] = $exclude }

    # Build the top-level result
    $result = @{
        matrix        = $matrix
        'fail-fast'   = $failFast
        'matrix-size' = $matrixSize
    }
    if ($maxParallel -gt 0) {
        $result['max-parallel'] = $maxParallel
    }

    return $result
}
