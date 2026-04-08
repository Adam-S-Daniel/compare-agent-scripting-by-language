# LicenseChecker.psm1
# Dependency License Checker module
#
# Strict-mode PowerShell implementation written to satisfy the TDD test suite in
# LicenseChecker.Tests.ps1.  Each exported function maps to one TDD cycle:
#
#   Cycle 1 / 2  — Read-DependencyManifest  (package.json + requirements.txt)
#   Cycle 3      — Get-LicenseConfig         (allow / deny lists)
#   Cycle 4      — Test-LicenseCompliance    (status determination)
#   Cycle 5      — Get-DependencyLicense     (mock license lookup — mockable in tests)
#   Cycle 6      — New-ComplianceReport      (end-to-end report)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Module-level mock license database.
# In tests, Get-DependencyLicense is overridden via Pester's Mock mechanism.
# In production the caller would replace this with a real registry lookup.
# ---------------------------------------------------------------------------
$Script:MockLicenseDb = [hashtable]@{
    # JavaScript / npm
    'express'         = 'MIT'
    'lodash'          = 'MIT'
    'axios'           = 'MIT'
    'jest'            = 'MIT'
    'react'           = 'MIT'
    'vue'             = 'MIT'
    'typescript'      = 'Apache-2.0'
    'gpl-lib'         = 'GPL-3.0'
    'agpl-lib'        = 'AGPL-3.0'
    # Python / PyPI
    'requests'        = 'Apache-2.0'
    'flask'           = 'BSD-3-Clause'
    'numpy'           = 'BSD-3-Clause'
    'boto3'           = 'Apache-2.0'
    'django'          = 'BSD-3-Clause'
    'gpl-package'     = 'GPL-3.0'
    # 'unknown-package' is intentionally absent → returned as 'unknown'
}

# ---------------------------------------------------------------------------
# CYCLE 1 & 2 — Read-DependencyManifest
# Detects the manifest type from the file name, delegates to the appropriate
# private parser, and returns a uniform array of [PSCustomObject]{Name; Version}.
# ---------------------------------------------------------------------------
function Read-DependencyManifest {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
        throw "Manifest file not found: $ManifestPath"
    }

    [string]$fileName = [System.IO.Path]::GetFileName($ManifestPath)
    [string]$content  = Get-Content -Path $ManifestPath -Raw -Encoding UTF8

    if ($fileName -eq 'package.json') {
        return [PSCustomObject[]](Read-PackageJson -Content $content)
    }
    elseif ($fileName -eq 'requirements.txt') {
        return [PSCustomObject[]](Read-RequirementsTxt -Content $content)
    }
    else {
        throw "Unsupported manifest type: '$fileName'. Supported types: package.json, requirements.txt"
    }
}

# Private — parses an npm package.json and returns all declared dependencies.
function Read-PackageJson {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    [PSCustomObject]$json = $Content | ConvertFrom-Json

    [System.Collections.Generic.List[PSCustomObject]]$deps =
        [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($section in @('dependencies', 'devDependencies')) {
        # Access as a property on the deserialized object; returns $null if absent
        [PSCustomObject]$sectionObj = $json.PSObject.Properties[$section]?.Value

        if ($null -ne $sectionObj) {
            foreach ($prop in $sectionObj.PSObject.Properties) {
                $deps.Add([PSCustomObject]@{
                    Name    = [string]$prop.Name
                    Version = [string]$prop.Value
                })
            }
        }
    }

    return [PSCustomObject[]]$deps.ToArray()
}

# Private — parses a PEP 508 requirements.txt and returns all declared dependencies.
function Read-RequirementsTxt {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    [System.Collections.Generic.List[PSCustomObject]]$deps =
        [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($rawLine in ($Content -split '\r?\n')) {
        [string]$line = $rawLine.Trim()

        # Skip blank lines and comment lines
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        [string]$pkgName = ''
        [string]$version = ''

        # Match: <package-name>[<extras>]<optional-specifier>
        # Group 1 = package name (letters, digits, hyphens, underscores, dots)
        # Group 2 = optional extras [...] (discarded)
        # Group 3 = optional version specifier starting with >, <, =, !, ~
        if ($line -match '^([A-Za-z0-9_\-\.]+)(\[[^\]]*\])?\s*([><=!~].*)$') {
            $pkgName = [string]$Matches[1]
            $version = [string]$Matches[3]
        }
        elseif ($line -match '^([A-Za-z0-9_\-\.]+)$') {
            # Bare package name with no version specifier
            $pkgName = [string]$Matches[1]
            $version = ''
        }
        else {
            # Unrecognised line format — skip silently
            continue
        }

        $deps.Add([PSCustomObject]@{
            Name    = $pkgName
            Version = $version
        })
    }

    return [PSCustomObject[]]$deps.ToArray()
}

# ---------------------------------------------------------------------------
# CYCLE 3 — Get-LicenseConfig
# Loads and validates the JSON allow/deny license configuration file.
# ---------------------------------------------------------------------------
function Get-LicenseConfig {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
        throw "Config file not found: $ConfigPath"
    }

    [string]$raw        = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
    [PSCustomObject]$cfg = $raw | ConvertFrom-Json

    # Validate required properties
    if ($null -eq $cfg.PSObject.Properties['allowList']?.Value) {
        throw "Config is missing required property 'allowList'"
    }
    if ($null -eq $cfg.PSObject.Properties['denyList']?.Value) {
        throw "Config is missing required property 'denyList'"
    }

    return $cfg
}

# ---------------------------------------------------------------------------
# CYCLE 4 — Test-LicenseCompliance
# Maps a license identifier to one of three statuses: approved | denied | unknown.
# Deny-list wins over allow-list when both would match (safer default).
# ---------------------------------------------------------------------------
function Test-LicenseCompliance {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$License,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    # An already-unknown license is always 'unknown'
    if ($License -eq 'unknown') {
        return [string]'unknown'
    }

    [string[]]$denyList  = [string[]]$Config.denyList
    [string[]]$allowList = [string[]]$Config.allowList

    # Deny-list is checked first (fail-safe)
    if ($denyList -contains $License) {
        return [string]'denied'
    }

    if ($allowList -contains $License) {
        return [string]'approved'
    }

    return [string]'unknown'
}

# ---------------------------------------------------------------------------
# CYCLE 5 — Get-DependencyLicense
# Returns the SPDX license identifier for the given package name.
# Uses the module-level mock database; designed to be replaced by Pester's Mock
# in tests or by a real registry call in production.
# ---------------------------------------------------------------------------
function Get-DependencyLicense {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    if ($Script:MockLicenseDb.ContainsKey($PackageName)) {
        return [string]$Script:MockLicenseDb[$PackageName]
    }

    return [string]'unknown'
}

# ---------------------------------------------------------------------------
# CYCLE 6 — New-ComplianceReport
# Orchestrates the full pipeline: for each dependency, look up its license and
# determine compliance status, returning a report array.
# ---------------------------------------------------------------------------
function New-ComplianceReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Dependencies,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    [System.Collections.Generic.List[PSCustomObject]]$report =
        [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($dep in $Dependencies) {
        [string]$license = Get-DependencyLicense -PackageName ([string]$dep.Name)
        [string]$status  = Test-LicenseCompliance -License $license -Config $Config

        $report.Add([PSCustomObject]@{
            Name    = [string]$dep.Name
            Version = [string]$dep.Version
            License = $license
            Status  = $status
        })
    }

    return [PSCustomObject[]]$report.ToArray()
}

# ---------------------------------------------------------------------------
# Exports — only the public API is exposed; private parsers stay internal
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    'Read-DependencyManifest'
    'Get-LicenseConfig'
    'Get-DependencyLicense'
    'Test-LicenseCompliance'
    'New-ComplianceReport'
)
