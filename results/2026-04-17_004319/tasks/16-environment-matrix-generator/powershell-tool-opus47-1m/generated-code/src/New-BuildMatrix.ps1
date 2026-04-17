Set-StrictMode -Version Latest

# Keys that control strategy behavior rather than matrix dimensions.
$script:ReservedKeys = @('include', 'exclude', 'max-parallel', 'fail-fast', 'max-size')

function ConvertTo-HashtableFromPSObject {
    # ConvertFrom-Json returns PSCustomObjects; we normalize to hashtables so the
    # rest of the code can treat file-sourced and inline configs uniformly.
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.Specialized.OrderedDictionary]) { return $InputObject }
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $h = @{}
            foreach ($p in $InputObject.PSObject.Properties) {
                $h[$p.Name] = ConvertTo-HashtableFromPSObject -InputObject $p.Value
            }
            return $h
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
            return @($InputObject | ForEach-Object { ConvertTo-HashtableFromPSObject -InputObject $_ })
        }
        return $InputObject
    }
}

function Get-MatrixCartesianProduct {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Dimensions)

    # Sort keys so output is stable across PowerShell versions (hashtable ordering is not guaranteed).
    $keys = @($Dimensions.Keys | Sort-Object)
    if ($keys.Count -eq 0) { return @() }

    $accumulator = @([ordered]@{})
    foreach ($key in $keys) {
        $values = @($Dimensions[$key])
        if ($values.Count -eq 0) { throw "Dimension '$key' must contain at least one value" }
        $next = [System.Collections.ArrayList]::new()
        foreach ($combo in $accumulator) {
            foreach ($value in $values) {
                $copy = [ordered]@{}
                foreach ($k in $combo.Keys) { $copy[$k] = $combo[$k] }
                $copy[$key] = $value
                [void]$next.Add($copy)
            }
        }
        $accumulator = @($next.ToArray())
    }
    return $accumulator
}

function Test-MatrixRuleMatches {
    # A rule matches a combination when every key listed in the rule is present and equal.
    # This is GitHub Actions' "subset match" semantic used for exclude filtering.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Combination,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Rule
    )
    foreach ($key in $Rule.Keys) {
        if (-not $Combination.Contains($key)) { return $false }
        if ($Combination[$key] -ne $Rule[$key]) { return $false }
    }
    return $true
}

function New-BuildMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config
    )

    if ($null -eq $Config -or $Config.Keys.Count -eq 0) {
        throw 'Configuration cannot be empty'
    }

    $dimensions = @{}
    foreach ($key in $Config.Keys) {
        if ($key -in $script:ReservedKeys) { continue }
        $values = @($Config[$key])
        if ($values.Count -eq 0) { throw "Dimension '$key' must contain at least one value" }
        $dimensions[$key] = $values
    }

    if ($dimensions.Count -eq 0) {
        throw 'Configuration must include at least one matrix dimension'
    }

    # Validate max-parallel and max-size up-front so the error surfaces even on tiny inputs.
    if ($Config.Contains('max-parallel')) {
        $mp = [int]$Config['max-parallel']
        if ($mp -le 0) { throw 'max-parallel must be a positive integer' }
    }
    $maxSize = 256
    if ($Config.Contains('max-size')) {
        $maxSize = [int]$Config['max-size']
        if ($maxSize -le 0) { throw 'max-size must be a positive integer' }
    }

    $combinations = @(Get-MatrixCartesianProduct -Dimensions $dimensions)

    if ($Config.Contains('exclude') -and $Config['exclude']) {
        $excludeRules = @($Config['exclude'] | ForEach-Object { ConvertTo-HashtableFromPSObject -InputObject $_ })
        $combinations = @($combinations | Where-Object {
            $combo = $_
            $matched = $false
            foreach ($rule in $excludeRules) {
                if (Test-MatrixRuleMatches -Combination $combo -Rule $rule) { $matched = $true; break }
            }
            -not $matched
        })
    }

    # Simplified include semantics: each include entry is appended as a new combination.
    # This covers the typical "add one exotic row" use case without implementing GitHub's
    # full merging rules (which depend on a fragile definition of "original matrix expansion").
    if ($Config.Contains('include') -and $Config['include']) {
        $includeRules = @($Config['include'] | ForEach-Object { ConvertTo-HashtableFromPSObject -InputObject $_ })
        foreach ($rule in $includeRules) {
            $ordered = [ordered]@{}
            foreach ($k in ($rule.Keys | Sort-Object)) { $ordered[$k] = $rule[$k] }
            $combinations += , $ordered
        }
    }

    if ($combinations.Count -gt $maxSize) {
        throw "Matrix size ($($combinations.Count)) exceeds maximum allowed size ($maxSize)"
    }

    $result = [ordered]@{
        matrix = [ordered]@{ include = @($combinations) }
        count  = $combinations.Count
    }
    if ($Config.Contains('max-parallel')) { $result['max-parallel'] = [int]$Config['max-parallel'] }
    if ($Config.Contains('fail-fast'))    { $result['fail-fast']    = [bool]$Config['fail-fast'] }
    return $result
}

function ConvertTo-BuildMatrixJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Config,
        [int]$Depth = 10,
        [switch]$Compress
    )
    $matrix = New-BuildMatrix -Config $Config
    return ($matrix | ConvertTo-Json -Depth $Depth -Compress:$Compress)
}

function New-BuildMatrixFromFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) { throw "Config file not found: $Path" }

    $raw = Get-Content -Path $Path -Raw
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$Path': $($_.Exception.Message)"
    }
    $config = ConvertTo-HashtableFromPSObject -InputObject $parsed
    if ($config -isnot [hashtable]) {
        throw "Config file '$Path' must contain a JSON object at the top level"
    }
    return New-BuildMatrix -Config $config
}
