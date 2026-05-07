# Dependency License Checker - Core Functions
# Parses dependency manifests, checks licenses against allow/deny lists,
# and generates a compliance report. Mocked license lookup via config DB.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Parse-PackageJson {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    $dependencies = @()

    if ($content.PSObject.Properties['dependencies']) {
        foreach ($prop in $content.dependencies.PSObject.Properties) {
            $dependencies += @{
                Name    = $prop.Name
                Version = $prop.Value -replace '[\^~>=<]', ''
                Type    = "production"
            }
        }
    }

    if ($content.PSObject.Properties['devDependencies']) {
        foreach ($prop in $content.devDependencies.PSObject.Properties) {
            $dependencies += @{
                Name    = $prop.Name
                Version = $prop.Value -replace '[\^~>=<]', ''
                Type    = "development"
            }
        }
    }

    return $dependencies
}

function Parse-RequirementsTxt {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $dependencies = @()
    $lines = Get-Content -Path $Path

    foreach ($line in $lines) {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        if ($line -match '^([a-zA-Z0-9_.-]+)==(.+)$') {
            $dependencies += @{
                Name    = $Matches[1]
                Version = $Matches[2]
                Type    = "production"
            }
        }
        elseif ($line -match '^([a-zA-Z0-9_.-]+)([><=!]+.+)?$') {
            $version = if ($Matches[2]) { $Matches[2] -replace '[><=!]', '' } else { "unspecified" }
            $dependencies += @{
                Name    = $Matches[1]
                Version = $version
                Type    = "production"
            }
        }
    }

    return $dependencies
}

function Get-LicenseForDependency {
    param(
        [string]$DependencyName,
        [hashtable]$LicenseDatabase
    )

    if ($LicenseDatabase.ContainsKey($DependencyName)) {
        return $LicenseDatabase[$DependencyName]
    }

    return $null
}

function Get-LicenseStatus {
    param(
        [string]$License,
        [string[]]$AllowedLicenses,
        [string[]]$DeniedLicenses
    )

    if ([string]::IsNullOrEmpty($License)) {
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

function Read-LicenseConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json

    $licenseDb = @{}
    if ($content.PSObject.Properties['licenseDatabase']) {
        foreach ($prop in $content.licenseDatabase.PSObject.Properties) {
            $licenseDb[$prop.Name] = $prop.Value
        }
    }

    return @{
        AllowedLicenses = @($content.allowedLicenses)
        DeniedLicenses  = @($content.deniedLicenses)
        LicenseDatabase = $licenseDb
    }
}

function Invoke-LicenseCheck {
    param(
        [string]$ManifestPath,
        [string]$ConfigPath
    )

    $config = Read-LicenseConfig -Path $ConfigPath

    $extension = [System.IO.Path]::GetFileName($ManifestPath)
    $dependencies = @()

    if ($extension -eq "package.json") {
        $dependencies = Parse-PackageJson -Path $ManifestPath
    }
    elseif ($extension -eq "requirements.txt") {
        $dependencies = Parse-RequirementsTxt -Path $ManifestPath
    }
    else {
        throw "Unsupported manifest format: $extension"
    }

    $results = @()
    foreach ($dep in $dependencies) {
        $license = Get-LicenseForDependency -DependencyName $dep.Name -LicenseDatabase $config.LicenseDatabase
        $status = Get-LicenseStatus -License $license -AllowedLicenses $config.AllowedLicenses -DeniedLicenses $config.DeniedLicenses

        $results += @{
            Name    = $dep.Name
            Version = $dep.Version
            Type    = $dep.Type
            License = if ($license) { $license } else { "UNKNOWN" }
            Status  = $status
        }
    }

    return $results
}

function Format-ComplianceReport {
    param(
        [array]$Results,
        [string]$ManifestPath
    )

    $approved = @($Results | Where-Object { $_.Status -eq "approved" })
    $denied = @($Results | Where-Object { $_.Status -eq "denied" })
    $unknown = @($Results | Where-Object { $_.Status -eq "unknown" })

    $report = @()
    $report += "=== Dependency License Compliance Report ==="
    $report += "Manifest: $ManifestPath"
    $report += "Total dependencies: $($Results.Count)"
    $report += "Approved: $($approved.Count) | Denied: $($denied.Count) | Unknown: $($unknown.Count)"
    $report += ""
    $report += "--- Details ---"

    foreach ($r in $Results) {
        $statusTag = switch ($r.Status) {
            "approved" { "[APPROVED]" }
            "denied"   { "[DENIED]" }
            "unknown"  { "[UNKNOWN]" }
        }
        $report += "$statusTag $($r.Name)@$($r.Version) - License: $($r.License) ($($r.Type))"
    }

    $report += ""
    if ($denied.Count -gt 0) {
        $report += "WARNING: $($denied.Count) dependencies have denied licenses!"
        $report += "RESULT: FAIL"
    }
    elseif ($unknown.Count -gt 0) {
        $report += "NOTE: $($unknown.Count) dependencies have unknown license status."
        $report += "RESULT: WARN"
    }
    else {
        $report += "All dependencies have approved licenses."
        $report += "RESULT: PASS"
    }

    return $report -join "`n"
}
