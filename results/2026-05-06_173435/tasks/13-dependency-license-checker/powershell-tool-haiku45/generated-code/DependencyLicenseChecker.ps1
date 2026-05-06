# Dependency License Checker - Main Script
# Parses dependency manifests, checks licenses against allow/deny lists, generates compliance reports

function Parse-PackageJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    # Parse JSON content
    try {
        $json = $Content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JSON: $_"
    }

    # Extract dependencies
    $dependencies = @()
    if ($json.dependencies) {
        foreach ($depName in $json.dependencies.PSObject.Properties.Name) {
            $dependencies += @{
                Name    = $depName
                Version = $json.dependencies.$depName
            }
        }
    }

    return $dependencies
}

function Parse-ManifestFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw
    return Parse-PackageJson -Content $content
}

function Get-MockLicense {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DependencyName,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    # Mock license database
    $mockLicenses = @{
        "lodash"   = @{ Name = "lodash"; Version = "4.17.21"; LicenseType = "MIT" }
        "axios"    = @{ Name = "axios"; Version = "1.4.0"; LicenseType = "Apache-2.0" }
        "gpl-lib"  = @{ Name = "gpl-lib"; Version = "1.0.0"; LicenseType = "GPL-3.0" }
        "express"  = @{ Name = "express"; Version = "4.18.0"; LicenseType = "MIT" }
        "react"    = @{ Name = "react"; Version = "18.0.0"; LicenseType = "MIT" }
    }

    if ($mockLicenses.ContainsKey($DependencyName)) {
        return $mockLicenses[$DependencyName]
    }

    return $null
}

function Check-LicenseCompliance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LicenseType,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowList,

        [Parameter(Mandatory = $true)]
        [string[]]$DenyList
    )

    if ($DenyList -contains $LicenseType) {
        return "denied"
    }

    if ($AllowList -contains $LicenseType) {
        return "approved"
    }

    return "unknown"
}

function Generate-ComplianceReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Dependencies,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowList,

        [Parameter(Mandatory = $true)]
        [string[]]$DenyList
    )

    $report = @()

    foreach ($dep in $Dependencies) {
        $status = Check-LicenseCompliance -LicenseType $dep.License -AllowList $AllowList -DenyList $DenyList

        $report += @{
            Name    = $dep.Name
            Version = $dep.Version
            License = $dep.License
            Status  = $status
        }
    }

    return $report
}

function Export-ComplianceReport {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Report,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # Export as JSON
    $Report | ConvertTo-Json | Set-Content -Path $OutputPath

    # Also export as formatted text
    $textPath = $OutputPath -replace '\.json$', '.txt'
    $textContent = @"
=== DEPENDENCY LICENSE COMPLIANCE REPORT ===
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

SUMMARY:
--------
Total Dependencies: $($Report.Count)
Approved: $(($Report | Where-Object { $_.Status -eq 'approved' }).Count)
Denied: $(($Report | Where-Object { $_.Status -eq 'denied' }).Count)
Unknown: $(($Report | Where-Object { $_.Status -eq 'unknown' }).Count)

DETAILS:
--------
"@

    foreach ($entry in $Report) {
        $textContent += "`n$($entry.Name) ($($entry.Version)): $($entry.License) - [$($entry.Status)]"
    }

    $textContent | Set-Content -Path $textPath
}
