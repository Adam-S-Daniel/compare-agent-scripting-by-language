# DependencyLicenseChecker.ps1
# Executable entry point: parses a manifest, checks licenses, and prints a report.
# Usage: ./DependencyLicenseChecker.ps1 -ManifestPath <path> -ConfigPath <path> -MockLicensesPath <path>

param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$MockLicensesPath,
    # When set, exit with code 1 if any denied licenses are found.
    [switch]$FailOnDenied
)

# Load library functions
. (Join-Path $PSScriptRoot "LicenseCheckerLib.ps1")

try {
    $report = Get-ComplianceReport `
        -ManifestPath   $ManifestPath `
        -ConfigPath     $ConfigPath `
        -MockLicensesPath $MockLicensesPath

    $formatted = Format-ComplianceReport -Report $report
    Write-Output $formatted

    if ($FailOnDenied) {
        $deniedCount = ($report | Where-Object { $_.Status -eq "DENIED" }).Count
        if ($deniedCount -gt 0) {
            exit 1
        }
    }
} catch {
    Write-Error "License check failed: $_"
    exit 1
}
