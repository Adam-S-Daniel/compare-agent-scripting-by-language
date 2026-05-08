# Dependency License Checker - Entry Point
# Usage: pwsh DependencyLicenseChecker.ps1 -ManifestPath <path> -ConfigPath <path>

param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

. "$PSScriptRoot/DependencyLicenseChecker.Functions.ps1"

$results = Invoke-LicenseCheck -ManifestPath $ManifestPath -ConfigPath $ConfigPath
$report = Format-ComplianceReport -Results $results -ManifestPath $ManifestPath
Write-Output $report

$denied = @($results | Where-Object { $_.Status -eq "denied" })
if ($denied.Count -gt 0) {
    exit 1
}
