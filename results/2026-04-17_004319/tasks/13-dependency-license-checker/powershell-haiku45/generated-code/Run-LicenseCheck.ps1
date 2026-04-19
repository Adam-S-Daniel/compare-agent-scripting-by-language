#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [string]$OutputPath = "./dependency-license-report.json",

    [string]$OutputFormat = "json"
)

. $PSScriptRoot/DependencyLicenseChecker.ps1

function Main {
    Write-Host "Dependency License Checker" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan

    # Load configuration
    Write-Host "Loading configuration from: $ConfigPath"
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration file not found: $ConfigPath"
        exit 1
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $allowedLicenses = $config.allowedLicenses
    $deniedLicenses = $config.deniedLicenses

    Write-Host "Allowed licenses: $($allowedLicenses -join ', ')"
    Write-Host "Denied licenses: $($deniedLicenses -join ', ')"

    # Parse dependencies
    Write-Host "`nParsing dependencies from: $ManifestPath"
    $dependencies = Get-Dependencies -ManifestPath $ManifestPath
    Write-Host "Found $($dependencies.Count) dependencies"

    # Generate report
    Write-Host "`nGenerating compliance report..."
    $report = Generate-ComplianceReport -Dependencies $dependencies `
        -AllowedLicenses $allowedLicenses -DeniedLicenses $deniedLicenses

    # Display results
    Write-Host "`n================================================"
    Write-Host "COMPLIANCE REPORT" -ForegroundColor Cyan
    Write-Host "================================================"

    $approved = $report | Where-Object { $_.status -eq "approved" }
    $denied = $report | Where-Object { $_.status -eq "denied" }
    $unknown = $report | Where-Object { $_.status -eq "unknown" }

    Write-Host "`nApproved ($($approved.Count)):" -ForegroundColor Green
    foreach ($item in $approved) {
        Write-Host "  ✓ $($item.name)@$($item.version) [$($item.license)]"
    }

    if ($denied.Count -gt 0) {
        Write-Host "`nDenied ($($denied.Count)):" -ForegroundColor Red
        foreach ($item in $denied) {
            Write-Host "  ✗ $($item.name)@$($item.version) [$($item.license)]"
        }
    }

    if ($unknown.Count -gt 0) {
        Write-Host "`nUnknown ($($unknown.Count)):" -ForegroundColor Yellow
        foreach ($item in $unknown) {
            Write-Host "  ? $($item.name)@$($item.version) [$($item.license)]"
        }
    }

    # Save report
    Write-Host "`nSaving report to: $OutputPath"
    Save-ComplianceReport -Report $report -OutputPath $OutputPath -Format $OutputFormat

    # Exit with error if any denied licenses found
    if ($denied.Count -gt 0) {
        Write-Host "`n[ERROR] Found $($denied.Count) dependency/dependencies with denied licenses!" -ForegroundColor Red
        exit 1
    }

    Write-Host "`n[SUCCESS] All dependencies have approved or unknown licenses!" -ForegroundColor Green
    exit 0
}

Main
