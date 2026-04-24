# check-licenses.ps1
# CLI entry point: parses a manifest, looks up licenses (via an optional offline
# map for deterministic CI runs), checks them against allow/deny lists, and
# prints a JSON compliance report to stdout. Exits non-zero if any denied.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$LicenseMapPath,
    [string]$OutputPath,
    [switch]$ReportOnly
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'LicenseChecker.psm1'
Import-Module $modulePath -Force

# If an offline license map is provided, override Get-PackageLicense so the
# report is deterministic without network access. This is how CI runs.
if ($LicenseMapPath) {
    if (-not (Test-Path -LiteralPath $LicenseMapPath)) {
        throw "License map not found: $LicenseMapPath"
    }
    $map = Get-Content -LiteralPath $LicenseMapPath -Raw | ConvertFrom-Json

    # Convert PSCustomObject to a hashtable keyed by package name.
    $lookup = @{}
    foreach ($prop in $map.PSObject.Properties) {
        $lookup[$prop.Name] = [string]$prop.Value
    }

    # Install the lookup table as a module-scoped variable, then redefine
    # Get-PackageLicense in the module to read from it. Invoke-LicenseCheck
    # (also in the module) then routes through our offline map.
    $mod = Get-Module LicenseChecker
    & $mod { param($tbl) $script:LicenseMap = $tbl } $lookup
    & $mod {
        function script:Get-PackageLicense {
            param([string]$Name, [string]$Version)
            if ($script:LicenseMap -and $script:LicenseMap.ContainsKey($Name)) {
                return $script:LicenseMap[$Name]
            }
            return 'UNKNOWN'
        }
    }
}

$report = Invoke-LicenseCheck -ManifestPath $ManifestPath -ConfigPath $ConfigPath
$json   = $report | ConvertTo-Json -Depth 6

if ($OutputPath) {
    $json | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
Write-Output $json

if ($report.summary.denied -gt 0 -and -not $ReportOnly) {
    Write-Error "Found $($report.summary.denied) denied license(s)"
    exit 2
}
exit 0
