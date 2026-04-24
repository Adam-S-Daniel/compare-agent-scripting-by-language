# DependencyLicenseChecker
# ------------------------
# Parses a package.json-style manifest, looks up the license for each
# dependency via a pluggable provider ScriptBlock (mockable for tests),
# and classifies the license against an allow/deny policy.
#
# The provider abstraction is the key design choice: the real world needs
# a network call to a registry, but tests — and CI runs — must be hermetic.
# Injecting a ScriptBlock keeps production and test code on one code path.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-ManifestDependencies {
    <#
    .SYNOPSIS
    Reads a package.json manifest and returns dependency records.

    .OUTPUTS
    [pscustomobject] with Name, Version, Scope ('prod'|'dev').
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $json = $raw | ConvertFrom-Json -AsHashtable
    } catch {
        throw "Failed to parse manifest as JSON ($Path): $($_.Exception.Message)"
    }

    $result = [System.Collections.Generic.List[object]]::new()

    foreach ($scope in @(@{ key = 'dependencies'; tag = 'prod' }, @{ key = 'devDependencies'; tag = 'dev' })) {
        if ($json.ContainsKey($scope.key) -and $json[$scope.key]) {
            foreach ($name in $json[$scope.key].Keys) {
                $result.Add([pscustomobject]@{
                    Name    = [string]$name
                    Version = [string]$json[$scope.key][$name]
                    Scope   = $scope.tag
                })
            }
        }
    }

    return $result.ToArray()
}

function Get-DependencyLicense {
    <#
    .SYNOPSIS
    Looks up a single dependency's license via the injected provider.

    .DESCRIPTION
    The Provider parameter is a ScriptBlock taking the package name and
    returning a license SPDX string or $null when unknown. Tests inject a
    hashtable-backed fake; production injects a registry client.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]      $Name,
        [Parameter(Mandatory)] [scriptblock] $Provider
    )

    # Invoke the provider; always coerce empty strings to $null so downstream
    # classification has a single representation for "unknown".
    $license = & $Provider $Name
    if ([string]::IsNullOrWhiteSpace($license)) { return $null }
    return [string]$license
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
    Classifies a license string against an allow/deny policy.

    .OUTPUTS
    One of 'approved', 'denied', 'unknown'.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]          [AllowNull()] [AllowEmptyString()] [string] $License,
        [Parameter(Mandatory)]                                    $Policy
    )

    # Null / empty / whitespace license => unknown.
    if ([string]::IsNullOrWhiteSpace($License)) { return 'unknown' }

    $deny  = @($Policy.deny  | ForEach-Object { [string]$_ })
    $allow = @($Policy.allow | ForEach-Object { [string]$_ })

    # Deny wins over allow when a license is on both lists — a deliberate
    # conservative default so policy mistakes fail closed.
    if ($deny  -contains $License) { return 'denied' }
    if ($allow -contains $License) { return 'approved' }
    return 'unknown'
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
    Produces a full compliance report from a manifest + policy + provider.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]      $ManifestPath,
        [Parameter(Mandatory)]               $Policy,
        [Parameter(Mandatory)] [scriptblock] $Provider
    )

    $deps = Get-ManifestDependencies -Path $ManifestPath

    $entries = foreach ($dep in $deps) {
        $license = Get-DependencyLicense -Name $dep.Name -Provider $Provider
        [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            Scope   = $dep.Scope
            License = $license
            Status  = Test-LicenseCompliance -License $license -Policy $Policy
        }
    }
    $entries = @($entries)

    $approved = @($entries | Where-Object Status -eq 'approved').Count
    $denied   = @($entries | Where-Object Status -eq 'denied').Count
    $unknown  = @($entries | Where-Object Status -eq 'unknown').Count

    [pscustomobject]@{
        Entries       = $entries
        Summary       = [pscustomobject]@{
            Approved = $approved
            Denied   = $denied
            Unknown  = $unknown
            Total    = $entries.Count
        }
        HasViolations = ($denied -gt 0)
    }
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
    Renders a report as a plain-text block suitable for logs / files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Report
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('Dependency License Compliance Report')
    $lines.Add('=====================================')
    $lines.Add('')
    $lines.Add(('{0,-24} {1,-10} {2,-5} {3,-14} {4}' -f 'Name', 'Version', 'Scope', 'License', 'Status'))
    $lines.Add(('{0,-24} {1,-10} {2,-5} {3,-14} {4}' -f ('-' * 24), ('-' * 10), ('-' * 5), ('-' * 14), ('-' * 8)))

    foreach ($entry in $Report.Entries) {
        $license = if ($entry.License) { $entry.License } else { '<unknown>' }
        $lines.Add(('{0,-24} {1,-10} {2,-5} {3,-14} {4}' -f $entry.Name, $entry.Version, $entry.Scope, $license, $entry.Status))
    }

    $lines.Add('')
    $lines.Add('Summary')
    $lines.Add('-------')
    $lines.Add(("Approved: {0}" -f $Report.Summary.Approved))
    $lines.Add(("Denied:   {0}" -f $Report.Summary.Denied))
    $lines.Add(("Unknown:  {0}" -f $Report.Summary.Unknown))
    $lines.Add(("Total:    {0}" -f $Report.Summary.Total))
    $lines.Add('')
    $lines.Add(("HasViolations: {0}" -f $Report.HasViolations))

    return ($lines -join [Environment]::NewLine)
}

function Invoke-DependencyLicenseCheck {
    <#
    .SYNOPSIS
    Orchestrates a full compliance check: read manifest, load policy,
    wire up the license provider, emit the report, return exit code.

    .OUTPUTS
    [int] 0 on clean, 1 when any dependency is denied.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ManifestPath,
        [Parameter(Mandatory)] [string] $PolicyPath,
        # Path to a JSON file mapping package name => license string. The
        # default for tests; real CI pipelines swap in a network provider.
        [Parameter(Mandatory)] [string] $LicenseDatabasePath,
        [Parameter()]          [string] $OutputPath
    )

    if (-not (Test-Path -LiteralPath $PolicyPath)) {
        throw "Policy file not found: $PolicyPath"
    }
    if (-not (Test-Path -LiteralPath $LicenseDatabasePath)) {
        throw "License database not found: $LicenseDatabasePath"
    }

    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json -AsHashtable
    $db     = Get-Content -LiteralPath $LicenseDatabasePath -Raw | ConvertFrom-Json -AsHashtable

    # Closure-captured provider keeps the script free of global state.
    $provider = {
        param($name)
        if ($db.ContainsKey($name)) { $db[$name] } else { $null }
    }.GetNewClosure()

    $report = New-ComplianceReport -ManifestPath $ManifestPath -Policy $policy -Provider $provider
    $text   = Format-ComplianceReport -Report $report

    Write-Host $text

    if ($OutputPath) {
        $dir = Split-Path -Parent $OutputPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $OutputPath -Value $text
    }

    return [int]($report.HasViolations)
}

Export-ModuleMember -Function `
    Get-ManifestDependencies, `
    Get-DependencyLicense, `
    Test-LicenseCompliance, `
    New-ComplianceReport, `
    Format-ComplianceReport, `
    Invoke-DependencyLicenseCheck
