# LicenseChecker.psm1
# Dependency License Checker Module
#
# Parses dependency manifests, looks up licenses, classifies compliance,
# and generates reports. All license lookup is injectable for testability.
#
# TDD cycle summary:
#   RED   (cycle 1) - Tests for Read-DependencyManifest written first
#   GREEN (cycle 1) - Read-DependencyManifest implemented
#   RED   (cycle 2) - Tests for Test-LicenseCompliance written
#   GREEN (cycle 2) - Test-LicenseCompliance implemented
#   RED   (cycle 3) - Tests for Invoke-LicenseLookup written
#   GREEN (cycle 3) - Invoke-LicenseLookup implemented with built-in mock db
#   RED   (cycle 4) - Tests for New-ComplianceReport written
#   GREEN (cycle 4) - New-ComplianceReport implemented
#   RED   (cycle 5) - Tests for Export-ComplianceReport written
#   GREEN (cycle 5) - Export-ComplianceReport implemented

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

function ConvertFrom-PackageJson {
    <#
    .SYNOPSIS
        Parses a package.json file and returns dependency objects.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [string]$Content,
        [switch]$IncludeDev
    )

    [PSCustomObject]$json = $Content | ConvertFrom-Json
    [System.Collections.Generic.List[PSCustomObject]]$deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Process runtime dependencies
    if ($null -ne $json.dependencies) {
        foreach ($prop in $json.dependencies.PSObject.Properties) {
            $deps.Add([PSCustomObject]@{
                Name    = [string]$prop.Name
                Version = [string]$prop.Value
            })
        }
    }

    # Optionally include devDependencies
    if ($IncludeDev -and $null -ne $json.devDependencies) {
        foreach ($prop in $json.devDependencies.PSObject.Properties) {
            $deps.Add([PSCustomObject]@{
                Name    = [string]$prop.Name
                Version = [string]$prop.Value
            })
        }
    }

    return $deps
}

function ConvertFrom-RequirementsTxt {
    <#
    .SYNOPSIS
        Parses a requirements.txt file and returns dependency objects.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSCustomObject]])]
    param(
        [string]$Content
    )

    [System.Collections.Generic.List[PSCustomObject]]$deps = [System.Collections.Generic.List[PSCustomObject]]::new()
    [string[]]$lines = $Content -split "`n"

    foreach ($rawLine in $lines) {
        [string]$line = $rawLine.Trim()

        # Skip blank lines and comment lines
        if ($line -eq '' -or $line.StartsWith('#')) {
            continue
        }

        # Handle version-pinned entries like "requests==2.28.0"
        if ($line -match '^([A-Za-z0-9_\-\.]+)==(.+)$') {
            $deps.Add([PSCustomObject]@{
                Name    = [string]$Matches[1]
                Version = [string]$Matches[2].Trim()
            })
        }
        elseif ($line -match '^([A-Za-z0-9_\-\.]+)(.*)$') {
            # Package with no version pinning or other specifiers
            $deps.Add([PSCustomObject]@{
                Name    = [string]$Matches[1]
                Version = [string]''
            })
        }
    }

    return $deps
}

# ---------------------------------------------------------------------------
# Public functions
# ---------------------------------------------------------------------------

function Read-DependencyManifest {
    <#
    .SYNOPSIS
        Reads a dependency manifest file and returns a list of dependency objects.
    .DESCRIPTION
        Supports package.json (npm) and requirements.txt (pip) formats.
        Each returned object has Name and Version properties.
    .PARAMETER ManifestPath
        Path to the dependency manifest file.
    .PARAMETER IncludeDev
        When set, include dev/test dependencies (applies to package.json).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [switch]$IncludeDev
    )

    # Validate file existence
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest file not found: '$ManifestPath'"
    }

    [string]$ext = [System.IO.Path]::GetExtension($ManifestPath).ToLowerInvariant()
    [string]$fileName = [System.IO.Path]::GetFileName($ManifestPath).ToLowerInvariant()
    [string]$content  = Get-Content -LiteralPath $ManifestPath -Raw

    if ($fileName -eq 'package.json' -or $ext -eq '.json') {
        [System.Collections.Generic.List[PSCustomObject]]$result = ConvertFrom-PackageJson -Content $content -IncludeDev:$IncludeDev
        return [PSCustomObject[]]$result.ToArray()
    }
    elseif ($fileName -eq 'requirements.txt' -or $ext -eq '.txt') {
        [System.Collections.Generic.List[PSCustomObject]]$result = ConvertFrom-RequirementsTxt -Content $content
        return [PSCustomObject[]]$result.ToArray()
    }
    else {
        throw "Unsupported manifest format (unsupported extension '$ext'). Supported: package.json, requirements.txt"
    }
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Classifies a license string as 'approved', 'denied', or 'unknown'.
    .DESCRIPTION
        - 'denied'   takes priority: if the license appears in DenyList, returns 'denied'.
        - 'approved' if the license appears in AllowList.
        - 'unknown'  if not found in either list, or if the license string is empty.
    .PARAMETER License
        The SPDX license identifier to classify.
    .PARAMETER AllowList
        Array of approved license identifiers (case-insensitive).
    .PARAMETER DenyList
        Array of denied license identifiers (case-insensitive). Takes priority.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$License,

        [Parameter(Mandatory)]
        [string[]]$AllowList,

        [Parameter(Mandatory)]
        [string[]]$DenyList
    )

    # Empty or null license — cannot classify
    if ([string]::IsNullOrWhiteSpace($License)) {
        return 'unknown'
    }

    [string]$normalised = $License.ToUpperInvariant()

    # Deny list has highest priority
    [string[]]$upperDeny = $DenyList | ForEach-Object { [string]$_.ToUpperInvariant() }
    if ($upperDeny -contains $normalised) {
        return 'denied'
    }

    # Check allow list
    [string[]]$upperAllow = $AllowList | ForEach-Object { [string]$_.ToUpperInvariant() }
    if ($upperAllow -contains $normalised) {
        return 'approved'
    }

    return 'unknown'
}

function Invoke-LicenseLookup {
    <#
    .SYNOPSIS
        Looks up the license for a package by name and version.
    .DESCRIPTION
        Uses a built-in mock database for testing. In production this would
        call an external API (e.g., libraries.io or npm registry).
        Returns the SPDX license string, or empty string if unknown.
    .PARAMETER PackageName
        The package name to look up.
    .PARAMETER Version
        The version of the package (used for accurate lookup).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$PackageName,

        [Parameter(Mandatory)]
        [string]$Version
    )

    # Built-in mock database — covers common packages for testing
    # In a real implementation, this would query npm registry, PyPI, etc.
    [hashtable]$mockDb = @{
        'express'         = 'MIT'
        'lodash'          = 'MIT'
        'moment'          = 'MIT'
        'react'           = 'MIT'
        'vue'             = 'MIT'
        'axios'           = 'MIT'
        'chalk'           = 'MIT'
        'commander'       = 'MIT'
        'jest'            = 'MIT'
        'typescript'      = 'Apache-2.0'
        'requests'        = 'Apache-2.0'
        'boto3'           = 'Apache-2.0'
        'flask'           = 'BSD-3-Clause'
        'numpy'           = 'BSD-3-Clause'
        'scipy'           = 'BSD-3-Clause'
        'django'          = 'BSD-3-Clause'
        'gpl-lib'         = 'GPL-3.0'
        'gpl-package'     = 'GPL-2.0'
        'mystery-lib'     = ''
        'unknown-pkg'     = ''
    }

    if ($mockDb.ContainsKey($PackageName)) {
        return [string]$mockDb[$PackageName]
    }
    return [string]''
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Generates a full compliance report for a dependency manifest.
    .DESCRIPTION
        Parses the manifest, looks up each dependency's license via the
        provided LicenseLookup scriptblock (injectable for testing), classifies
        each license, and returns a report hashtable with Summary and Dependencies.
    .PARAMETER ManifestPath
        Path to the dependency manifest file.
    .PARAMETER Config
        Hashtable with AllowList ([string[]]) and DenyList ([string[]]) keys.
    .PARAMETER LicenseLookup
        Scriptblock that accepts -PackageName and -Version and returns a license string.
        Defaults to the built-in Invoke-LicenseLookup function.
    .PARAMETER IncludeDev
        When set, includes dev dependencies in the report.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [hashtable]$Config,

        [scriptblock]$LicenseLookup = $null,

        [switch]$IncludeDev
    )

    # Validate config keys
    if (-not $Config.ContainsKey('AllowList')) {
        throw "Config must contain an 'AllowList' key"
    }
    if (-not $Config.ContainsKey('DenyList')) {
        throw "Config must contain a 'DenyList' key"
    }

    [string[]]$allowList = [string[]]$Config['AllowList']
    [string[]]$denyList  = [string[]]$Config['DenyList']

    # Use built-in lookup if none provided
    if ($null -eq $LicenseLookup) {
        $LicenseLookup = { param([string]$PackageName, [string]$Version)
            Invoke-LicenseLookup -PackageName $PackageName -Version $Version
        }
    }

    # Parse dependencies from the manifest
    [PSCustomObject[]]$dependencies = Read-DependencyManifest -ManifestPath $ManifestPath -IncludeDev:$IncludeDev

    [System.Collections.Generic.List[PSCustomObject]]$depReports = [System.Collections.Generic.List[PSCustomObject]]::new()
    [int]$approvedCount = 0
    [int]$deniedCount   = 0
    [int]$unknownCount  = 0

    foreach ($dep in $dependencies) {
        [string]$name    = [string]$dep.Name
        [string]$version = [string]$dep.Version

        # Look up license — invoke the scriptblock with named params
        [string]$license = [string]( & $LicenseLookup -PackageName $name -Version $version )

        # Classify the license
        [string]$status = Test-LicenseCompliance `
            -License   $license `
            -AllowList $allowList `
            -DenyList  $denyList

        # Track counts
        switch ($status) {
            'approved' { $approvedCount++ }
            'denied'   { $deniedCount++ }
            'unknown'  { $unknownCount++ }
        }

        $depReports.Add([PSCustomObject]@{
            Name    = $name
            Version = $version
            License = $license
            Status  = $status
        })
    }

    [int]$total = $approvedCount + $deniedCount + $unknownCount

    return [hashtable]@{
        ManifestPath = $ManifestPath
        Dependencies = [PSCustomObject[]]$depReports.ToArray()
        Summary      = [PSCustomObject]@{
            Total       = $total
            Approved    = $approvedCount
            Denied      = $deniedCount
            Unknown     = $unknownCount
            IsCompliant = ($deniedCount -eq 0)
        }
    }
}

function Export-ComplianceReport {
    <#
    .SYNOPSIS
        Writes a compliance report to a file in text or JSON format.
    .PARAMETER Report
        The report hashtable produced by New-ComplianceReport.
    .PARAMETER OutputPath
        The file path to write to.
    .PARAMETER Format
        Output format: 'text' (default) or 'json'.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [ValidateSet('text', 'json')]
        [string]$Format = 'text'
    )

    if ($Format -eq 'json') {
        # Export as structured JSON
        [PSCustomObject]$exportObj = [PSCustomObject]@{
            ManifestPath = [string]$Report['ManifestPath']
            GeneratedAt  = [string](Get-Date -Format 'o')
            Summary      = $Report['Summary']
            Dependencies = $Report['Dependencies']
        }
        [string]$json = $exportObj | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
    }
    else {
        # Export as human-readable text table
        [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

        [void]$sb.AppendLine('=' * 70)
        [void]$sb.AppendLine('DEPENDENCY LICENSE COMPLIANCE REPORT')
        [void]$sb.AppendLine('=' * 70)
        [void]$sb.AppendLine("Manifest : $([string]$Report['ManifestPath'])")
        [void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        [void]$sb.AppendLine('')

        [PSCustomObject]$summary = $Report['Summary']
        [void]$sb.AppendLine('SUMMARY')
        [void]$sb.AppendLine('-' * 30)
        [void]$sb.AppendLine("Total     : $([int]$summary.Total)")
        [void]$sb.AppendLine("Approved  : $([int]$summary.Approved)")
        [void]$sb.AppendLine("Denied    : $([int]$summary.Denied)")
        [void]$sb.AppendLine("Unknown   : $([int]$summary.Unknown)")
        [void]$sb.AppendLine("Compliant : $([bool]$summary.IsCompliant)")
        [void]$sb.AppendLine('')

        [void]$sb.AppendLine('DEPENDENCIES')
        [void]$sb.AppendLine('-' * 70)
        [void]$sb.AppendLine('{0,-30} {1,-15} {2,-20} {3}' -f 'Package', 'Version', 'License', 'Status')
        [void]$sb.AppendLine('-' * 70)

        foreach ($dep in $Report['Dependencies']) {
            [string]$depName    = [string]$dep.Name
            [string]$depVersion = [string]$dep.Version
            [string]$depLicense = [string]$dep.License
            [string]$depStatus  = [string]$dep.Status
            [void]$sb.AppendLine(('{0,-30} {1,-15} {2,-20} {3}' -f $depName, $depVersion, $depLicense, $depStatus))
        }

        [void]$sb.AppendLine('=' * 70)
        Set-Content -LiteralPath $OutputPath -Value $sb.ToString() -Encoding UTF8
    }
}

Export-ModuleMember -Function @(
    'Read-DependencyManifest'
    'Test-LicenseCompliance'
    'Invoke-LicenseLookup'
    'New-ComplianceReport'
    'Export-ComplianceReport'
)
