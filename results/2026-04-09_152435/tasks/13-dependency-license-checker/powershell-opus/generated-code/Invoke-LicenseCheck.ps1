# Invoke-LicenseCheck.ps1
# Entry point script for the dependency license checker.
# Usage: pwsh Invoke-LicenseCheck.ps1 -ManifestPath <path> -ConfigPath <path>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath,

    [Parameter(Mandatory)]
    [string]$ConfigPath
)

# Import the module
Import-Module "$PSScriptRoot/DependencyLicenseChecker.psm1" -Force

try {
    # Generate the compliance report
    $report = New-ComplianceReport -ManifestPath $ManifestPath -ConfigPath $ConfigPath

    # Format and output the report
    $text = Format-ComplianceReport -Report $report
    Write-Output $text

    # Exit with non-zero if denied licenses found
    if ($report.HasDenied) {
        Write-Output ""
        Write-Output "RESULT: FAIL - Denied licenses detected"
        exit 1
    }
    else {
        Write-Output ""
        Write-Output "RESULT: PASS - All licenses compliant"
        exit 0
    }
}
catch {
    Write-Error "License check failed: $_"
    exit 2
}
