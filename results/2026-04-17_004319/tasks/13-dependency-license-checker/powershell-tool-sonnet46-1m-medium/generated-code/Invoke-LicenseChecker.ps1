# Invoke-LicenseChecker.ps1
# Entry-point script for the Dependency License Checker.
# Usage: ./Invoke-LicenseChecker.ps1 -ManifestPath <path> -ConfigPath <path> [-MockLicensesPath <path>]
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$MockLicensesPath
)

# Load all functions from the library file
. "$PSScriptRoot/LicenseChecker-Functions.ps1"

# --- Load config ---
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# --- Load mock license data (if provided) ---
$mockLicenses = @{}
if ($MockLicensesPath) {
    if (-not (Test-Path $MockLicensesPath)) {
        Write-Error "Mock licenses file not found: $MockLicensesPath"
        exit 1
    }
    $json = Get-Content $MockLicensesPath -Raw | ConvertFrom-Json
    $json.PSObject.Properties | ForEach-Object { $mockLicenses[$_.Name] = $_.Value }
}

# --- Run the check ---
$report = Invoke-LicenseCheck -ManifestPath $ManifestPath -Config $config -MockLicenses $mockLicenses

# --- Print report ---
Write-Output "=== LICENSE COMPLIANCE REPORT ==="
foreach ($entry in $report) {
    Write-Output "$($entry.Name): $($entry.License) ($($entry.Status))"
}

$approved = @($report | Where-Object { $_.Status -eq 'approved' }).Count
$denied   = @($report | Where-Object { $_.Status -eq 'denied'   }).Count
$unknown  = @($report | Where-Object { $_.Status -eq 'unknown'  }).Count

Write-Output ""
Write-Output "=== SUMMARY ==="
Write-Output "Approved: $approved"
Write-Output "Denied:   $denied"
Write-Output "Unknown:  $unknown"
Write-Output ""

if ($denied -gt 0) {
    Write-Output "COMPLIANCE FAILURE: $denied denied license(s) found"
    $report | Where-Object { $_.Status -eq 'denied' } | ForEach-Object {
        Write-Output "  - $($_.Name) ($($_.License))"
    }
    exit 1
} else {
    Write-Output "COMPLIANCE CHECK PASSED"
}
