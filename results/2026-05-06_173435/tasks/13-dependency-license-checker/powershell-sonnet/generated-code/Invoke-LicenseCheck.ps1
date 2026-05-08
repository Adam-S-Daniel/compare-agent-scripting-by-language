# Entry-point wrapper around LicenseChecker.ps1 functions.
# Run directly: ./Invoke-LicenseCheck.ps1 -ManifestPath <path> [-ConfigPath <path>]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "fixtures/license-config.json")
)

. "$PSScriptRoot/LicenseChecker.ps1"

try {
    $config = Get-LicenseConfig -ConfigPath $ConfigPath
    $deps   = Get-DependenciesFromManifest -ManifestPath $ManifestPath

    # Get-MockLicense is defined in LicenseChecker.ps1 and reads fixtures/mock-licenses.json.
    # Pass it as a function reference — no $using: needed, avoids remote-execution restrictions.
    $report    = New-ComplianceReport -Dependencies $deps -Config $config -LicenseLookup ${function:Get-MockLicense}
    $formatted = Format-ComplianceReport -ReportItems $report
    Write-Output $formatted

    $deniedCount = @($report | Where-Object Status -eq "DENIED").Count
    if ($deniedCount -gt 0) {
        Write-Warning "Found $deniedCount denied license(s) — review before shipping."
        exit 2
    }
    exit 0
}
catch {
    Write-Error "License check failed: $_"
    exit 1
}
