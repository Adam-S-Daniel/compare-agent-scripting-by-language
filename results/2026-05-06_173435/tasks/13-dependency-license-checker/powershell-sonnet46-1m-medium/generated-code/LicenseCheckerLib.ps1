# LicenseCheckerLib.ps1
# Library of functions for dependency license checking.
# Dot-source this file to make all functions available.

function Get-Dependencies {
    <#
    .SYNOPSIS
    Parses a package.json manifest and returns a list of dependencies.
    #>
    param(
        [Parameter(Mandatory)][string]$ManifestPath
    )
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }
    $manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json
    if (-not $manifest.dependencies) {
        return @()
    }
    $deps = @()
    foreach ($prop in $manifest.dependencies.PSObject.Properties) {
        # Strip leading ^ or ~ from semver strings (e.g. "^4.17.21" -> "4.17.21")
        $version = $prop.Value -replace '^[\^~]', ''
        $deps += [PSCustomObject]@{ Name = $prop.Name; Version = $version }
    }
    return $deps
}

function Get-LicenseFromMockData {
    <#
    .SYNOPSIS
    Looks up a package license from a mock hashtable.
    Returns null when the package is not in the mock data.
    #>
    param(
        [Parameter(Mandatory)][string]$PackageName,
        [Parameter(Mandatory)][hashtable]$MockLicenses
    )
    return $MockLicenses[$PackageName]
}

function Get-ComplianceStatus {
    <#
    .SYNOPSIS
    Determines compliance status for a given license string.
    Returns "APPROVED", "DENIED", or "UNKNOWN".
    #>
    param(
        [string]$License,
        [Parameter(Mandatory)][PSCustomObject]$Config
    )
    if ([string]::IsNullOrEmpty($License)) { return "UNKNOWN" }
    if ($Config.allowedLicenses -contains $License) { return "APPROVED" }
    if ($Config.deniedLicenses  -contains $License) { return "DENIED" }
    return "UNKNOWN"
}

function ConvertPSObjectToHashtable {
    param([PSCustomObject]$InputObject)
    $ht = @{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        $ht[$prop.Name] = $prop.Value
    }
    return $ht
}

function Get-ComplianceReport {
    <#
    .SYNOPSIS
    Runs the full compliance pipeline: parse manifest, mock-lookup licenses,
    classify each dependency, and return an array of report entries.
    #>
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$MockLicensesPath
    )
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    if (-not (Test-Path $MockLicensesPath)) {
        throw "Mock licenses file not found: $MockLicensesPath"
    }

    $dependencies  = Get-Dependencies -ManifestPath $ManifestPath
    $config        = Get-Content -Raw $ConfigPath | ConvertFrom-Json
    $mockLicenses  = Get-Content -Raw $MockLicensesPath | ConvertFrom-Json |
                     ForEach-Object { ConvertPSObjectToHashtable -InputObject $_ }

    $report = @()
    foreach ($dep in $dependencies) {
        $license = Get-LicenseFromMockData -PackageName $dep.Name -MockLicenses $mockLicenses
        if ([string]::IsNullOrEmpty($license)) { $license = "UNKNOWN-LICENSE" }
        $status  = Get-ComplianceStatus -License $license -Config $config
        $report += [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }
    return $report
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
    Formats a compliance report array into a human-readable string.
    #>
    param(
        [Parameter(Mandatory)][array]$Report
    )
    $lines = @("=== Dependency License Compliance Report ===")

    foreach ($entry in $Report) {
        $lines += "$($entry.Name)@$($entry.Version): $($entry.License) [$($entry.Status)]"
    }

    $total    = $Report.Count
    $approved = ($Report | Where-Object { $_.Status -eq "APPROVED" }).Count
    $denied   = ($Report | Where-Object { $_.Status -eq "DENIED"   }).Count
    $unknown  = ($Report | Where-Object { $_.Status -eq "UNKNOWN"  }).Count

    $lines += ""
    $lines += "Summary: $total total, $approved approved, $denied denied, $unknown unknown"

    if ($denied -gt 0) {
        $lines += "Status: FAILED - $denied denied license(s) detected"
    } else {
        $lines += "Status: PASSED - no denied licenses found"
    }

    return $lines -join "`n"
}
