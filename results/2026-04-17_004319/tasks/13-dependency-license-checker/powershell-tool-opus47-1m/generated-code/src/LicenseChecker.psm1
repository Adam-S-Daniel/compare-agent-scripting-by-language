# LicenseChecker.psm1
#
# Tiny, pure-PowerShell module that:
#   * parses a dependency manifest (currently package.json),
#   * looks each dependency's license up in a caller-supplied "database"
#     hashtable (kept external so tests can mock),
#   * classifies each license as approved / denied / unknown per the
#     supplied policy,
#   * and emits a structured compliance report object.
#
# Keeping the license lookup external (rather than calling out to npm /
# pip / a registry) is intentional: it keeps the module deterministic,
# makes it trivially testable, and lets the CI job feed in whatever
# license data it already has on hand.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-DependencyManifest {
    <#
    .SYNOPSIS
        Extracts name/version pairs from a package.json-style manifest.
    .DESCRIPTION
        Merges 'dependencies' and 'devDependencies' objects. Returns an
        array of [pscustomobject] with Name and Version properties.
        The function is intentionally permissive about which top-level
        keys are present so that small fixture files (e.g. without a
        'name' field) still work.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $manifest = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse manifest '$Path' as JSON: $($_.Exception.Message)"
    }

    $dependencies = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($block in 'dependencies', 'devDependencies') {
        if ($manifest.PSObject.Properties.Name -contains $block -and $manifest.$block) {
            foreach ($prop in $manifest.$block.PSObject.Properties) {
                $dependencies.Add([pscustomobject]@{
                    Name    = $prop.Name
                    Version = [string]$prop.Value
                })
            }
        }
    }

    return $dependencies.ToArray()
}

function Get-DependencyLicense {
    <#
    .SYNOPSIS
        Looks up the license for a dependency in the supplied database.
    .DESCRIPTION
        Returns $null when the name is not present. Matching is
        case-insensitive so "LoDaSh" and "lodash" resolve the same way.
        Database is just a hashtable of name -> license string, which
        keeps this module independent of any real registry.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Database
    )

    # Hashtables in PowerShell are case-insensitive by default when
    # constructed with @{}, but callers may pass a case-sensitive one,
    # so search explicitly.
    foreach ($key in $Database.Keys) {
        if ([string]::Equals($key, $Name, [StringComparison]::OrdinalIgnoreCase)) {
            return $Database[$key]
        }
    }
    return $null
}

function Test-LicenseStatus {
    <#
    .SYNOPSIS
        Classifies a license as approved / denied / unknown per policy.
    .DESCRIPTION
        Deny-list wins over allow-list (defensive default). Null / empty
        licenses are treated as unknown.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$License,

        [Parameter(Mandatory)]
        [object]$Policy
    )

    if ([string]::IsNullOrWhiteSpace($License)) {
        return 'unknown'
    }

    $deny  = @($Policy.deny)
    $allow = @($Policy.allow)

    if ($deny -contains $License) { return 'denied' }
    if ($allow -contains $License) { return 'approved' }
    return 'unknown'
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        End-to-end: manifest + policy + license database -> report.
    .DESCRIPTION
        Emits a [pscustomobject] with:
          * compliant     : $true iff no denied dependencies
          * summary       : counts { approved, denied, unknown, total }
          * dependencies  : per-dep { Name, Version, license, status }
        The shape is stable so tests (and CI jobs) can assert on it
        without regex spelunking.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [object]$Policy,

        [Parameter(Mandatory)]
        [hashtable]$LicenseDatabase
    )

    $deps = Read-DependencyManifest -Path $ManifestPath

    $rows = foreach ($dep in $deps) {
        $license = Get-DependencyLicense -Name $dep.Name -Database $LicenseDatabase
        $status  = Test-LicenseStatus -License $license -Policy $Policy
        [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            license = if ($license) { $license } else { 'unknown' }
            status  = $status
        }
    }

    # Coerce to array so .Count works even when there are 0 or 1 rows.
    $rows = @($rows)

    $summary = [pscustomobject]@{
        approved = @($rows | Where-Object status -eq 'approved').Count
        denied   = @($rows | Where-Object status -eq 'denied').Count
        unknown  = @($rows | Where-Object status -eq 'unknown').Count
        total    = $rows.Count
    }

    [pscustomobject]@{
        compliant    = ($summary.denied -eq 0)
        summary      = $summary
        dependencies = $rows
    }
}

Export-ModuleMember -Function Read-DependencyManifest,
                              Get-DependencyLicense,
                              Test-LicenseStatus,
                              New-ComplianceReport
