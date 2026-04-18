#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI wrapper around LicenseChecker: turns a manifest + policy + mock
    license database into a JSON compliance report.

.DESCRIPTION
    Designed to be callable from CI. Reads:
      * -ManifestPath   dependency manifest (package.json-style)
      * -PolicyPath     JSON with { allow: [...], deny: [...] }
      * -LicenseDbPath  JSON object mapping dep name -> license string
                        (the "mock" registry used in place of a real one)
    Prints the report to stdout as pretty JSON. Also writes it to -OutPath
    when supplied.

    Exit codes:
      0  compliant (no denied dependencies)
      1  at least one denied dependency
      2  operational error (missing files, parse failure, etc.)

.EXAMPLE
    pwsh ./Invoke-LicenseCheck.ps1 -ManifestPath ./package.json \
        -PolicyPath ./config/policy.json \
        -LicenseDbPath ./config/mock-licenses.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath,

    [Parameter(Mandatory)]
    [string]$PolicyPath,

    [Parameter(Mandatory)]
    [string]$LicenseDbPath,

    [string]$OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    $modulePath = Join-Path $PSScriptRoot 'src' 'LicenseChecker.psm1'
    Import-Module $modulePath -Force

    foreach ($p in @($PolicyPath, $LicenseDbPath)) {
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
            throw "Config file not found: $p"
        }
    }

    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json

    # Hashtable conversion keeps things simple for Get-DependencyLicense,
    # which expects a [hashtable] rather than a PSCustomObject.
    $dbJson = Get-Content -LiteralPath $LicenseDbPath -Raw | ConvertFrom-Json
    $db = @{}
    foreach ($prop in $dbJson.PSObject.Properties) {
        $db[$prop.Name] = [string]$prop.Value
    }

    $report = New-ComplianceReport -ManifestPath $ManifestPath `
                                   -Policy $policy `
                                   -LicenseDatabase $db

    $json = $report | ConvertTo-Json -Depth 8

    # Markers make it trivial to extract the JSON from act's verbose log.
    Write-Output '--- LICENSE-REPORT-BEGIN ---'
    Write-Output $json
    Write-Output '--- LICENSE-REPORT-END ---'

    if ($OutPath) {
        Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
    }

    # Emit a concise human-readable line so the workflow log tells a story.
    $s = $report.summary
    Write-Output ("SUMMARY total={0} approved={1} denied={2} unknown={3} compliant={4}" -f `
        $s.total, $s.approved, $s.denied, $s.unknown, $report.compliant)

    if (-not $report.compliant) {
        exit 1
    }
    exit 0
}
catch {
    Write-Error "License check failed: $($_.Exception.Message)"
    exit 2
}
