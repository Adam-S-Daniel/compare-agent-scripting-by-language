# Dependency License Checker
# Parses package manifests, looks up licenses (or mocks them), and produces
# a compliance report based on allow/deny lists.

# ─── Mock license database ───────────────────────────────────────────────────
# Maps package names to SPDX license identifiers for offline testing.
$script:MockLicenseDb = @{
    # npm packages
    "express"         = "MIT"
    "lodash"          = "MIT"
    "react"           = "MIT"
    "jest"            = "MIT"
    "eslint"          = "MIT"
    "webpack"         = "MIT"
    "babel-core"      = "MIT"
    "axios"           = "MIT"
    "moment"          = "MIT"
    "gpl-package"     = "GPL-3.0"
    "lgpl-package"    = "LGPL-2.1"
    # Python packages
    "requests"        = "Apache-2.0"
    "flask"           = "BSD-3-Clause"
    "django"          = "BSD-3-Clause"
    "numpy"           = "BSD-3-Clause"
    "pandas"          = "BSD-3-Clause"
    "pytest"          = "MIT"
    "gpl-library"     = "GPL-2.0"
    "agpl-service"    = "AGPL-3.0"
}

# ─── Function: Parse manifest file ──────────────────────────────────────────
function Get-ManifestDependencies {
    <#
    .SYNOPSIS
        Parses a dependency manifest and returns a list of {Name, Version} objects.
    .PARAMETER Path
        Path to the manifest file (package.json or requirements.txt).
    .PARAMETER IncludeDev
        Include dev/test dependencies (package.json only).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$IncludeDev
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest not found: '$Path'"
    }

    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $fileName = [System.IO.Path]::GetFileName($Path).ToLower()

    switch ($fileName) {
        "package.json" {
            return Parse-PackageJson -Path $Path -IncludeDev:$IncludeDev
        }
        "requirements.txt" {
            return Parse-RequirementsTxt -Path $Path
        }
        default {
            throw "Unsupported manifest type: '$fileName'. Supported: package.json, requirements.txt"
        }
    }
}

function Parse-PackageJson {
    param([string]$Path, [switch]$IncludeDev)

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $deps = @()

    if ($json.dependencies) {
        foreach ($name in $json.dependencies.PSObject.Properties.Name) {
            $deps += [PSCustomObject]@{
                Name    = $name
                Version = $json.dependencies.$name -replace '^[\^~>=<]+'
            }
        }
    }

    if ($IncludeDev -and $json.devDependencies) {
        foreach ($name in $json.devDependencies.PSObject.Properties.Name) {
            $deps += [PSCustomObject]@{
                Name    = $name
                Version = $json.devDependencies.$name -replace '^[\^~>=<]+'
            }
        }
    }

    return $deps
}

function Parse-RequirementsTxt {
    param([string]$Path)

    $lines = Get-Content $Path
    $deps  = @()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Skip blank lines and comments
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }

        # Match "package==version", "package>=version", etc.
        if ($trimmed -match '^([A-Za-z0-9_.\-]+)\s*[=<>!~]+\s*(.+)$') {
            $deps += [PSCustomObject]@{
                Name    = $Matches[1].Trim()
                Version = $Matches[2].Trim()
            }
        } else {
            # Package with no version constraint
            $deps += [PSCustomObject]@{
                Name    = $trimmed -replace '\[.*\]'  # strip extras
                Version = "any"
            }
        }
    }

    return $deps
}

# ─── Function: Look up license ───────────────────────────────────────────────
function Get-DependencyLicense {
    <#
    .SYNOPSIS
        Returns the SPDX license identifier for a package.
    .PARAMETER Name
        Package name.
    .PARAMETER Version
        Package version (used for real lookups; ignored in mock mode).
    .PARAMETER MockData
        Use the built-in mock database instead of a real registry call.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Version = "any",

        [bool]$MockData = $true
    )

    if ($MockData) {
        if ($script:MockLicenseDb.ContainsKey($Name)) {
            return $script:MockLicenseDb[$Name]
        }
        return "UNKNOWN"
    }

    # Real lookup placeholder — extend here for npm/PyPI registry calls
    throw "Real license lookup not implemented. Use -MockData `$true for testing."
}

# ─── Function: Check compliance ─────────────────────────────────────────────
function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Returns 'approved', 'denied', or 'unknown' for a given license.
    .PARAMETER License
        The SPDX license identifier string.
    .PARAMETER Config
        Hashtable with AllowList and DenyList string arrays.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$License,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Deny-list takes precedence
    if ($Config.DenyList -contains $License) {
        return "denied"
    }

    if ($Config.AllowList -contains $License) {
        return "approved"
    }

    return "unknown"
}

# ─── Function: Main entry point ──────────────────────────────────────────────
function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
        Parses a manifest, looks up licenses, and returns a compliance report.
    .PARAMETER ManifestPath
        Path to the dependency manifest file.
    .PARAMETER ConfigPath
        Path to the JSON license config file (AllowList / DenyList).
    .PARAMETER IncludeDev
        Include dev dependencies (package.json only).
    .PARAMETER MockData
        Use mock license database.
    .OUTPUTS
        Array of PSCustomObjects: Name, Version, License, Status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [switch]$IncludeDev,

        [bool]$MockData = $true
    )

    # Load config
    if (-not (Test-Path $ConfigPath)) {
        throw "License config not found: '$ConfigPath'"
    }
    $configJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $config = @{
        AllowList = [string[]]$configJson.AllowList
        DenyList  = [string[]]$configJson.DenyList
    }

    # Parse manifest
    $dependencies = Get-ManifestDependencies -Path $ManifestPath -IncludeDev:$IncludeDev

    # Build report
    $report = foreach ($dep in $dependencies) {
        $license = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -MockData $MockData
        $status  = Test-LicenseCompliance -License $license -Config $config

        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }

    return $report
}

# ─── Helper: Format and print report to console ──────────────────────────────
function Write-LicenseReport {
    param(
        [Parameter(Mandatory)]
        [object[]]$Report,

        [string]$Title = "Dependency License Compliance Report"
    )

    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
    Write-Host ""

    $approved = @($Report | Where-Object { $_.Status -eq "approved" })
    $denied   = @($Report | Where-Object { $_.Status -eq "denied" })
    $unknown  = @($Report | Where-Object { $_.Status -eq "unknown" })

    foreach ($entry in $Report) {
        $color = switch ($entry.Status) {
            "approved" { "Green" }
            "denied"   { "Red" }
            default    { "Yellow" }
        }
        Write-Host ("{0,-30} {1,-15} {2,-20} [{3}]" -f `
            $entry.Name, $entry.Version, $entry.License, $entry.Status.ToUpper()) `
            -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "Summary: $($approved.Count) approved, $($denied.Count) denied, $($unknown.Count) unknown" -ForegroundColor White

    if ($denied.Count -gt 0) {
        Write-Host "COMPLIANCE FAILURE: $($denied.Count) denied license(s) found." -ForegroundColor Red
        return 1
    }
    if ($unknown.Count -gt 0) {
        Write-Host "WARNING: $($unknown.Count) unknown license(s) require review." -ForegroundColor Yellow
    }
    return 0
}
