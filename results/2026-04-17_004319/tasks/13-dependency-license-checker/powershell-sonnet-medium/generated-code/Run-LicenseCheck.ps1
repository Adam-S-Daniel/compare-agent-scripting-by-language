# CLI entry point — delegates to functions in DependencyLicenseChecker.ps1
param(
    [string]$ManifestPath     = "package.json",
    [string]$ConfigPath       = "fixtures/license-config.json",
    [string]$MockDatabasePath = "fixtures/mock-licenses.json"
)

. (Join-Path $PSScriptRoot "DependencyLicenseChecker.ps1")

try {
    $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -ConfigPath $ConfigPath -MockDatabasePath $MockDatabasePath
    Write-Host (Format-ComplianceReport -Report $report)

    if (-not $report.Compliant) {
        exit 1
    }
}
catch {
    Write-Error "License check failed: $_"
    exit 2
}
