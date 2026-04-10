# DependencyLicenseChecker.psm1
# Module for parsing dependency manifests, checking licenses against allow/deny lists,
# and generating compliance reports.
#
# Approach:
# - Parse package.json and requirements.txt formats
# - Look up licenses via a pluggable lookup function (mockable for testing)
# - Compare against config-driven allow-list and deny-list
# - Produce a structured compliance report with approved/denied/unknown statuses

<#
.SYNOPSIS
    Parses a package.json file and extracts dependency names and versions.
.PARAMETER Path
    Path to the package.json file.
.OUTPUTS
    Array of objects with Name and Version properties.
#>
function Get-PackageJsonDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw
    $json = $content | ConvertFrom-Json

    $results = @()

    # Extract both dependencies and devDependencies
    foreach ($section in @('dependencies', 'devDependencies')) {
        if ($json.PSObject.Properties.Name -contains $section) {
            $deps = $json.$section
            foreach ($prop in $deps.PSObject.Properties) {
                $results += [PSCustomObject]@{
                    Name    = $prop.Name
                    Version = $prop.Value
                    Source  = $section
                }
            }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Parses a requirements.txt file and extracts dependency names and versions.
.PARAMETER Path
    Path to the requirements.txt file.
.OUTPUTS
    Array of objects with Name and Version properties.
#>
function Get-RequirementsTxtDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $lines = Get-Content -Path $Path
    $results = @()

    foreach ($line in $lines) {
        # Skip comments and blank lines
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) {
            continue
        }

        # Match patterns like: package==1.0.0, package>=1.0.0, package~=1.0.0, package
        if ($trimmed -match '^([A-Za-z0-9_.-]+)\s*([><=!~]+)\s*(.+)$') {
            $results += [PSCustomObject]@{
                Name    = $Matches[1]
                Version = $Matches[3].Trim()
                Source  = 'requirements.txt'
            }
        }
        elseif ($trimmed -match '^([A-Za-z0-9_.-]+)\s*$') {
            $results += [PSCustomObject]@{
                Name    = $Matches[1]
                Version = '*'
                Source  = 'requirements.txt'
            }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Parses any supported dependency manifest file.
.PARAMETER Path
    Path to the manifest file.
#>
function Get-Dependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $fileName = Split-Path -Leaf $Path

    switch ($fileName) {
        'package.json' { return Get-PackageJsonDependencies -Path $Path }
        'requirements.txt' { return Get-RequirementsTxtDependencies -Path $Path }
        default { throw "Unsupported manifest format: $fileName. Supported: package.json, requirements.txt" }
    }
}

<#
.SYNOPSIS
    Reads a license checker configuration file (JSON).
.PARAMETER Path
    Path to the config JSON file.
.DESCRIPTION
    Config format:
    {
        "allowedLicenses": ["MIT", "Apache-2.0"],
        "deniedLicenses": ["GPL-3.0"],
        "licenseLookup": { "express": "MIT", "lodash": "MIT" }
    }
#>
function Get-LicenseConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    $content = Get-Content -Path $Path -Raw
    $config = $content | ConvertFrom-Json

    # Validate required fields
    if (-not ($config.PSObject.Properties.Name -contains 'allowedLicenses')) {
        throw "Config missing required field: allowedLicenses"
    }
    if (-not ($config.PSObject.Properties.Name -contains 'deniedLicenses')) {
        throw "Config missing required field: deniedLicenses"
    }

    return $config
}

<#
.SYNOPSIS
    Looks up the license for a dependency using the provided lookup function.
.PARAMETER DependencyName
    Name of the dependency.
.PARAMETER LookupTable
    Hashtable mapping dependency names to license identifiers.
.OUTPUTS
    License string or $null if unknown.
#>
function Get-DependencyLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DependencyName,

        [Parameter(Mandatory)]
        [hashtable]$LookupTable
    )

    if ($LookupTable.ContainsKey($DependencyName)) {
        return $LookupTable[$DependencyName]
    }

    return $null
}

<#
.SYNOPSIS
    Determines the compliance status of a license.
.PARAMETER License
    The SPDX license identifier.
.PARAMETER AllowedLicenses
    Array of allowed license identifiers.
.PARAMETER DeniedLicenses
    Array of denied license identifiers.
.OUTPUTS
    "approved", "denied", or "unknown"
#>
function Get-LicenseStatus {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$License,

        [Parameter(Mandatory)]
        [string[]]$AllowedLicenses,

        [Parameter(Mandatory)]
        [string[]]$DeniedLicenses
    )

    if ([string]::IsNullOrEmpty($License)) {
        return 'unknown'
    }

    if ($DeniedLicenses -contains $License) {
        return 'denied'
    }

    if ($AllowedLicenses -contains $License) {
        return 'approved'
    }

    return 'unknown'
}

<#
.SYNOPSIS
    Generates a full compliance report for a dependency manifest.
.PARAMETER ManifestPath
    Path to the dependency manifest file.
.PARAMETER ConfigPath
    Path to the license checker config file.
.PARAMETER LookupOverride
    Optional hashtable to override the config's licenseLookup (useful for testing).
.OUTPUTS
    Object with Summary and Details properties.
#>
function New-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [hashtable]$LookupOverride
    )

    # Parse dependencies
    $deps = Get-Dependencies -Path $ManifestPath

    # Load config
    $config = Get-LicenseConfig -Path $ConfigPath

    # Build lookup table from config or override
    $lookup = @{}
    if ($LookupOverride) {
        $lookup = $LookupOverride
    }
    elseif ($config.PSObject.Properties.Name -contains 'licenseLookup') {
        foreach ($prop in $config.licenseLookup.PSObject.Properties) {
            $lookup[$prop.Name] = $prop.Value
        }
    }

    $allowedLicenses = @($config.allowedLicenses)
    $deniedLicenses = @($config.deniedLicenses)

    # Build report details
    $details = @()
    $approvedCount = 0
    $deniedCount = 0
    $unknownCount = 0

    foreach ($dep in $deps) {
        $license = Get-DependencyLicense -DependencyName $dep.Name -LookupTable $lookup
        $status = Get-LicenseStatus -License $license -AllowedLicenses $allowedLicenses -DeniedLicenses $deniedLicenses

        switch ($status) {
            'approved' { $approvedCount++ }
            'denied'   { $deniedCount++ }
            'unknown'  { $unknownCount++ }
        }

        $details += [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($license) { $license } else { 'UNKNOWN' }
            Status  = $status
        }
    }

    $report = [PSCustomObject]@{
        Summary = [PSCustomObject]@{
            Total    = $details.Count
            Approved = $approvedCount
            Denied   = $deniedCount
            Unknown  = $unknownCount
        }
        Details = $details
        HasDenied = ($deniedCount -gt 0)
    }

    return $report
}

<#
.SYNOPSIS
    Formats a compliance report as a readable text output.
.PARAMETER Report
    The report object from New-ComplianceReport.
#>
function Format-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Report
    )

    $output = @()
    $output += "=== Dependency License Compliance Report ==="
    $output += ""
    $output += "Summary:"
    $output += "  Total dependencies: $($Report.Summary.Total)"
    $output += "  Approved: $($Report.Summary.Approved)"
    $output += "  Denied: $($Report.Summary.Denied)"
    $output += "  Unknown: $($Report.Summary.Unknown)"
    $output += ""
    $output += "Details:"
    $output += ("-" * 70)
    $output += "{0,-30} {1,-15} {2,-15} {3}" -f "Package", "Version", "License", "Status"
    $output += ("-" * 70)

    foreach ($item in $Report.Details) {
        $statusLabel = switch ($item.Status) {
            'approved' { 'APPROVED' }
            'denied'   { 'DENIED' }
            'unknown'  { 'UNKNOWN' }
        }
        $output += "{0,-30} {1,-15} {2,-15} {3}" -f $item.Name, $item.Version, $item.License, $statusLabel
    }

    $output += ("-" * 70)

    if ($Report.HasDenied) {
        $output += ""
        $output += "WARNING: Denied licenses found! Review required."
    }

    return ($output -join "`n")
}

Export-ModuleMember -Function @(
    'Get-PackageJsonDependencies',
    'Get-RequirementsTxtDependencies',
    'Get-Dependencies',
    'Get-LicenseConfig',
    'Get-DependencyLicense',
    'Get-LicenseStatus',
    'New-ComplianceReport',
    'Format-ComplianceReport'
)
