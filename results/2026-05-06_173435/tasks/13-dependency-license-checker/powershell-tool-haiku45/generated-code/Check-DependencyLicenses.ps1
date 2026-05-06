#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks dependencies in a manifest file against license allow/deny lists.

.DESCRIPTION
    Parses a dependency manifest (package.json, requirements.txt), looks up
    each dependency's license in a mocked provider, and generates a compliance
    report with each dependency's license status.

.PARAMETER ManifestPath
    Path to the manifest file (package.json, requirements.txt, etc.)

.PARAMETER ConfigPath
    Path to the license configuration file (JSON with allowedLicenses and deniedLicenses)

.PARAMETER OutputPath
    Path where the compliance report will be written (default: compliance-report.json)

.EXAMPLE
    .\Check-DependencyLicenses.ps1 -ManifestPath package.json -ConfigPath license-config.json
#>

param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the dependency manifest file")]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true, HelpMessage = "Path to the license configuration file")]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false, HelpMessage = "Output path for compliance report")]
    [string]$OutputPath = "compliance-report.json"
)

$ErrorActionPreference = "Stop"

# Import the DependencyLicenseChecker module
$scriptDir = Split-Path -Parent $PSCommandPath
$modulePath = Join-Path $scriptDir "DependencyLicenseChecker.ps1"

if (-not (Test-Path $modulePath)) {
    Write-Error "Cannot find DependencyLicenseChecker.ps1 at $modulePath"
    exit 1
}

. $modulePath

try {
    # Validate input files exist
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Load configuration
    Write-Verbose "Loading configuration from $ConfigPath"
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    $allowList = $config.allowedLicenses
    $denyList = $config.deniedLicenses

    if (-not $allowList -or $allowList.Count -eq 0) {
        throw "Configuration must contain 'allowedLicenses' array"
    }

    if (-not $denyList -or $denyList.Count -eq 0) {
        throw "Configuration must contain 'deniedLicenses' array"
    }

    # Parse manifest
    Write-Verbose "Parsing manifest from $ManifestPath"
    $dependencies = Parse-ManifestFile -Path $ManifestPath

    if ($dependencies.Count -eq 0) {
        Write-Warning "No dependencies found in manifest"
    }

    # Look up licenses and create report
    Write-Verbose "Looking up licenses and generating compliance report"
    $report = @()

    foreach ($dep in $dependencies) {
        $license = Get-MockLicense -DependencyName $dep.Name -Version $dep.Version

        if ($null -eq $license) {
            # License not found in mock database
            $licenseType = "UNKNOWN"
        }
        else {
            $licenseType = $license.LicenseType
        }

        $status = Check-LicenseCompliance -LicenseType $licenseType -AllowList $allowList -DenyList $denyList

        $report += @{
            Name    = $dep.Name
            Version = $dep.Version
            License = $licenseType
            Status  = $status
        }
    }

    # Export report
    Write-Verbose "Exporting compliance report to $OutputPath"
    Export-ComplianceReport -Report $report -OutputPath $OutputPath

    # Display summary
    $approvedCount = ($report | Where-Object { $_.Status -eq "approved" }).Count
    $deniedCount = ($report | Where-Object { $_.Status -eq "denied" }).Count
    $unknownCount = ($report | Where-Object { $_.Status -eq "unknown" }).Count

    Write-Host ""
    Write-Host "=== DEPENDENCY LICENSE COMPLIANCE REPORT ==="
    Write-Host "Manifest: $ManifestPath"
    Write-Host "Configuration: $ConfigPath"
    Write-Host ""
    Write-Host "SUMMARY:"
    Write-Host "--------"
    Write-Host "Total Dependencies: $($report.Count)"
    Write-Host "Approved: $approvedCount"
    Write-Host "Denied: $deniedCount"
    Write-Host "Unknown: $unknownCount"
    Write-Host ""

    # Exit with error if any dependencies are denied
    if ($deniedCount -gt 0) {
        Write-Host "DENIED LICENSES:"
        $report | Where-Object { $_.Status -eq "denied" } | ForEach-Object {
            Write-Host "  - $($_.Name) ($($_.Version)): $($_.License)"
        }
        Write-Host ""
        Write-Error "License compliance check FAILED: $deniedCount denied license(s) found"
        exit 1
    }

    Write-Host "License compliance check PASSED"
    exit 0
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
    exit 1
}
