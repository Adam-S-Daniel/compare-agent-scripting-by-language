# DependencyLicenseChecker.ps1
# Parses dependency manifests (package.json, requirements.txt), checks each
# dependency's license against allow/deny lists, and generates a compliance report.
#
# TDD approach: tests were written first (see DependencyLicenseChecker.Tests.ps1),
# then this implementation was built to satisfy them.

<#
.SYNOPSIS
    Parse a dependency manifest and extract dependency names and versions.
.PARAMETER Path
    Path to the manifest file (package.json or requirements.txt).
.OUTPUTS
    Array of objects with Name and Version properties.
#>
function Import-DependencyManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    $fileName = [System.IO.Path]::GetFileName($Path).ToLower()

    # Detect format based on file name or extension
    if ($fileName -eq 'package.json' -or $extension -eq '.json') {
        return Import-PackageJson -Path $Path
    }
    elseif ($fileName -eq 'requirements.txt' -or $extension -eq '.txt') {
        return Import-RequirementsTxt -Path $Path
    }
    else {
        throw "Unsupported manifest format: $fileName. Supported: package.json, requirements.txt"
    }
}

<#
.SYNOPSIS
    Parse a Node.js package.json and extract dependencies.
#>
function Import-PackageJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $content = Get-Content -Path $Path -Raw -ErrorAction Stop
    $json = $content | ConvertFrom-Json -ErrorAction Stop

    $dependencies = @()

    # Extract from "dependencies" section
    if ($json.PSObject.Properties['dependencies']) {
        $json.dependencies.PSObject.Properties | ForEach-Object {
            $dependencies += [PSCustomObject]@{
                Name    = $_.Name
                Version = $_.Value -replace '[\^~>=<]', ''
            }
        }
    }

    # Extract from "devDependencies" section
    if ($json.PSObject.Properties['devDependencies']) {
        $json.devDependencies.PSObject.Properties | ForEach-Object {
            $dependencies += [PSCustomObject]@{
                Name    = $_.Name
                Version = $_.Value -replace '[\^~>=<]', ''
            }
        }
    }

    if ($dependencies.Count -eq 0) {
        Write-Warning "No dependencies found in $Path"
    }

    return $dependencies
}

<#
.SYNOPSIS
    Parse a Python requirements.txt and extract dependencies.
#>
function Import-RequirementsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $lines = Get-Content -Path $Path -ErrorAction Stop
    $dependencies = @()

    foreach ($line in $lines) {
        # Skip comments and blank lines
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        # Parse formats like: package==1.0.0, package>=1.0.0, package~=1.0.0, or just package
        if ($trimmed -match '^([a-zA-Z0-9_.-]+)\s*([=~!<>]+)\s*(.+)$') {
            $dependencies += [PSCustomObject]@{
                Name    = $Matches[1]
                Version = $Matches[3].Trim()
            }
        }
        elseif ($trimmed -match '^([a-zA-Z0-9_.-]+)\s*$') {
            $dependencies += [PSCustomObject]@{
                Name    = $Matches[1]
                Version = 'any'
            }
        }
    }

    if ($dependencies.Count -eq 0) {
        Write-Warning "No dependencies found in $Path"
    }

    return $dependencies
}

<#
.SYNOPSIS
    Look up the license for a dependency using a mock license database.
.PARAMETER Name
    The dependency name.
.PARAMETER Version
    The dependency version.
.PARAMETER LicenseDbPath
    Path to the JSON file serving as a mock license database.
.OUTPUTS
    License string or "Unknown" if not found.
#>
function Get-DependencyLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Version = '',

        [Parameter(Mandatory)]
        [string]$LicenseDbPath
    )

    if (-not (Test-Path $LicenseDbPath)) {
        throw "License database not found: $LicenseDbPath"
    }

    $db = Get-Content -Path $LicenseDbPath -Raw | ConvertFrom-Json -ErrorAction Stop

    # Look up by package name (case-insensitive)
    $entry = $db.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1

    if ($entry) {
        return $entry.Value
    }

    return 'Unknown'
}

<#
.SYNOPSIS
    Load the license configuration (allow-list and deny-list).
.PARAMETER ConfigPath
    Path to the license-config.json file.
#>
function Import-LicenseConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "License config not found: $ConfigPath"
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
    return $config
}

<#
.SYNOPSIS
    Determine if a license is approved, denied, or unknown based on config.
.PARAMETER License
    The license string to check.
.PARAMETER Config
    The license config object with allowedLicenses and deniedLicenses arrays.
.OUTPUTS
    "approved", "denied", or "unknown"
#>
function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$License,

        [Parameter(Mandatory)]
        [object]$Config
    )

    # Unknown license from DB lookup
    if ($License -eq 'Unknown') {
        return 'unknown'
    }

    # Check deny-list first (deny takes precedence)
    if ($Config.deniedLicenses -contains $License) {
        return 'denied'
    }

    # Check allow-list
    if ($Config.allowedLicenses -contains $License) {
        return 'approved'
    }

    # License is known but not in either list
    return 'unknown'
}

<#
.SYNOPSIS
    Generate a full compliance report for all dependencies in a manifest.
.PARAMETER ManifestPath
    Path to the dependency manifest file.
.PARAMETER ConfigPath
    Path to the license configuration file.
.PARAMETER LicenseDbPath
    Path to the mock license database.
.OUTPUTS
    String containing the formatted compliance report.
#>
function New-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [string]$LicenseDbPath
    )

    # Parse the manifest
    $dependencies = Import-DependencyManifest -Path $ManifestPath

    # Load config
    $config = Import-LicenseConfig -ConfigPath $ConfigPath

    # Classify each dependency
    $results = @()
    foreach ($dep in $dependencies) {
        $license = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -LicenseDbPath $LicenseDbPath
        $status = Test-LicenseCompliance -License $license -Config $config
        $results += [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }

    # Count by status
    $approvedCount = ($results | Where-Object { $_.Status -eq 'approved' }).Count
    $deniedCount   = ($results | Where-Object { $_.Status -eq 'denied' }).Count
    $unknownCount  = ($results | Where-Object { $_.Status -eq 'unknown' }).Count

    # Determine overall status
    $overallStatus = if ($deniedCount -gt 0 -or $unknownCount -gt 0) { 'FAIL' } else { 'PASS' }

    # Build the report
    $manifestName = [System.IO.Path]::GetFileName($ManifestPath)
    $report = @()
    $report += '=== Dependency License Compliance Report ==='
    $report += "Manifest: $manifestName"
    $report += "Total Dependencies: $($results.Count)"
    $report += ''

    # Group by status and output
    $approved = $results | Where-Object { $_.Status -eq 'approved' }
    $denied   = $results | Where-Object { $_.Status -eq 'denied' }
    $unknown  = $results | Where-Object { $_.Status -eq 'unknown' }

    if ($approved) {
        foreach ($dep in $approved) {
            $report += "[APPROVED] $($dep.Name)@$($dep.Version) - $($dep.License)"
        }
    }

    if ($denied) {
        foreach ($dep in $denied) {
            $report += "[DENIED] $($dep.Name)@$($dep.Version) - $($dep.License)"
        }
    }

    if ($unknown) {
        foreach ($dep in $unknown) {
            $report += "[UNKNOWN] $($dep.Name)@$($dep.Version) - $($dep.License)"
        }
    }

    $report += ''
    $report += "Summary: $approvedCount approved, $deniedCount denied, $unknownCount unknown"
    $report += "Overall Status: $overallStatus"

    return $report -join "`n"
}

# Entry point: if run directly with parameters, generate the report
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.InvocationName -ne '') {
    param(
        [string]$ManifestPath,
        [string]$ConfigPath,
        [string]$LicenseDbPath
    )

    if ($ManifestPath -and $ConfigPath -and $LicenseDbPath) {
        $report = New-ComplianceReport -ManifestPath $ManifestPath -ConfigPath $ConfigPath -LicenseDbPath $LicenseDbPath
        Write-Output $report
    }
}
