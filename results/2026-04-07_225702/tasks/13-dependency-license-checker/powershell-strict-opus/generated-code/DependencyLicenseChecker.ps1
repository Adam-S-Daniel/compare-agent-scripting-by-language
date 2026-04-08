Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Dependency License Checker
# Parses dependency manifests (package.json, requirements.txt),
# looks up licenses, and generates compliance reports against
# allow/deny license lists.

function Parse-DependencyManifest {
    <#
    .SYNOPSIS
        Parses a dependency manifest file and extracts dependency names and versions.
    .DESCRIPTION
        Supports package.json and requirements.txt formats.
        Returns an array of objects with Name and Version properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    [string]$fileName = Split-Path -Leaf $Path

    switch ($fileName) {
        'package.json' {
            return Parse-PackageJson -Path $Path
        }
        'requirements.txt' {
            return Parse-RequirementsTxt -Path $Path
        }
        default {
            throw "Unsupported manifest format: $fileName. Supported: package.json, requirements.txt"
        }
    }
}

function Parse-PackageJson {
    <#
    .SYNOPSIS
        Parses a package.json file for dependencies.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    [string]$content = Get-Content -Path $Path -Raw
    [PSCustomObject]$pkg = $content | ConvertFrom-Json

    [System.Collections.Generic.List[PSCustomObject]]$deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Extract both dependencies and devDependencies (check property exists for strict mode)
    foreach ($section in @('dependencies', 'devDependencies')) {
        if ($null -ne ($pkg.PSObject.Properties.Match($section)) -and
            $pkg.PSObject.Properties.Match($section).Count -gt 0) {
            [PSCustomObject]$sectionObj = $pkg.PSObject.Properties[$section].Value
            foreach ($prop in $sectionObj.PSObject.Properties) {
                [PSCustomObject]$dep = [PSCustomObject]@{
                    Name    = [string]$prop.Name
                    Version = [string]$prop.Value
                }
                $deps.Add($dep)
            }
        }
    }

    return [PSCustomObject[]]$deps.ToArray()
}

function Parse-RequirementsTxt {
    <#
    .SYNOPSIS
        Parses a requirements.txt file for Python dependencies.
    .DESCRIPTION
        Handles version specifiers (==, >=, <=, ~=, !=) and skips comments/blank lines.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    [string[]]$lines = Get-Content -Path $Path
    [System.Collections.Generic.List[PSCustomObject]]$deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($rawLine in $lines) {
        [string]$line = $rawLine.Trim()

        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        # Split on version specifiers: ==, >=, <=, ~=, !=
        if ($line -match '^([A-Za-z0-9_.-]+)\s*(([><=!~]=?).*)$') {
            [PSCustomObject]$dep = [PSCustomObject]@{
                Name    = [string]$Matches[1]
                Version = [string]$Matches[2]
            }
            $deps.Add($dep)
        }
        else {
            # No version specifier — use wildcard
            [PSCustomObject]$dep = [PSCustomObject]@{
                Name    = [string]$line
                Version = [string]'*'
            }
            $deps.Add($dep)
        }
    }

    return [PSCustomObject[]]$deps.ToArray()
}

function Get-DependencyLicense {
    <#
    .SYNOPSIS
        Looks up the license for a dependency by name.
    .DESCRIPTION
        Uses a hashtable database for license lookup (mockable for testing).
        Returns 'UNKNOWN' if the package is not found.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$LicenseDatabase
    )

    if ($LicenseDatabase.ContainsKey($Name)) {
        return [string]$LicenseDatabase[$Name]
    }

    return [string]'UNKNOWN'
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Checks a license against allow/deny lists.
    .DESCRIPTION
        Returns 'Approved' if the license is on the allow list,
        'Denied' if on the deny list, 'Unknown' otherwise.
        Deny list takes precedence over allow list.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$License,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    [string[]]$denyList = [string[]]$Config['DenyList']
    [string[]]$allowList = [string[]]$Config['AllowList']

    # Deny list takes precedence
    if ($denyList -contains $License) {
        return [string]'Denied'
    }

    if ($allowList -contains $License) {
        return [string]'Approved'
    }

    return [string]'Unknown'
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Generates a compliance report for all dependencies in a manifest.
    .DESCRIPTION
        Parses the manifest, looks up each dependency's license, checks compliance,
        and returns a report object with summary counts and per-dependency entries.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [hashtable]$LicenseDatabase,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Parse the manifest to get dependencies
    [PSCustomObject[]]$dependencies = Parse-DependencyManifest -Path $ManifestPath

    [System.Collections.Generic.List[PSCustomObject]]$entries = [System.Collections.Generic.List[PSCustomObject]]::new()
    [int]$approvedCount = 0
    [int]$deniedCount = 0
    [int]$unknownCount = 0

    foreach ($dep in $dependencies) {
        [string]$license = Get-DependencyLicense -Name ([string]$dep.Name) -LicenseDatabase $LicenseDatabase
        [string]$status = Test-LicenseCompliance -License $license -Config $Config

        [PSCustomObject]$entry = [PSCustomObject]@{
            Name    = [string]$dep.Name
            Version = [string]$dep.Version
            License = [string]$license
            Status  = [string]$status
        }
        $entries.Add($entry)

        switch ($status) {
            'Approved' { $approvedCount++ }
            'Denied'   { $deniedCount++ }
            'Unknown'  { $unknownCount++ }
        }
    }

    [PSCustomObject]$report = [PSCustomObject]@{
        ManifestPath      = [string]$ManifestPath
        TotalDependencies = [int]$entries.Count
        Approved          = [int]$approvedCount
        Denied            = [int]$deniedCount
        Unknown           = [int]$unknownCount
        Entries           = [PSCustomObject[]]$entries.ToArray()
    }

    return $report
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
        Formats a compliance report as human-readable text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine('  Dependency License Compliance Report')
    [void]$sb.AppendLine('========================================')
    [void]$sb.AppendLine("Manifest: $([string]$Report.ManifestPath)")
    [void]$sb.AppendLine('')

    # Per-dependency table
    [void]$sb.AppendLine([string]::Format('{0,-30} {1,-20} {2,-10}', 'Package', 'License', 'Status'))
    [void]$sb.AppendLine([string]::new('-', 62))

    foreach ($entry in $Report.Entries) {
        [string]$statusMarker = switch ([string]$entry.Status) {
            'Approved' { '[OK]' }
            'Denied'   { '[DENIED]' }
            'Unknown'  { '[?]' }
        }
        [void]$sb.AppendLine([string]::Format(
            '{0,-30} {1,-20} {2}',
            [string]$entry.Name,
            [string]$entry.License,
            "$statusMarker $([string]$entry.Status)"
        ))
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('--- Summary ---')
    [void]$sb.AppendLine("Total: $([int]$Report.TotalDependencies)")
    [void]$sb.AppendLine("  Approved: $([int]$Report.Approved)")
    [void]$sb.AppendLine("  Denied:   $([int]$Report.Denied)")
    [void]$sb.AppendLine("  Unknown:  $([int]$Report.Unknown)")

    if ([int]$Report.Denied -gt 0) {
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('WARNING: Some dependencies have denied licenses!')
    }

    return [string]$sb.ToString()
}

function Get-DefaultLicenseDatabase {
    <#
    .SYNOPSIS
        Returns a built-in mock license database for common packages.
    .DESCRIPTION
        Provides a default hashtable mapping package names to SPDX license identifiers.
        Used as a mock for testing without real registry lookups.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    [hashtable]$db = @{
        # Node.js / npm packages
        'express'    = 'MIT'
        'lodash'     = 'MIT'
        'react'      = 'MIT'
        'jest'       = 'MIT'
        'axios'      = 'MIT'
        'moment'     = 'MIT'
        'chalk'      = 'MIT'
        'commander'  = 'MIT'
        'debug'      = 'MIT'
        'uuid'       = 'MIT'
        'webpack'    = 'MIT'
        'typescript' = 'Apache-2.0'

        # Python packages
        'flask'      = 'BSD-3-Clause'
        'django'     = 'BSD-3-Clause'
        'numpy'      = 'BSD-3-Clause'
        'pandas'     = 'BSD-3-Clause'
        'requests'   = 'Apache-2.0'
        'pytest'     = 'MIT'
        'setuptools' = 'MIT'
        'pip'        = 'MIT'
        'scipy'      = 'BSD-3-Clause'
        'pillow'     = 'MIT-CMU'
    }

    return $db
}

function Import-LicenseConfig {
    <#
    .SYNOPSIS
        Loads license allow/deny list configuration from a JSON file.
    .DESCRIPTION
        Expects a JSON file with "allowList" and "denyList" arrays.
        Returns a hashtable with AllowList and DenyList string arrays.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Configuration file not found: $Path"
    }

    [string]$content = Get-Content -Path $Path -Raw
    [PSCustomObject]$raw = $content | ConvertFrom-Json

    # Convert JSON arrays to typed string arrays
    [string[]]$allowList = @()
    [string[]]$denyList = @()

    if ($null -ne ($raw.PSObject.Properties.Match('allowList')) -and
        $raw.PSObject.Properties.Match('allowList').Count -gt 0) {
        $allowList = [string[]]@($raw.PSObject.Properties['allowList'].Value)
    }

    if ($null -ne ($raw.PSObject.Properties.Match('denyList')) -and
        $raw.PSObject.Properties.Match('denyList').Count -gt 0) {
        $denyList = [string[]]@($raw.PSObject.Properties['denyList'].Value)
    }

    [hashtable]$config = @{
        AllowList = [string[]]$allowList
        DenyList  = [string[]]$denyList
    }

    return $config
}
