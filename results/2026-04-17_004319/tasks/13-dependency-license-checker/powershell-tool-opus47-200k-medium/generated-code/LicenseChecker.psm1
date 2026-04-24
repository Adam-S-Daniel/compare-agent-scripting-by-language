# LicenseChecker.psm1
#
# Parses dependency manifests, classifies each dependency's license against an
# allow/deny policy, and produces a compliance report.
#
# License lookup is injected (scriptblock) so tests can avoid network calls.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DependencyList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('npm', 'pip', 'auto')][string]$Format = 'auto'
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    if ($Format -eq 'auto') {
        $Format = if ($Path -match 'package\.json$') { 'npm' }
                  elseif ($Path -match 'requirements.*\.txt$') { 'pip' }
                  else { throw "Unable to auto-detect manifest format for '$Path'. Pass -Format explicitly." }
    }

    switch ($Format) {
        'npm' {
            $raw = Get-Content -LiteralPath $Path -Raw
            try { $pkg = $raw | ConvertFrom-Json } catch { throw "Invalid JSON in '$Path': $_" }
            $deps = @()
            foreach ($section in 'dependencies', 'devDependencies') {
                if ($pkg.PSObject.Properties.Name -contains $section -and $pkg.$section) {
                    foreach ($prop in $pkg.$section.PSObject.Properties) {
                        $deps += [pscustomobject]@{ Name = $prop.Name; Version = [string]$prop.Value }
                    }
                }
            }
            return ,$deps
        }
        'pip' {
            $deps = @()
            foreach ($line in Get-Content -LiteralPath $Path) {
                $line = $line.Trim()
                if (-not $line -or $line.StartsWith('#')) { continue }
                # Split on common version specifiers; keep name + first pinned version.
                if ($line -match '^\s*([A-Za-z0-9_.\-]+)\s*(==|>=|<=|~=|!=|>|<)?\s*([^;#\s]+)?') {
                    $deps += [pscustomobject]@{
                        Name    = $Matches[1]
                        Version = if ($Matches[3]) { $Matches[3] } else { '' }
                    }
                }
            }
            return ,$deps
        }
    }
}

function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][string]$License,
        [Parameter(Mandatory)][hashtable]$Config
    )
    if ([string]::IsNullOrWhiteSpace($License)) { return 'unknown' }
    $lic = $License.Trim()
    $allow = @($Config.Allow) | ForEach-Object { $_.ToLowerInvariant() }
    $deny  = @($Config.Deny)  | ForEach-Object { $_.ToLowerInvariant() }
    $key = $lic.ToLowerInvariant()
    if ($deny -contains $key)  { return 'denied' }
    if ($allow -contains $key) { return 'approved' }
    return 'unknown'
}

function New-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Dependencies,
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][scriptblock]$LookupLicense
    )

    $results = foreach ($dep in $Dependencies) {
        $license = & $LookupLicense $dep.Name $dep.Version
        $status  = Test-LicenseCompliance -License $license -Config $Config
        [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($license) { $license } else { 'UNKNOWN' }
            Status  = $status
        }
    }

    $summary = [ordered]@{
        approved = @($results | Where-Object Status -EQ 'approved').Count
        denied   = @($results | Where-Object Status -EQ 'denied').Count
        unknown  = @($results | Where-Object Status -EQ 'unknown').Count
    }

    [pscustomobject]@{
        Results          = @($results)
        Summary          = $summary
        OverallCompliant = ($summary.denied -eq 0)
    }
}

function New-MockLicenseLookup {
    # Given a JSON file mapping { "pkgname": "LICENSE" }, return a scriptblock
    # that resolves licenses from that file. Used for offline/CI testing.
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Mock license file not found: $Path" }
    $map = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    return {
        param($name, $version)
        if ($map.ContainsKey($name)) { $map[$name] } else { $null }
    }.GetNewClosure()
}

function Invoke-LicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$MockLicenseFile,
        [string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Config not found: $ConfigPath" }
    $configRaw = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $config = @{
        Allow = @($configRaw.Allow)
        Deny  = @($configRaw.Deny)
    }

    $deps = Get-DependencyList -Path $ManifestPath

    $lookup = if ($MockLicenseFile) {
        New-MockLicenseLookup -Path $MockLicenseFile
    } else {
        { param($n,$v) $null }   # safe default: treat all as unknown
    }

    $report = New-ComplianceReport -Dependencies $deps -Config $config -LookupLicense $lookup

    # Human-readable output (also captured by callers that want JSON).
    Write-Host "Dependency License Compliance Report"
    Write-Host "====================================="
    foreach ($r in $report.Results) {
        $marker = switch ($r.Status) { 'approved' {'[OK]'} 'denied' {'[DENY]'} default {'[??]'} }
        Write-Host ("{0,-7} {1,-20} {2,-12} {3}" -f $marker, $r.Name, $r.Version, $r.License)
    }
    Write-Host ""
    Write-Host ("Summary: approved={0} denied={1} unknown={2}" -f `
        $report.Summary.approved, $report.Summary.denied, $report.Summary.unknown)
    Write-Host ("OverallCompliant: {0}" -f $report.OverallCompliant)

    if ($OutputPath) {
        $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath
    }

    return $report
}

Export-ModuleMember -Function Get-DependencyList, Test-LicenseCompliance,
    New-ComplianceReport, New-MockLicenseLookup, Invoke-LicenseCheck
