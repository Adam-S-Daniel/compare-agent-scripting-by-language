# Dependency License Checker
# Parses dependency manifests and checks licenses against allow/deny lists

function Get-Dependencies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }

    $content = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json

    $dependencies = @()

    if ($null -ne $content.dependencies) {
        foreach ($name in $content.dependencies.PSObject.Properties.Name) {
            $version = $content.dependencies.$name
            $dependencies += @{
                name    = $name
                version = $version
            }
        }
    }

    return $dependencies
}

# Mock license lookup - returns predefined licenses for testing
function Get-DependencyLicense {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    # Mock data for common packages
    $licenseMockData = @{
        "express"         = "MIT"
        "lodash"          = "MIT"
        "axios"           = "MIT"
        "react"           = "MIT"
        "vue"             = "MIT"
        "@angular/core"   = "MIT"
        "django"          = "BSD"
        "flask"           = "BSD"
        "numpy"           = "BSD"
        "requests"        = "Apache-2.0"
        "tensorflow"      = "Apache-2.0"
        "eslint"          = "MIT"
        "webpack"         = "MIT"
        "typescript"      = "Apache-2.0"
        "jest"            = "MIT"
        "mocha"           = "MIT"
        "pm2"             = "AGPL-3.0"
        "redis"           = "GPL-3.0"
    }

    return $licenseMockData[$Name] ?? "Unknown"
}

function Check-LicenseCompliance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$License,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedLicenses,
        [Parameter(Mandatory = $true)]
        [string[]]$DeniedLicenses
    )

    if ($License -eq "Unknown") {
        return "unknown"
    }

    if ($DeniedLicenses -contains $License) {
        return "denied"
    }

    if ($AllowedLicenses -contains $License) {
        return "approved"
    }

    return "unknown"
}

function Generate-ComplianceReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Dependencies,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedLicenses,
        [Parameter(Mandatory = $true)]
        [string[]]$DeniedLicenses
    )

    $report = @()

    foreach ($dep in $Dependencies) {
        $license = Get-DependencyLicense -Name $dep.name -Version $dep.version
        $status = Check-LicenseCompliance -License $license -AllowedLicenses $AllowedLicenses -DeniedLicenses $DeniedLicenses

        $report += @{
            name    = $dep.name
            version = $dep.version
            license = $license
            status  = $status
        }
    }

    return $report
}

function Save-ComplianceReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Report,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("json", "csv")]
        [string]$Format
    )

    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path $parent)) {
        throw "Output directory does not exist: $parent"
    }

    if ($Format -eq "json") {
        $Report | ConvertTo-Json -AsArray | Out-File -FilePath $OutputPath -Encoding UTF8
    }
    elseif ($Format -eq "csv") {
        $Report | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $OutputPath -Encoding UTF8
    }
}
