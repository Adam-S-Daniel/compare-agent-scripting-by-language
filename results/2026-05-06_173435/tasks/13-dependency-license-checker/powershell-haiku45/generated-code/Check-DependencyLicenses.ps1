#Requires -Version 7.0

<#
.SYNOPSIS
Checks dependencies in a manifest file against allow/deny license lists.

.DESCRIPTION
Parses package.json or requirements.txt, extracts dependencies with versions,
and generates a compliance report showing approved, denied, and unknown licenses.
Uses a mock license lookup for testing purposes.

.PARAMETER ManifestPath
Path to the dependency manifest file (package.json, requirements.txt, etc.)

.PARAMETER ConfigPath
Path to the license configuration file in JSON format.

.EXAMPLE
Check-DependencyLicensesReport -ManifestPath "./package.json" -ConfigPath "./license-config.json"
#>

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
    Validates license configuration structure.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )

    # Simply return the config if it has the expected structure
    if ($null -eq $Config.allowed -or $null -eq $Config.denied) {
        throw "License config must contain 'allowed' and 'denied' keys"
    }

    return $Config
}

function Get-Dependencies {
    <#
    .SYNOPSIS
    Extracts dependencies from a manifest file.

    .DESCRIPTION
    Supports package.json (Node.js) and requirements.txt (Python) formats.
    Returns an array of objects with name and version properties.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }

    $extension = [System.IO.Path]::GetExtension($ManifestPath).ToLower()
    $dependencies = @()

    if ($extension -eq ".json") {
        $manifest = Get-Content $ManifestPath | ConvertFrom-Json

        # Extract from dependencies and devDependencies
        if ($manifest.dependencies) {
            foreach ($dep in $manifest.dependencies.PSObject.Properties) {
                $dependencies += @{
                    name    = $dep.Name
                    version = $dep.Value
                }
            }
        }

        if ($manifest.devDependencies) {
            foreach ($dep in $manifest.devDependencies.PSObject.Properties) {
                $dependencies += @{
                    name    = $dep.Name
                    version = $dep.Value
                }
            }
        }
    }
    elseif ($extension -eq ".txt") {
        # Parse requirements.txt (name==version or name>=version, etc.)
        $lines = Get-Content $ManifestPath | Where-Object { $_ -and -not $_.StartsWith("#") }

        foreach ($line in $lines) {
            $line = $line.Trim()
            if ($line -match '([a-zA-Z0-9_-]+)\s*([><=!~]+)\s*(.+)') {
                $dependencies += @{
                    name    = $Matches[1]
                    version = $Matches[3]
                }
            }
        }
    }
    else {
        throw "Unsupported manifest format: $extension"
    }

    return @($dependencies)
}

function Get-LicenseForDependency {
    <#
    .SYNOPSIS
    Looks up the license for a dependency using a mock provider.

    .DESCRIPTION
    Uses the MockLicenses hashtable to simulate license lookups.
    Returns $null if the dependency is not found in the mock data.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [hashtable]$MockLicenses
    )

    return $MockLicenses[$PackageName]
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
    Generates a license compliance report for dependencies.

    .DESCRIPTION
    Analyzes each dependency against the allow/deny license lists
    and categorizes them as approved, denied, or unknown.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Dependencies,

        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $true)]
        [hashtable]$MockLicenses
    )

    $approved = @()
    $denied = @()
    $unknown = @()

    foreach ($dep in $Dependencies) {
        $license = Get-LicenseForDependency -PackageName $dep.name -MockLicenses $MockLicenses

        $depInfo = @{
            name    = $dep.name
            version = $dep.version
            license = $license
        }

        if ($null -eq $license) {
            $unknown += $depInfo
        }
        elseif ($Config.denied -contains $license) {
            $denied += $depInfo
        }
        elseif ($Config.allowed -contains $license) {
            $approved += $depInfo
        }
        else {
            $unknown += $depInfo
        }
    }

    return @{
        approved = $approved
        denied   = $denied
        unknown  = $unknown
        total    = $Dependencies.Count
    }
}

function Invoke-DependencyLicenseCheck {
    <#
    .SYNOPSIS
    Main entry point: parses manifest, checks licenses, generates report.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [hashtable]$MockLicenses = $null
    )

    # Load configuration
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content $ConfigPath | ConvertFrom-Json | ConvertTo-Hashtable

    # Parse manifest
    $dependencies = Get-Dependencies -ManifestPath $ManifestPath

    # Generate report
    if ($null -eq $MockLicenses) {
        $MockLicenses = @{}
    }

    $report = New-ComplianceReport -Dependencies $dependencies -Config $config -MockLicenses $MockLicenses

    return $report
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
    Converts a PSObject to a hashtable recursively.
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$Object
    )

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object
    }

    if ($Object -is [PSObject]) {
        $hash = @{}
        foreach ($prop in $Object.PSObject.Properties) {
            $hash[$prop.Name] = if ($prop.Value -is [PSObject]) {
                ConvertTo-Hashtable -Object $prop.Value
            }
            else {
                $prop.Value
            }
        }
        return $hash
    }

    return $Object
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
    Formats the compliance report as human-readable output.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Report
    )

    Write-Host "=== Dependency License Compliance Report ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Dependencies: $($Report.total)" -ForegroundColor White
    Write-Host ""

    Write-Host "✓ Approved ($($Report.approved.Count)):" -ForegroundColor Green
    foreach ($dep in $Report.approved) {
        Write-Host "  - $($dep.name) ($($dep.version)): $($dep.license)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✗ Denied ($($Report.denied.Count)):" -ForegroundColor Red
    foreach ($dep in $Report.denied) {
        Write-Host "  - $($dep.name) ($($dep.version)): $($dep.license)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "? Unknown ($($Report.unknown.Count)):" -ForegroundColor Yellow
    foreach ($dep in $Report.unknown) {
        Write-Host "  - $($dep.name) ($($dep.version))" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Compliant: $($Report.approved.Count + $Report.unknown.Count) / $($Report.total)"
    Write-Host "  Non-Compliant: $($Report.denied.Count) / $($Report.total)"
}
