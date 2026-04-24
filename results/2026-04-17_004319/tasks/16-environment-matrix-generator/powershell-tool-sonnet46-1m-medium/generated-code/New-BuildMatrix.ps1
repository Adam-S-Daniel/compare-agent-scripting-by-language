# New-BuildMatrix.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration describing
# OS options, language versions, feature flags, include/exclude rules, and limits.
#
# When run as a script (with -ConfigPath), reads config from JSON and writes
# the resulting matrix JSON to stdout.
# When dot-sourced, exposes New-BuildMatrix for use in Pester tests.

param(
    [string]$ConfigPath,
    [int]$MaxMatrixSize = 256
)

function New-BuildMatrix {
    <#
    .SYNOPSIS
        Builds a GitHub Actions strategy.matrix object from a dimension config.
    .PARAMETER Config
        Hashtable with keys: dimensions (required), include, exclude,
        "max-parallel", "fail-fast".
    .PARAMETER MaxMatrixSize
        Maximum allowed Cartesian product of all dimensions (default 256).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [int]$MaxMatrixSize = 256
    )

    # --- Validate config presence ---
    if ($null -eq $Config) {
        throw "Config is required and must not be null."
    }

    if (-not $Config.ContainsKey("dimensions") -or $null -eq $Config.dimensions) {
        throw "Config must contain a 'dimensions' key with at least one dimension."
    }

    $dims = $Config.dimensions

    # --- Validate each dimension has values ---
    foreach ($key in $dims.Keys) {
        if ($null -eq $dims[$key] -or $dims[$key].Count -eq 0) {
            throw "Dimension '$key' must not be empty."
        }
    }

    # --- Validate total Cartesian product against MaxMatrixSize ---
    [long]$totalCombinations = 1
    foreach ($values in $dims.Values) {
        $totalCombinations *= $values.Count
    }

    if ($totalCombinations -gt $MaxMatrixSize) {
        throw "Matrix size ($totalCombinations) exceeds maximum ($MaxMatrixSize). Reduce dimensions or raise MaxMatrixSize."
    }

    # --- Build the matrix object ---
    $matrixInner = [ordered]@{}

    foreach ($key in $dims.Keys) {
        $matrixInner[$key] = @($dims[$key])
    }

    if ($Config.ContainsKey("include") -and $null -ne $Config.include) {
        $matrixInner["include"] = $Config.include
    }

    if ($Config.ContainsKey("exclude") -and $null -ne $Config.exclude) {
        $matrixInner["exclude"] = $Config.exclude
    }

    # --- Build the strategy object ---
    $strategy = [ordered]@{
        matrix      = $matrixInner
        "fail-fast" = if ($Config.ContainsKey("fail-fast")) { $Config."fail-fast" } else { $true }
    }

    if ($Config.ContainsKey("max-parallel") -and $null -ne $Config."max-parallel") {
        $strategy["max-parallel"] = $Config."max-parallel"
    }

    return [pscustomobject]$strategy
}

# ---------------------------------------------------------------------------
# Script entry point — only runs when invoked directly (not dot-sourced).
# Reads a JSON config file and prints the matrix JSON to stdout.
# ---------------------------------------------------------------------------
# Script mode: runs when the file is invoked directly (not dot-sourced).
# Dot-sourcing (". ./script.ps1") never supplies $ConfigPath, so this block
# stays dormant when Pester loads the file.
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {

    # Use [Console]::Error.WriteLine instead of Write-Error so that
    # $ErrorActionPreference = "Stop" in the caller cannot intercept our exits.

    if (-not (Test-Path $ConfigPath)) {
        [Console]::Error.WriteLine("Config file not found: '$ConfigPath' does not exist.")
        exit 1
    }

    try {
        $rawJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json

        # Convert PSCustomObject → hashtable so New-BuildMatrix can use .ContainsKey()
        function ConvertTo-Hashtable {
            param([Parameter(ValueFromPipeline)] $obj)
            process {
                if ($obj -is [System.Management.Automation.PSCustomObject]) {
                    $ht = @{}
                    foreach ($prop in $obj.PSObject.Properties) {
                        $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
                    }
                    return $ht
                }
                elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
                    return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
                }
                else {
                    return $obj
                }
            }
        }

        $config = ConvertTo-Hashtable $rawJson

        $result = New-BuildMatrix -Config $config -MaxMatrixSize $MaxMatrixSize
        $result | ConvertTo-Json -Depth 20
    }
    catch {
        [Console]::Error.WriteLine("Error generating matrix: $_")
        exit 1
    }
}
