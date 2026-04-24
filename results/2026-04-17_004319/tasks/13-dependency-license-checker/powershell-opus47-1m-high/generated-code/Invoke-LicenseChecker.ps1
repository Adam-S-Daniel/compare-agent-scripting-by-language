# Invoke-LicenseChecker.ps1
#
# CLI wrapper around the LicenseChecker module. Prints a formatted report and
# returns a non-zero exit code if any dependency is on the deny list (so CI
# pipelines can fail the build on policy violations).
#
# Usage:
#   pwsh -File Invoke-LicenseChecker.ps1 `
#        -ManifestPath ./fixtures/package.json `
#        -ConfigPath   ./fixtures/license-config.json `
#        -LicenseDataPath ./fixtures/license-data.json

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$LicenseDataPath,
    # When set, emit the report as JSON on stdout in addition to text.
    [switch]$Json,
    # When set, process returns 0 even if denied licenses are present. Handy
    # for advisory runs where the policy hasn't been fully agreed yet.
    [switch]$NoFailOnDenied
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'src' 'LicenseChecker.psm1'
Import-Module -Name $modulePath -Force

try {
    $report = Invoke-LicenseCheck -ManifestPath $ManifestPath `
                                  -ConfigPath $ConfigPath `
                                  -LicenseDataPath $LicenseDataPath

    Write-Output (Format-LicenseReport -Report $report)

    if ($Json) {
        Write-Output '--- JSON REPORT START ---'
        Write-Output ($report | ConvertTo-Json -Depth 5 -Compress)
        Write-Output '--- JSON REPORT END ---'
    }

    $summary = Get-LicenseSummary -Report $report
    if ($summary.Denied -gt 0 -and -not $NoFailOnDenied) {
        Write-Error "License policy violation: $($summary.Denied) denied dependency/dependencies found."
        exit 2
    }
    exit 0
} catch {
    Write-Error "License check failed: $($_.Exception.Message)"
    exit 1
}
