# DependencyLicenseChecker.psm1
#
# A small dependency-license auditing module that:
#   * parses package.json or requirements.txt manifests,
#   * looks up each dependency's license from a mock data file
#     (Pester-Mock-friendly so unit tests can swap the lookup),
#   * classifies each license against an allow- / deny-list,
#   * emits a structured report (and a textual / JSON rendering of it).
#
# Built TDD-style: every public function corresponds to a Describe block
# in tests/DependencyLicenseChecker.Tests.ps1.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------
# Manifest parsing
# ------------------------------------------------------------

function Read-DependencyManifest {
    <#
    .SYNOPSIS
        Parses a dependency manifest into a flat list of {Name, Version, Scope}.
    .DESCRIPTION
        Detects manifest type from extension/filename:
            *.json (treated as package.json schema), or
            requirements.txt / *.txt (pip-style).
        Throws a meaningful error for missing or unsupported files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest file not found: $Path"
    }

    $name = Split-Path -Path $Path -Leaf
    $ext  = [System.IO.Path]::GetExtension($name).ToLowerInvariant()

    if ($ext -eq '.json') {
        return _Read-PackageJson -Path $Path
    }
    elseif ($name -ieq 'requirements.txt' -or $ext -eq '.txt') {
        return _Read-RequirementsTxt -Path $Path
    }
    else {
        throw "Unsupported manifest format: $Path"
    }
}

function _Read-PackageJson {
    param([string] $Path)
    $raw  = Get-Content -LiteralPath $Path -Raw
    try {
        $json = $raw | ConvertFrom-Json
    } catch {
        throw "Unsupported manifest content (invalid JSON): $Path"
    }

    $out = New-Object System.Collections.Generic.List[object]

    foreach ($block in @(
        @{ Prop = 'dependencies';    Scope = 'runtime' },
        @{ Prop = 'devDependencies'; Scope = 'dev'     }
    )) {
        if ($json.PSObject.Properties.Name -contains $block.Prop) {
            $section = $json.($block.Prop)
            if ($null -ne $section) {
                foreach ($prop in $section.PSObject.Properties) {
                    $out.Add([pscustomobject]@{
                        Name    = $prop.Name
                        Version = [string]$prop.Value
                        Scope   = $block.Scope
                    })
                }
            }
        }
    }
    return $out.ToArray()
}

function _Read-RequirementsTxt {
    param([string] $Path)
    $out = New-Object System.Collections.Generic.List[object]

    # Match "name" then optional "specifier+version" (e.g. ==2.0, >=1, ~= 4.2).
    # Whitespace around the operator is tolerated; comments starting with '#'
    # are stripped before parsing.
    $rx = '^\s*(?<name>[A-Za-z0-9_.\-]+)\s*(?<spec>(==|>=|<=|~=|!=|>|<)\s*\S+)?\s*$'

    foreach ($line in Get-Content -LiteralPath $Path) {
        $stripped = ($line -replace '#.*$', '').Trim()
        if ([string]::IsNullOrWhiteSpace($stripped)) { continue }

        $m = [regex]::Match($stripped, $rx)
        if (-not $m.Success) { continue }

        $version = if ($m.Groups['spec'].Success) {
            ($m.Groups['spec'].Value -replace '\s+', '')
        } else { '' }

        $out.Add([pscustomobject]@{
            Name    = $m.Groups['name'].Value
            Version = $version
            Scope   = 'runtime'
        })
    }
    return $out.ToArray()
}

# ------------------------------------------------------------
# License lookup (mocked for tests; real implementations would
# call npm/PyPI here).
# ------------------------------------------------------------

function Get-LicenseForPackage {
    <#
    .SYNOPSIS
        Returns the SPDX-style license string for a package name.
    .PARAMETER Name
        Package name, as it appears in the manifest.
    .PARAMETER MockDataPath
        Path to a JSON file mapping package name -> license string.
        The function is intentionally simple so unit tests can either
        seed a fixture file or swap it via Pester's Mock.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $MockDataPath
    )

    if (-not (Test-Path -LiteralPath $MockDataPath -PathType Leaf)) {
        # Treat missing mock data as "license unknown" rather than fatal so
        # the report can still be produced (a real registry call would be
        # treated similarly when the network is unavailable).
        return 'UNKNOWN'
    }

    $data = Get-Content -LiteralPath $MockDataPath -Raw | ConvertFrom-Json
    if ($data.PSObject.Properties.Name -contains $Name) {
        return [string]$data.$Name
    }
    return 'UNKNOWN'
}

# ------------------------------------------------------------
# Allow-list / deny-list classification
# ------------------------------------------------------------

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Classifies a single license string against an allow / deny list.
    .OUTPUTS
        [pscustomobject] @{ License; Status }
            Status is one of: approved | denied | unknown
        Deny matches win over allow matches when a license appears on both.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $License,
        [Parameter(Mandatory)] [object] $Config
    )

    $allow = @($Config.AllowList) | ForEach-Object { $_.ToString().ToLowerInvariant() }
    $deny  = @($Config.DenyList)  | ForEach-Object { $_.ToString().ToLowerInvariant() }
    $needle = $License.ToLowerInvariant()

    $status =
        if ($needle -eq 'unknown') { 'unknown' }
        elseif ($deny  -contains $needle) { 'denied' }
        elseif ($allow -contains $needle) { 'approved' }
        else { 'unknown' }

    [pscustomobject]@{
        License = $License
        Status  = $status
    }
}

# ------------------------------------------------------------
# Top-level orchestration
# ------------------------------------------------------------

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
        End-to-end check: read manifest, resolve licenses, classify, summarize.
    .PARAMETER ManifestPath
        Path to package.json or requirements.txt.
    .PARAMETER ConfigPath
        Path to a JSON file with { AllowList: [...], DenyList: [...] }.
    .PARAMETER MockDataPath
        Path to the mock license-lookup data file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ManifestPath,
        [Parameter(Mandatory)] [string] $ConfigPath,
        [Parameter(Mandatory)] [string] $MockDataPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "License config file not found: $ConfigPath"
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $deps   = Read-DependencyManifest -Path $ManifestPath

    $rows = foreach ($d in $deps) {
        $license = Get-LicenseForPackage -Name $d.Name -MockDataPath $MockDataPath
        $status  = (Test-LicenseCompliance -License $license -Config $config).Status
        [pscustomobject]@{
            Name    = $d.Name
            Version = $d.Version
            Scope   = $d.Scope
            License = $license
            Status  = $status
        }
    }
    $rows = @($rows)   # ensure array even when single dep

    $summary = [pscustomobject]@{
        Total    = $rows.Count
        Approved = @($rows | Where-Object Status -EQ 'approved').Count
        Denied   = @($rows | Where-Object Status -EQ 'denied').Count
        Unknown  = @($rows | Where-Object Status -EQ 'unknown').Count
    }

    [pscustomobject]@{
        Manifest      = $ManifestPath
        Dependencies  = $rows
        Summary       = $summary
        HasViolations = ($summary.Denied -gt 0)
    }
}

# ------------------------------------------------------------
# Rendering
# ------------------------------------------------------------

function Format-LicenseReport {
    <#
    .SYNOPSIS
        Render an Invoke-LicenseCheck report as text or JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report,
        [ValidateSet('Text','Json')] [string] $As = 'Text'
    )

    if ($As -eq 'Json') {
        return ($Report | ConvertTo-Json -Depth 6)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('Dependency License Compliance Report')
    [void]$sb.AppendLine('=====================================')
    foreach ($row in $Report.Dependencies) {
        $line = ('  [{0}] {1}@{2}  scope={3}  license={4}' -f `
            $row.Status.ToUpperInvariant(), $row.Name, $row.Version, $row.Scope, $row.License)
        [void]$sb.AppendLine($line)
    }
    $s = $Report.Summary
    [void]$sb.AppendLine(('Summary: TOTAL={0} APPROVED={1} DENIED={2} UNKNOWN={3}' -f `
        $s.Total, $s.Approved, $s.Denied, $s.Unknown))
    [void]$sb.AppendLine(('HasViolations={0}' -f $Report.HasViolations))
    return $sb.ToString()
}

Export-ModuleMember -Function `
    Read-DependencyManifest,
    Get-LicenseForPackage,
    Test-LicenseCompliance,
    Invoke-LicenseCheck,
    Format-LicenseReport
