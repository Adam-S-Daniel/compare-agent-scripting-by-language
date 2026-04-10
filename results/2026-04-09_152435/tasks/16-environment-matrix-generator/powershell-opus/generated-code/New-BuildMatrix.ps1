# New-BuildMatrix.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration object.
#
# The configuration specifies:
#   - dimensions: hashtable of dimension names to arrays of values (cross-product)
#   - include: optional array of hashtables for additional matrix entries
#   - exclude: optional array of hashtables for combinations to skip
#   - fail-fast: optional bool (default true)
#   - max-parallel: optional int
#   - max-combinations: optional int (default 256, GitHub Actions limit)
#
# Output: a PSCustomObject with matrix, fail-fast, and optionally max-parallel,
# which can be converted to JSON for use in GitHub Actions strategy.

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        # Config as a hashtable (in-memory)
        [Parameter(ParameterSetName = "Object")]
        [hashtable]$Config,

        # Path to a JSON config file
        [Parameter(ParameterSetName = "File")]
        [string]$ConfigPath
    )

    # Load config from file if a path was provided
    if ($PSCmdlet.ParameterSetName -eq "File") {
        if (-not (Test-Path $ConfigPath)) {
            throw "Config file not found: $ConfigPath"
        }
        $json = Get-Content -Path $ConfigPath -Raw
        $Config = $json | ConvertFrom-Json -AsHashtable
    }

    # Validate: dimensions must exist and be non-empty
    if (-not $Config.ContainsKey('dimensions') -or $null -eq $Config.dimensions) {
        throw "Config must include 'dimensions' with at least one dimension."
    }

    $dimensions = $Config.dimensions
    if ($dimensions.Count -eq 0) {
        throw "Config must include 'dimensions' with at least one dimension."
    }

    # Validate: each dimension must have at least one value
    foreach ($key in $dimensions.Keys) {
        $values = @($dimensions[$key])
        if ($values.Count -eq 0) {
            throw "Dimension '$key' is empty. Each dimension must have at least one value."
        }
    }

    # Calculate the total number of combinations (cross-product size)
    $totalCombinations = 1
    foreach ($key in $dimensions.Keys) {
        $totalCombinations *= @($dimensions[$key]).Count
    }

    # Determine the max allowed combinations (default: 256 per GitHub Actions)
    $maxCombinations = 256
    if ($Config.ContainsKey('max-combinations')) {
        $maxCombinations = [int]$Config['max-combinations']
    }

    # Validate matrix size
    if ($totalCombinations -gt $maxCombinations) {
        throw "Matrix size ($totalCombinations) exceeds maximum allowed ($maxCombinations). Reduce dimensions or increase max-combinations."
    }

    # Build the matrix object with dimension arrays
    $matrix = [ordered]@{}
    foreach ($key in ($dimensions.Keys | Sort-Object)) {
        $matrix[$key] = @($dimensions[$key])
    }

    # Add include rules if present
    if ($Config.ContainsKey('include') -and $null -ne $Config.include) {
        $includeList = @()
        foreach ($entry in $Config.include) {
            if ($entry -is [hashtable]) {
                $obj = [PSCustomObject]$entry
            } else {
                $obj = $entry
            }
            $includeList += $obj
        }
        $matrix['include'] = $includeList
    }

    # Add exclude rules if present
    if ($Config.ContainsKey('exclude') -and $null -ne $Config.exclude) {
        $excludeList = @()
        foreach ($entry in $Config.exclude) {
            if ($entry -is [hashtable]) {
                $obj = [PSCustomObject]$entry
            } else {
                $obj = $entry
            }
            $excludeList += $obj
        }
        $matrix['exclude'] = $excludeList
    }

    # Build the strategy result object
    $strategy = [ordered]@{
        matrix = [PSCustomObject]$matrix
    }

    # Set fail-fast (default true)
    if ($Config.ContainsKey('fail-fast')) {
        $strategy['fail-fast'] = [bool]$Config['fail-fast']
    } else {
        $strategy['fail-fast'] = $true
    }

    # Set max-parallel only if specified
    if ($Config.ContainsKey('max-parallel')) {
        $strategy['max-parallel'] = [int]$Config['max-parallel']
    }

    return [PSCustomObject]$strategy
}

# CLI entrypoint: when invoked directly with -ConfigPath, output JSON
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '') {
    # Only run CLI mode if a ConfigPath argument was passed on the command line
    $cliConfigPath = $null
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '-ConfigPath' -and ($i + 1) -lt $args.Count) {
            $cliConfigPath = $args[$i + 1]
            break
        }
    }
    if ($cliConfigPath) {
        $result = New-BuildMatrix -ConfigPath $cliConfigPath
        $result | ConvertTo-Json -Depth 10
    }
}
