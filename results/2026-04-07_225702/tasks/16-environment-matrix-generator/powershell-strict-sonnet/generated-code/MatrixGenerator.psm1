# MatrixGenerator.psm1
# Generates GitHub Actions strategy.matrix JSON from a configuration
# describing OS options, language versions, and feature flags.
#
# Supports include/exclude rules, max-parallel limits, fail-fast config,
# and validates the matrix doesn't exceed a configurable maximum size.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# New-MatrixConfig
# Creates a validated configuration object for matrix generation.
# ---------------------------------------------------------------------------
function New-MatrixConfig {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # [AllowEmptyCollection()] lets us pass @() so the custom validation below runs
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$OsOptions,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$LanguageVersions,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$FeatureFlags = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [hashtable[]]$IncludeRules = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [hashtable[]]$ExcludeRules = @(),

        # 0 means "no limit" — the key will be omitted from output
        [Parameter(Mandatory = $false)]
        [int]$MaxParallel = 0,

        [Parameter(Mandatory = $false)]
        [bool]$FailFast = $true,

        # GitHub Actions hard limit is 256 jobs; default to that
        [Parameter(Mandatory = $false)]
        [int]$MaxSize = 256
    )

    if ($OsOptions.Count -eq 0) {
        throw 'Configuration must include at least one OS option.'
    }

    if ($LanguageVersions.Count -eq 0) {
        throw 'Configuration must include at least one language version.'
    }

    return @{
        os              = [string[]]$OsOptions
        language_versions = [string[]]$LanguageVersions
        feature_flags   = [string[]]$FeatureFlags
        include_rules   = [hashtable[]]$IncludeRules
        exclude_rules   = [hashtable[]]$ExcludeRules
        max_parallel    = [int]$MaxParallel
        fail_fast       = [bool]$FailFast
        max_size        = [int]$MaxSize
    }
}

# ---------------------------------------------------------------------------
# Get-MatrixCombinations
# Computes the full cartesian product of os × language_versions × feature_flags.
# Returns an array of hashtables, each representing one job combination.
# ---------------------------------------------------------------------------
function Get-MatrixCombinations {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    [hashtable[]]$combinations = @()

    foreach ($os in $Config.os) {
        foreach ($lang in $Config.language_versions) {
            if ($Config.feature_flags.Count -gt 0) {
                # Three-dimensional product when feature flags are present
                foreach ($feature in $Config.feature_flags) {
                    $combinations += @{
                        os       = [string]$os
                        language = [string]$lang
                        feature  = [string]$feature
                    }
                }
            }
            else {
                # Two-dimensional product: no feature dimension
                $combinations += @{
                    os       = [string]$os
                    language = [string]$lang
                }
            }
        }
    }

    return $combinations
}

# ---------------------------------------------------------------------------
# Invoke-ExcludeRules
# Removes from $Combinations any entry whose key/value pairs are a superset
# of any rule in $ExcludeRules (partial-match semantics — a rule with only
# {os: windows-latest} removes ALL combinations for that OS).
# ---------------------------------------------------------------------------
function Invoke-ExcludeRules {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Combinations,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$ExcludeRules
    )

    if ($ExcludeRules.Count -eq 0) {
        return $Combinations
    }

    [hashtable[]]$kept = @()

    foreach ($combo in $Combinations) {
        [bool]$excluded = $false

        foreach ($rule in $ExcludeRules) {
            # A combination is excluded if it matches ALL key/value pairs in the rule
            [bool]$ruleMatches = $true
            foreach ($key in $rule.Keys) {
                if (-not $combo.ContainsKey($key) -or $combo[$key] -ne $rule[$key]) {
                    $ruleMatches = $false
                    break
                }
            }
            if ($ruleMatches) {
                $excluded = $true
                break
            }
        }

        if (-not $excluded) {
            $kept += $combo
        }
    }

    return $kept
}

# ---------------------------------------------------------------------------
# Test-MatrixSize
# Validates that the number of combinations does not exceed MaxSize.
# Throws a descriptive error if the limit is breached.
# ---------------------------------------------------------------------------
function Test-MatrixSize {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Combinations,

        [Parameter(Mandatory = $true)]
        [int]$MaxSize
    )

    [int]$count = $Combinations.Count
    if ($count -gt $MaxSize) {
        throw "Matrix size ($count) exceeds maximum allowed size ($MaxSize). " +
              "Reduce the number of OS options, language versions, or feature flags, " +
              "or add exclude rules to bring the total below $MaxSize."
    }
}

# ---------------------------------------------------------------------------
# ConvertTo-GitHubActionsMatrix
# Takes a validated config, generates combinations, applies excludes, validates
# size, then serialises the full strategy object to a JSON string.
# ---------------------------------------------------------------------------
function ConvertTo-GitHubActionsMatrix {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    # Generate the full cartesian product
    [hashtable[]]$combinations = Get-MatrixCombinations -Config $Config

    # Apply exclude rules to compute effective size for validation
    [hashtable[]]$effective = Invoke-ExcludeRules `
        -Combinations $combinations `
        -ExcludeRules $Config.exclude_rules

    # Validate size against the configured limit
    Test-MatrixSize -Combinations $effective -MaxSize $Config.max_size

    # Build the matrix dimensions (the raw arrays used by GitHub Actions)
    [hashtable]$matrixBody = @{
        os       = $Config.os
        language = $Config.language_versions
    }

    if ($Config.feature_flags.Count -gt 0) {
        $matrixBody['feature'] = $Config.feature_flags
    }

    # Attach include/exclude rules if any were provided
    if ($Config.include_rules.Count -gt 0) {
        $matrixBody['include'] = $Config.include_rules
    }

    if ($Config.exclude_rules.Count -gt 0) {
        $matrixBody['exclude'] = $Config.exclude_rules
    }

    # Build the top-level strategy object
    [hashtable]$strategy = @{
        'fail-fast' = $Config.fail_fast
        matrix      = $matrixBody
    }

    # Only add max-parallel when explicitly set (non-zero)
    if ($Config.max_parallel -gt 0) {
        $strategy['max-parallel'] = $Config.max_parallel
    }

    return $strategy | ConvertTo-Json -Depth 10 -Compress:$false
}

# ---------------------------------------------------------------------------
# Invoke-MatrixGenerator
# Top-level entry point — accepts a raw config hashtable (matching the
# structure produced by New-MatrixConfig or read from a JSON config file),
# runs the full pipeline, and returns (and optionally writes) the JSON.
# ---------------------------------------------------------------------------
function Invoke-MatrixGenerator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$InputConfig,

        # If provided, the JSON is written to this file in addition to being returned
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ''
    )

    # Build the config object from the raw hashtable, supplying defaults
    [string[]]$os = [string[]]$InputConfig['os']
    [string[]]$langVersions = [string[]]$InputConfig['language_versions']

    [string[]]$featureFlags = @()
    if ($InputConfig.ContainsKey('feature_flags') -and $null -ne $InputConfig['feature_flags']) {
        $featureFlags = [string[]]$InputConfig['feature_flags']
    }

    [hashtable[]]$includeRules = @()
    if ($InputConfig.ContainsKey('include_rules') -and $null -ne $InputConfig['include_rules']) {
        $includeRules = [hashtable[]]$InputConfig['include_rules']
    }

    [hashtable[]]$excludeRules = @()
    if ($InputConfig.ContainsKey('exclude_rules') -and $null -ne $InputConfig['exclude_rules']) {
        $excludeRules = [hashtable[]]$InputConfig['exclude_rules']
    }

    [int]$maxParallel = 0
    if ($InputConfig.ContainsKey('max_parallel') -and $null -ne $InputConfig['max_parallel']) {
        $maxParallel = [int]$InputConfig['max_parallel']
    }

    [bool]$failFast = $true
    if ($InputConfig.ContainsKey('fail_fast') -and $null -ne $InputConfig['fail_fast']) {
        $failFast = [bool]$InputConfig['fail_fast']
    }

    [int]$maxSize = 256
    if ($InputConfig.ContainsKey('max_size') -and $null -ne $InputConfig['max_size']) {
        $maxSize = [int]$InputConfig['max_size']
    }

    [hashtable]$config = New-MatrixConfig `
        -OsOptions $os `
        -LanguageVersions $langVersions `
        -FeatureFlags $featureFlags `
        -IncludeRules $includeRules `
        -ExcludeRules $excludeRules `
        -MaxParallel $maxParallel `
        -FailFast $failFast `
        -MaxSize $maxSize

    [string]$json = ConvertTo-GitHubActionsMatrix -Config $config

    if ($OutputPath -ne '') {
        Set-Content -Path $OutputPath -Value $json -Encoding UTF8
    }

    return $json
}

Export-ModuleMember -Function @(
    'New-MatrixConfig',
    'Get-MatrixCombinations',
    'Invoke-ExcludeRules',
    'Test-MatrixSize',
    'ConvertTo-GitHubActionsMatrix',
    'Invoke-MatrixGenerator'
)
