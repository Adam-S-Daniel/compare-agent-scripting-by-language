<#
.SYNOPSIS
    Generates a GitHub Actions strategy.matrix object from a configuration spec.

.DESCRIPTION
    Reads a configuration hashtable describing axes (e.g. os, language version,
    feature flags), include/exclude rules, fail-fast and max-parallel settings,
    and a max-size guard. Produces a hashtable shaped for `strategy:` in a
    GitHub Actions workflow:

        strategy:
          fail-fast: false
          max-parallel: 4
          matrix:
            include: [ ... cartesian product, plus extra include rows ... ]

    The cartesian product is materialized into `matrix.include` (rather than
    using axis-keys directly) so excludes and adds compose deterministically.
#>

# GitHub Actions documents a hard ceiling of 256 jobs per matrix.
$script:GitHubMatrixCeiling = 256

function New-EnvironmentMatrix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Config
    )

    if (-not $Config.ContainsKey('axes') -or $null -eq $Config.axes -or $Config.axes.Count -eq 0) {
        $err = [System.Management.Automation.ErrorRecord]::new(
            [System.ArgumentException]::new("Config must define at least one axis under 'axes'."),
            'NoAxes', 'InvalidArgument', $Config)
        $PSCmdlet.ThrowTerminatingError($err)
    }

    $axes = $Config.axes

    # Build the cartesian product iteratively. Each entry is a hashtable mapping
    # axis name -> value, so we can compare entries against exclude rules.
    # Use [ordered] hashtables so axis keys appear in the JSON in declaration order
    # (e.g. {os, node} not {node, os}) — matters for human-readable diffs and tests.
    $combinations = @( [ordered] @{} )
    foreach ($key in $axes.Keys) {
        $values = @($axes[$key])
        $next   = New-Object System.Collections.ArrayList
        foreach ($combo in $combinations) {
            foreach ($v in $values) {
                $merged = [ordered] @{}
                foreach ($k in $combo.Keys) { $merged[$k] = $combo[$k] }
                $merged[$key] = $v
                [void] $next.Add($merged)
            }
        }
        $combinations = $next.ToArray()
    }

    # Apply exclude rules: drop any combo where every key in the rule matches.
    if ($Config.ContainsKey('exclude') -and $Config.exclude) {
        $combinations = @($combinations | Where-Object {
            $combo = $_
            $hit = $false
            foreach ($rule in $Config.exclude) {
                $matchAll = $true
                foreach ($k in $rule.Keys) {
                    # Use Contains so this works for both [hashtable] and [ordered]@{} (OrderedDictionary).
                    if (-not $combo.Contains($k) -or $combo[$k] -ne $rule[$k]) { $matchAll = $false; break }
                }
                if ($matchAll) { $hit = $true; break }
            }
            -not $hit
        })
    }

    # Apply include rules: append extra rows verbatim.
    if ($Config.ContainsKey('include') -and $Config.include) {
        $combinations = @($combinations) + @($Config.include | ForEach-Object { $_ })
    }

    # Enforce GitHub's hard ceiling, plus user-supplied max-size if smaller.
    $maxSize = $script:GitHubMatrixCeiling
    if ($Config.ContainsKey('max-size') -and $Config['max-size'] -lt $maxSize) {
        $maxSize = [int] $Config['max-size']
    }
    if ($combinations.Count -gt $maxSize) {
        $err = [System.Management.Automation.ErrorRecord]::new(
            [System.InvalidOperationException]::new(
                "Matrix size $($combinations.Count) exceeds maximum $maxSize."),
            'MatrixTooLarge', 'LimitsExceeded', $combinations.Count)
        $PSCmdlet.ThrowTerminatingError($err)
    }

    # Convert each combo hashtable to a PSCustomObject so it serializes as a JSON
    # object with named keys (Actions requires this shape).
    $includeObjects = $combinations | ForEach-Object { [pscustomobject] $_ }

    $result = [ordered] @{
        matrix = [pscustomobject] @{ include = @($includeObjects) }
    }
    if ($Config.ContainsKey('fail-fast'))     { $result['fail-fast']    = [bool] $Config['fail-fast'] }
    if ($Config.ContainsKey('max-parallel'))  { $result['max-parallel'] = [int]  $Config['max-parallel'] }

    return [pscustomobject] $result
}

function ConvertTo-MatrixJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $Matrix,
        [int] $Depth = 10
    )
    process {
        # -Compress keeps the JSON on one line for easy embedding in `matrix:` outputs.
        $Matrix | ConvertTo-Json -Depth $Depth -Compress
    }
}

function Invoke-MatrixGenerator {
    <#
    .SYNOPSIS
        CLI wrapper: read a JSON config from a path, write matrix JSON to stdout.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath
    )
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    # Use AsHashtable so keys with hyphens (fail-fast, max-parallel) survive intact.
    $config = $raw | ConvertFrom-Json -AsHashtable
    New-EnvironmentMatrix -Config $config | ConvertTo-MatrixJson
}
