# New-EnvironmentMatrix.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration file.
# Supports OS options, language versions, feature flags, include/exclude rules,
# max-parallel, fail-fast, and max-size validation.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigFile
)

# Compute cartesian product of named dimensions.
# Each dimension is a hashtable with Name and Values keys.
function Get-CartesianProduct {
    param([object[]]$Dimensions)

    $result = @(@{})

    foreach ($dim in $Dimensions) {
        $dimName   = $dim.Name
        $dimValues = $dim.Values
        $newResult = [System.Collections.Generic.List[hashtable]]::new()

        foreach ($existing in $result) {
            foreach ($val in $dimValues) {
                $combo = @{}
                foreach ($key in $existing.Keys) { $combo[$key] = $existing[$key] }
                $combo[$dimName] = $val
                $newResult.Add($combo)
            }
        }

        $result = $newResult.ToArray()
    }

    return $result
}

# Build the strategy.matrix output from a parsed config object.
function New-BuildMatrix {
    param([Parameter(Mandatory)][PSCustomObject]$Config)

    if (-not $Config.os) {
        throw "Configuration must include an 'os' field with at least one OS value"
    }

    # Assemble cartesian product dimensions: OS + language versions + feature flags
    $dimensions = @()
    $dimensions += @{ Name = "os"; Values = @($Config.os) }

    if ($Config.language_versions) {
        foreach ($lang in $Config.language_versions.PSObject.Properties) {
            $dimensions += @{ Name = $lang.Name; Values = @($lang.Value) }
        }
    }

    if ($Config.feature_flags) {
        foreach ($flag in $Config.feature_flags.PSObject.Properties) {
            $dimensions += @{ Name = $flag.Name; Values = @($flag.Value) }
        }
    }

    $combinations  = Get-CartesianProduct -Dimensions $dimensions
    $computedCount = $combinations.Count

    $maxSize = if ($null -ne $Config.max_size) { [int]$Config.max_size } else { 256 }
    if ($computedCount -gt $maxSize) {
        throw "Matrix size $computedCount exceeds maximum allowed size $maxSize"
    }

    # Build the matrix dimensions object for GitHub Actions
    $matrixDims = [ordered]@{}
    $matrixDims["os"] = @($Config.os)

    if ($Config.language_versions) {
        foreach ($lang in $Config.language_versions.PSObject.Properties) {
            $matrixDims[$lang.Name] = @($lang.Value)
        }
    }

    if ($Config.feature_flags) {
        foreach ($flag in $Config.feature_flags.PSObject.Properties) {
            $matrixDims[$flag.Name] = @($flag.Value)
        }
    }

    if ($Config.include)  { $matrixDims["include"]  = $Config.include }
    if ($Config.exclude)  { $matrixDims["exclude"]  = $Config.exclude }

    $maxParallel = if ($null -ne $Config.max_parallel) { [int]$Config.max_parallel } else { 256 }
    $failFast    = if ($null -ne $Config.fail_fast)    { [bool]$Config.fail_fast }   else { $true }

    return [ordered]@{
        strategy = [ordered]@{
            matrix          = $matrixDims
            "max-parallel"  = $maxParallel
            "fail-fast"     = $failFast
        }
        computed_count = $computedCount
    }
}

# Main execution — throws on error so callers (tests, workflow) see exceptions
$config = Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json
$result = New-BuildMatrix -Config $config
$result | ConvertTo-Json -Depth 10
