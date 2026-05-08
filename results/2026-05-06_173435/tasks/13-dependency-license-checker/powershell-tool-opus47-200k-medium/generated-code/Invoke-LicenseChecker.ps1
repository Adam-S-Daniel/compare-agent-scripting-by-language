<#
.SYNOPSIS
    CLI wrapper for the LicenseChecker module.
.DESCRIPTION
    Reads a manifest, looks up each package's license through a local stub map
    (network calls would happen here in production), and writes a compliance
    report to stdout. Exits non-zero when any dependency is on the deny-list,
    or when -FailOnUnknown is set and any license is unrecognized.
.PARAMETER Manifest
    Path to package.json or requirements.txt (or a similarly-shaped file).
.PARAMETER Config
    Path to a JSON file with 'allow' and 'deny' arrays of SPDX license IDs.
.PARAMETER LicenseDb
    Optional JSON file mapping package names to license strings. Used as the
    "lookup" backend so this CLI runs offline. If absent, every package
    resolves to $null and is reported as Unknown.
.PARAMETER FailOnUnknown
    Treat Unknown statuses as failures for exit-code purposes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Manifest,
    [Parameter(Mandatory)] [string] $Config,
    [string] $LicenseDb,
    [switch] $FailOnUnknown
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'LicenseChecker.psm1') -Force

if (-not (Test-Path -LiteralPath $Config)) {
    Write-Error "Config not found: $Config"
    exit 2
}
$cfgRaw = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$cfg = @{
    Allow = @($cfgRaw.allow)
    Deny  = @($cfgRaw.deny)
}

# Build the offline license-lookup callback. In production this is where the
# CLI would call npm/PyPI/etc.; here we read a JSON map for deterministic CI.
$licenseMap = @{}
if ($LicenseDb -and (Test-Path -LiteralPath $LicenseDb)) {
    $dbRaw = Get-Content -LiteralPath $LicenseDb -Raw | ConvertFrom-Json
    foreach ($prop in $dbRaw.PSObject.Properties) {
        $licenseMap[$prop.Name] = [string]$prop.Value
    }
}
$lookup = {
    param($name)
    if ($licenseMap.ContainsKey($name)) { return $licenseMap[$name] }
    return $null
}.GetNewClosure()

try {
    $report = Invoke-LicenseCheck -ManifestPath $Manifest -Config $cfg -LicenseLookup $lookup
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}

Write-Output (Format-ComplianceReport -Report $report)

# Emit a short machine-grep-friendly tail so CI can assert on exact counts.
$approved = @($report | Where-Object Status -EQ 'Approved').Count
$denied   = @($report | Where-Object Status -EQ 'Denied').Count
$unknown  = @($report | Where-Object Status -EQ 'Unknown').Count
Write-Output ("RESULT approved={0} denied={1} unknown={2}" -f $approved, $denied, $unknown)

if ($denied -gt 0) {
    Write-Output "RESULT verdict=FAIL"
    exit 1
}
if ($FailOnUnknown -and $unknown -gt 0) {
    Write-Output "RESULT verdict=FAIL"
    exit 1
}
Write-Output "RESULT verdict=PASS"
exit 0
