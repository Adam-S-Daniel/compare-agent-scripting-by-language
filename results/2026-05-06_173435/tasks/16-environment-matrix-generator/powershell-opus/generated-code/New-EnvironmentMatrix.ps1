# New-EnvironmentMatrix.ps1
# Generates a GitHub Actions strategy.matrix JSON from a configuration file.
# Supports include/exclude rules, max-parallel, fail-fast, and size validation.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

if (-not $config.dimensions) {
    throw "Configuration must contain a 'dimensions' field"
}

$dimensionProps = @($config.dimensions.PSObject.Properties)
if ($dimensionProps.Count -eq 0) {
    throw "Configuration must have at least one dimension"
}

# Build matrix object — use List[object] so ConvertTo-Json always emits arrays
$matrix = [ordered]@{}
foreach ($prop in $dimensionProps) {
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($v in @($prop.Value)) { $list.Add($v) }
    $matrix[$prop.Name] = $list
}

# Cartesian product size
$totalCombinations = 1
foreach ($prop in $dimensionProps) {
    $totalCombinations *= @($prop.Value).Count
}

# Count combinations removed by each exclude rule
$excludeCount = 0
if ($config.exclude) {
    foreach ($rule in @($config.exclude)) {
        $ruleMatchCount = 1
        $ruleValid = $true
        $rulePropNames = @($rule.PSObject.Properties | ForEach-Object { $_.Name })

        foreach ($dim in $dimensionProps) {
            if ($rulePropNames -contains $dim.Name) {
                # Rule pins this dimension — verify the value exists
                if (@($dim.Value) -notcontains $rule.($dim.Name)) {
                    $ruleValid = $false
                    break
                }
            } else {
                # Rule is silent on this dimension — matches all its values
                $ruleMatchCount *= @($dim.Value).Count
            }
        }
        if ($ruleValid) { $excludeCount += $ruleMatchCount }
    }

    $excludeList = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($config.exclude)) { $excludeList.Add($item) }
    $matrix['exclude'] = $excludeList
}

# Count genuinely new combinations introduced by include rules
$newIncludeCount = 0
if ($config.include) {
    foreach ($item in @($config.include)) {
        $isNew = $false
        foreach ($dim in $dimensionProps) {
            $itemPropNames = @($item.PSObject.Properties | ForEach-Object { $_.Name })
            if ($itemPropNames -contains $dim.Name) {
                if (@($dim.Value) -notcontains $item.($dim.Name)) {
                    $isNew = $true
                    break
                }
            }
        }
        if ($isNew) { $newIncludeCount++ }
    }

    $includeList = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($config.include)) { $includeList.Add($item) }
    $matrix['include'] = $includeList
}

$effectiveSize = $totalCombinations - $excludeCount + $newIncludeCount

$maxCombinations = if ($null -ne $config.'max-combinations') {
    [int]$config.'max-combinations'
} else {
    256
}

if ($effectiveSize -gt $maxCombinations) {
    throw "Matrix size ($effectiveSize) exceeds maximum allowed ($maxCombinations)"
}

# Assemble the strategy output
$strategy = [ordered]@{
    'matrix'         = $matrix
    'fail-fast'      = if ($null -ne $config.'fail-fast') { [bool]$config.'fail-fast' } else { $false }
    'effective-size'  = $effectiveSize
}

if ($null -ne $config.'max-parallel') {
    $strategy['max-parallel'] = [int]$config.'max-parallel'
}

$strategy | ConvertTo-Json -Depth 10
