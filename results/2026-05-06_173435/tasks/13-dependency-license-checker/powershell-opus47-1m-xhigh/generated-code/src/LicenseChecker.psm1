# LicenseChecker module
#
# Built TDD-style: each public function below was implemented by running the
# Pester suite, watching it fail (red), then writing the minimum code to turn
# it green. The mock license database lives in $script:DefaultLicenseDb so
# tests are deterministic and run offline. Callers can override it with the
# -LicenseDatabase parameter on Get-LicenseInfo to inject test data.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Mock license database. In a real implementation this would be a call out to
# npm registry, PyPI's JSON API, libraries.io, etc. For deterministic CI runs
# we use a static map keyed by package name (version-agnostic for simplicity).
$script:DefaultLicenseDb = @{
    'express'      = 'MIT'
    'lodash'       = 'MIT'
    'jest'         = 'MIT'
    'requests'     = 'Apache-2.0'
    'flask'        = 'BSD-3-Clause'
    'some-gpl-pkg' = 'GPL-3.0'
    'numpy'        = 'BSD-3-Clause'
    'pandas'       = 'BSD-3-Clause'
    'react'        = 'MIT'
    'left-pad'     = 'WTFPL'
}

function Get-DependencyManifest {
    <#
    .SYNOPSIS
        Parse a dependency manifest into a list of {Name, Version} records.
    .DESCRIPTION
        Detects the manifest format from the file extension/name:
        *.json (assumes package.json shape) or requirements.txt-style.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file not found: $Path"
    }

    $name = Split-Path -Leaf $Path
    if ($name -match '\.json$') {
        return _ParsePackageJson -Path $Path
    }
    if ($name -match '^(requirements.*\.txt|.*\.txt)$') {
        return _ParseRequirementsTxt -Path $Path
    }
    throw "Unsupported manifest format: $name (expected package.json or requirements.txt)"
}

function _ParsePackageJson {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON manifest '$Path': $($_.Exception.Message)"
    }

    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($section in 'dependencies', 'devDependencies') {
        $node = $obj.PSObject.Properties[$section]
        if ($null -eq $node) { continue }
        foreach ($prop in $node.Value.PSObject.Properties) {
            $results.Add([pscustomobject]@{
                Name    = $prop.Name
                Version = (_NormalizeSemver $prop.Value)
            })
        }
    }
    return ,$results.ToArray()
}

function _NormalizeSemver {
    # Strip semver range prefixes (^, ~, >=, <=, >, <, =, v) and surrounding spaces.
    param([string]$Version)
    if (-not $Version) { return '' }
    return ($Version.Trim() -replace '^[\s\^~>=<v]+', '')
}

function _ParseRequirementsTxt {
    param([string]$Path)
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        # Match name [extras] op version, where op is ==, >=, <=, ~=, !=, >, <
        if ($trimmed -match '^\s*([A-Za-z0-9_.\-]+)\s*(?:\[[^\]]+\])?\s*(?:==|>=|<=|~=|!=|>|<)\s*([^\s;]+)') {
            $results.Add([pscustomobject]@{
                Name    = $matches[1]
                Version = $matches[2]
            })
        } elseif ($trimmed -match '^\s*([A-Za-z0-9_.\-]+)\s*$') {
            # Bare package name with no pinned version.
            $results.Add([pscustomobject]@{
                Name    = $matches[1]
                Version = ''
            })
        }
    }
    return ,$results.ToArray()
}

function Get-LicenseInfo {
    <#
    .SYNOPSIS
        Look up the license for a package (mocked for deterministic testing).
    .PARAMETER LicenseDatabase
        Optional hashtable of name->license overriding the bundled mock data.
        Letting callers pass this in is what makes the function testable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Version,
        [hashtable]$LicenseDatabase
    )
    $db = if ($PSBoundParameters.ContainsKey('LicenseDatabase')) {
        $LicenseDatabase
    } else { $script:DefaultLicenseDb }

    $license = if ($db.ContainsKey($Name)) { $db[$Name] } else { 'UNKNOWN' }
    return [pscustomobject]@{
        Name    = $Name
        Version = $Version
        License = $license
    }
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Classify a license as Approved / Denied / Unknown given an allow/deny policy.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$License,
        [Parameter(Mandatory)][hashtable]$Policy
    )
    $allow = @($Policy['Allow']) | ForEach-Object { if ($_) { $_.ToLowerInvariant() } }
    $deny  = @($Policy['Deny'])  | ForEach-Object { if ($_) { $_.ToLowerInvariant() } }
    $lic   = $License.ToLowerInvariant()

    # Deny wins over Allow when both lists contain the same license — explicit
    # deny is a stronger signal (e.g. policy says "MIT generally allowed but
    # this dual-licensed copyleft variant is denied"). Tests pin this rule.
    $status = if ($deny -contains $lic) {
        'Denied'
    } elseif ($lic -eq 'unknown') {
        'Unknown'
    } elseif ($allow -contains $lic) {
        'Approved'
    } else {
        'Unknown'
    }
    return [pscustomobject]@{ License = $License; Status = $status }
}

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
        End-to-end pipeline: parse manifest, look up licenses, classify,
        return a structured report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$PolicyPath,
        [hashtable]$LicenseDatabase
    )

    if (-not (Test-Path -LiteralPath $PolicyPath)) {
        throw "Policy file not found: $PolicyPath"
    }
    $policyRaw = Get-Content -LiteralPath $PolicyPath -Raw
    try {
        $policyObj = $policyRaw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse policy JSON '$PolicyPath': $($_.Exception.Message)"
    }
    $policy = @{
        Allow = @($policyObj.allow)
        Deny  = @($policyObj.deny)
    }

    $deps = Get-DependencyManifest -Path $ManifestPath

    $rows = foreach ($dep in $deps) {
        $info = if ($PSBoundParameters.ContainsKey('LicenseDatabase')) {
            Get-LicenseInfo -Name $dep.Name -Version $dep.Version -LicenseDatabase $LicenseDatabase
        } else {
            Get-LicenseInfo -Name $dep.Name -Version $dep.Version
        }
        $verdict = Test-LicenseCompliance -License $info.License -Policy $policy
        [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $info.License
            Status  = $verdict.Status
        }
    }

    $approved = @($rows | Where-Object { $_.Status -eq 'Approved' }).Count
    $denied   = @($rows | Where-Object { $_.Status -eq 'Denied'   }).Count
    $unknown  = @($rows | Where-Object { $_.Status -eq 'Unknown'  }).Count

    return [pscustomobject]@{
        ManifestPath = $ManifestPath
        PolicyPath   = $PolicyPath
        Compliant    = ($denied -eq 0 -and $unknown -eq 0)
        Summary      = [pscustomobject]@{
            Total         = $rows.Count
            ApprovedCount = $approved
            DeniedCount   = $denied
            UnknownCount  = $unknown
        }
        Results = @($rows)
    }
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
        Render a Report object (output of Invoke-LicenseCheck) as a
        plain-text compliance report suitable for CI logs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Report
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $verdict = if ($Report.Compliant) { 'COMPLIANT' } else { 'NON-COMPLIANT' }

    $lines.Add("=== License Compliance Report: $verdict ===")
    $lines.Add('')
    # NOTE: outer parens around (... -f ...) are mandatory. Without them
    # PowerShell parses .Add(fmt -f a, b, c) as a 4-arg method call, splitting
    # on the commas before the -f operator gets a chance to consume them.
    $lines.Add(('{0,-25} {1,-12} {2,-15} {3}' -f 'Name', 'Version', 'License', 'Status'))
    $lines.Add(('{0,-25} {1,-12} {2,-15} {3}' -f ('-' * 25), ('-' * 12), ('-' * 15), ('-' * 8)))
    foreach ($row in $Report.Results) {
        $lines.Add(('{0,-25} {1,-12} {2,-15} {3}' -f $row.Name, $row.Version, $row.License, $row.Status))
    }
    $lines.Add('')
    $lines.Add("Total:    $($Report.Summary.Total)")
    $lines.Add("Approved: $($Report.Summary.ApprovedCount)")
    $lines.Add("Denied:   $($Report.Summary.DeniedCount)")
    $lines.Add("Unknown:  $($Report.Summary.UnknownCount)")
    return ($lines -join [Environment]::NewLine)
}

Export-ModuleMember -Function Get-DependencyManifest, Get-LicenseInfo, `
    Test-LicenseCompliance, Invoke-LicenseCheck, Format-ComplianceReport
