<#
.SYNOPSIS
    Dependency license compliance checker.

.DESCRIPTION
    Parses a dependency manifest (package.json or requirements.txt), looks up
    each dependency's license through a pluggable lookup map (mocked for
    testing — in real use this would call an SPDX/registry API), and reports
    each dependency's status against an allow/deny config.

    Statuses:
        Approved - license is on the allow list
        Denied   - license is on the deny list
        Unknown  - license is missing or not on either list

    The script defines its functions when sourced (dot-sourced for tests) and
    invokes the CLI entry point when executed directly.
#>

[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ConfigPath,
    [string]$LookupPath,
    [string]$OutputPath,
    [ValidateSet('package','requirements','auto')]
    [string]$Format = 'auto',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Get-DependencyList {
    <#
    .SYNOPSIS
        Parses a dependency manifest into a list of [name, version] objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('package','requirements','auto')]
        [string]$Format = 'auto'
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file not found: $Path"
    }

    if ($Format -eq 'auto') {
        $Format = if ((Split-Path $Path -Leaf) -match 'package\.json$') { 'package' }
                  elseif ((Split-Path $Path -Leaf) -match 'requirements.*\.txt$') { 'requirements' }
                  else { 'package' }
    }

    switch ($Format) {
        'package' {
            try {
                $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
            } catch {
                throw "Failed to parse package.json '$Path': $($_.Exception.Message)"
            }
            $deps = @()
            foreach ($section in 'dependencies','devDependencies','peerDependencies','optionalDependencies') {
                if ($json.PSObject.Properties.Name -contains $section -and $json.$section) {
                    foreach ($prop in $json.$section.PSObject.Properties) {
                        $deps += [pscustomobject]@{
                            Name    = $prop.Name
                            Version = [string]$prop.Value
                            Source  = $section
                        }
                    }
                }
            }
            return ,$deps
        }
        'requirements' {
            $deps = @()
            foreach ($raw in Get-Content -LiteralPath $Path) {
                $line = $raw.Trim()
                if (-not $line)             { continue }
                if ($line.StartsWith('#'))  { continue }
                # Strip inline comment
                $line = ($line -split '#',2)[0].Trim()
                # Match name and optional version: pkg==1.0, pkg>=1, pkg~=1, pkg<1, pkg>1
                if ($line -match '^([A-Za-z0-9_.\-]+)\s*(?:[<>=!~]=?|===)\s*([A-Za-z0-9_.\-\*]+)') {
                    $deps += [pscustomobject]@{
                        Name    = $matches[1]
                        Version = $matches[2]
                        Source  = 'requirements'
                    }
                } elseif ($line -match '^([A-Za-z0-9_.\-]+)\s*$') {
                    $deps += [pscustomobject]@{
                        Name    = $matches[1]
                        Version = 'unspecified'
                        Source  = 'requirements'
                    }
                }
            }
            return ,$deps
        }
    }
}

function Get-DependencyLicense {
    <#
    .SYNOPSIS
        Mock license lookup. In real use this would query an SPDX/registry API.
    .DESCRIPTION
        Looks up a license from the supplied hashtable/dictionary. Missing
        entries return the sentinel string "UNKNOWN".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Version,
        [Parameter(Mandatory)]$LicenseMap
    )
    if ($LicenseMap -is [hashtable] -or $LicenseMap -is [System.Collections.IDictionary]) {
        if ($LicenseMap.Contains($Name)) { return [string]$LicenseMap[$Name] }
    } else {
        # PSCustomObject (e.g. parsed from JSON)
        $prop = $LicenseMap.PSObject.Properties[$Name]
        if ($prop) { return [string]$prop.Value }
    }
    return 'UNKNOWN'
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Returns Approved / Denied / Unknown for a single license string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$License,
        [Parameter(Mandatory)]$Config
    )

    $allow = @($Config.allow) | ForEach-Object { $_.ToString().ToLowerInvariant() }
    $deny  = @($Config.deny)  | ForEach-Object { $_.ToString().ToLowerInvariant() }
    $lic   = $License.ToLowerInvariant()

    if ([string]::IsNullOrWhiteSpace($lic) -or $lic -eq 'unknown') { return 'Unknown' }
    if ($deny  -contains $lic) { return 'Denied' }
    if ($allow -contains $lic) { return 'Approved' }
    return 'Unknown'
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Builds the per-dependency compliance report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$LookupPath,
        [ValidateSet('package','requirements','auto')]
        [string]$Format = 'auto'
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Config file not found: $ConfigPath" }
    if (-not (Test-Path -LiteralPath $LookupPath)) { throw "License lookup file not found: $LookupPath" }

    try {
        $config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    } catch {
        throw "Failed to parse config '$ConfigPath': $($_.Exception.Message)"
    }
    try {
        $lookup = Get-Content -Raw -LiteralPath $LookupPath | ConvertFrom-Json
    } catch {
        throw "Failed to parse lookup '$LookupPath': $($_.Exception.Message)"
    }

    $deps   = Get-DependencyList -Path $ManifestPath -Format $Format
    $report = @()
    foreach ($dep in $deps) {
        $lic    = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -LicenseMap $lookup
        $status = Test-LicenseCompliance -License $lic -Config $config
        $report += [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $lic
            Status  = $status
            Source  = $dep.Source
        }
    }
    return ,$report
}

function Get-ComplianceSummary {
    <#
    .SYNOPSIS
        Aggregates the report into Total / Approved / Denied / Unknown counts.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Report)

    [pscustomobject]@{
        Total    = $Report.Count
        Approved = @($Report | Where-Object Status -eq 'Approved').Count
        Denied   = @($Report | Where-Object Status -eq 'Denied').Count
        Unknown  = @($Report | Where-Object Status -eq 'Unknown').Count
    }
}

function Invoke-LicenseChecker {
    <#
    .SYNOPSIS
        CLI entry point. Builds the report, optionally writes JSON, prints a
        human-readable table, and returns a result object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$LookupPath,
        [string]$OutputPath,
        [ValidateSet('package','requirements','auto')]
        [string]$Format = 'auto',
        [switch]$Quiet
    )

    $report  = New-ComplianceReport -ManifestPath $ManifestPath -ConfigPath $ConfigPath -LookupPath $LookupPath -Format $Format
    $summary = Get-ComplianceSummary -Report $report

    if ($OutputPath) {
        $payload = [pscustomobject]@{
            manifest = (Resolve-Path -LiteralPath $ManifestPath).Path
            summary  = $summary
            report   = $report
        }
        $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath
    }

    if (-not $Quiet) {
        Write-Host "License Compliance Report"
        Write-Host "========================="
        $report | Format-Table Name, Version, License, Status -AutoSize | Out-Host
        Write-Host ""
        Write-Host ("Total: {0}  Approved: {1}  Denied: {2}  Unknown: {3}" -f `
            $summary.Total, $summary.Approved, $summary.Denied, $summary.Unknown)
    }

    return [pscustomobject]@{
        Report  = $report
        Summary = $summary
    }
}

# ---- CLI invocation ----------------------------------------------------
# Only run if executed as a script (not dot-sourced for tests).
if ($MyInvocation.InvocationName -ne '.' -and $ManifestPath) {
    try {
        $result = Invoke-LicenseChecker -ManifestPath $ManifestPath `
                                        -ConfigPath  $ConfigPath `
                                        -LookupPath  $LookupPath `
                                        -OutputPath  $OutputPath `
                                        -Format      $Format `
                                        -Quiet:$Quiet
        # Exit non-zero if there are any denied licenses (CI-friendly).
        if ($result.Summary.Denied -gt 0) { exit 2 }
        if ($result.Summary.Unknown -gt 0) { exit 1 }
        exit 0
    } catch {
        Write-Error $_.Exception.Message
        exit 3
    }
}
