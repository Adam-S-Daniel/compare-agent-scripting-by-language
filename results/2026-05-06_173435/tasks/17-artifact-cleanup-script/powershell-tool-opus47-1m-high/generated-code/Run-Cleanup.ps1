# Run-Cleanup.ps1
#
# Thin CLI wrapper that the GitHub Actions workflow invokes. It reads a
# fixture (artifacts JSON) and a config JSON containing the policy knobs +
# fixed Now timestamp, then calls Invoke-ArtifactCleanup. Keeping this in a
# separate script (instead of letting the workflow invoke the library
# directly) makes the act harness simpler -- one script, one invocation.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputPath,
    [Parameter(Mandatory)] [string] $ConfigPath,
    [string] $OutputPath = 'plan.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ArtifactCleanup.ps1')

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

# Pull each policy field with a default so test fixtures only need to set what
# they care about. Fall back via [psobject].Properties to avoid StrictMode
# blowing up when a field is absent.
function Get-Field {
    param($Object, [string] $Name, $Default)
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop -and $null -ne $prop.Value) { return $prop.Value }
    return $Default
}

$maxAge   = [int]  (Get-Field $config 'MaxAgeDays'            0)
$maxSize  = [long] (Get-Field $config 'MaxTotalSizeBytes'     0)
$keepN    = [int]  (Get-Field $config 'KeepLatestPerWorkflow' 0)
$dryRun   = [bool] (Get-Field $config 'DryRun'                $false)
$nowRaw   =        (Get-Field $config 'Now'                   $null)

if ($nowRaw) {
    # ConvertFrom-Json may already deserialize ISO datetimes into [datetime];
    # round-tripping through ToString() loses the UTC marker, so handle both.
    if ($nowRaw -is [datetime]) {
        $now = $nowRaw.ToUniversalTime()
    } else {
        $now = [datetime]::Parse(
            [string]$nowRaw,
            [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor `
            [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    }
} else {
    $now = (Get-Date).ToUniversalTime()
}

Write-Host ("CONFIG: max_age_days={0} max_size={1} keep_latest={2} now={3} dry_run={4}" -f `
    $maxAge, $maxSize, $keepN, $now.ToString('o'), $dryRun.ToString().ToLowerInvariant())

Invoke-ArtifactCleanup `
    -InputPath  $InputPath `
    -OutputPath $OutputPath `
    -MaxAgeDays $maxAge `
    -MaxTotalSizeBytes $maxSize `
    -KeepLatestPerWorkflow $keepN `
    -Now $now `
    -DryRun:$dryRun | Out-Null
