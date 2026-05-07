# LicenseChecker.psm1
# Parses dependency manifests, looks up licenses (mockable),
# and produces a compliance report against allow/deny lists.

Set-StrictMode -Version Latest

function Read-DependencyManifest {
    <#
    Parses a package.json-style manifest and returns an array of
    [pscustomobject]@{ Name; Version } entries from `dependencies`
    and `devDependencies`. Throws on missing or malformed files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Manifest is empty: $Path"
    }

    try {
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Manifest is not valid JSON ($Path): $($_.Exception.Message)"
    }

    $deps = [System.Collections.Generic.List[object]]::new()
    $propNames = @($json.PSObject.Properties | ForEach-Object Name)
    foreach ($section in 'dependencies', 'devDependencies') {
        if ($propNames -contains $section -and $json.$section) {
            foreach ($prop in $json.$section.PSObject.Properties) {
                $deps.Add([pscustomobject]@{
                    Name    = $prop.Name
                    Version = [string]$prop.Value
                })
            }
        }
    }

    return ,$deps.ToArray()
}

function Read-LicenseConfig {
    <#
    Loads a JSON config containing `allow` and `deny` arrays of license
    identifiers (e.g. SPDX). Missing arrays are treated as empty.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "License config not found: $Path"
    }

    try {
        $cfg = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "License config is not valid JSON ($Path): $($_.Exception.Message)"
    }

    $allow = @()
    $deny  = @()
    $propNames = @($cfg.PSObject.Properties | ForEach-Object Name)
    if ($propNames -contains 'allow' -and $cfg.allow) { $allow = @($cfg.allow) }
    if ($propNames -contains 'deny'  -and $cfg.deny)  { $deny  = @($cfg.deny)  }

    return [pscustomobject]@{
        Allow = $allow
        Deny  = $deny
    }
}

function Get-DependencyLicense {
    <#
    Mockable license lookup. Returns the license id for a given dependency
    name+version, or $null if unknown. The default implementation reads from
    a hashtable parameter so tests can inject a fixture; production callers
    can swap in a registry/HTTP-backed lookup by passing -LookupTable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]    $Name,
        [Parameter(Mandatory)] [string]    $Version,
        [Parameter(Mandatory)] [hashtable] $LookupTable
    )

    if ($LookupTable.ContainsKey($Name)) {
        return [string]$LookupTable[$Name]
    }
    return $null
}

function Get-ComplianceStatus {
    <#
    Resolves a license string against allow/deny lists.
    Returns one of: 'approved', 'denied', 'unknown'.
    Deny wins over allow when the same id appears in both.
    Null/empty license is treated as 'unknown'.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()] [AllowEmptyString()] [string] $License,
        [Parameter(Mandatory)] [string[]] $Allow,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $Deny
    )

    if ([string]::IsNullOrWhiteSpace($License)) { return 'unknown' }
    if ($Deny  -contains $License) { return 'denied'   }
    if ($Allow -contains $License) { return 'approved' }
    return 'unknown'
}

function Invoke-LicenseComplianceReport {
    <#
    Top-level orchestrator: reads manifest + config, looks up licenses
    (via the supplied hashtable), and returns a list of report rows.
    Each row has Name, Version, License, Status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]    $ManifestPath,
        [Parameter(Mandatory)] [string]    $ConfigPath,
        [Parameter(Mandatory)] [hashtable] $LookupTable
    )

    $deps   = Read-DependencyManifest -Path $ManifestPath
    $config = Read-LicenseConfig      -Path $ConfigPath

    $rows = foreach ($d in $deps) {
        $lic = Get-DependencyLicense -Name $d.Name -Version $d.Version -LookupTable $LookupTable
        $status = Get-ComplianceStatus -License $lic -Allow $config.Allow -Deny $config.Deny
        [pscustomobject]@{
            Name    = $d.Name
            Version = $d.Version
            License = if ($null -eq $lic) { '' } else { $lic }
            Status  = $status
        }
    }

    return ,@($rows)
}

function Format-ComplianceReport {
    <#
    Formats report rows as a human-readable, deterministic text report.
    Includes a summary line and one row per dependency, sorted by name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Rows
    )

    $sorted = @($Rows | Sort-Object -Property Name)
    $approved = @($sorted | Where-Object Status -eq 'approved').Count
    $denied   = @($sorted | Where-Object Status -eq 'denied').Count
    $unknown  = @($sorted | Where-Object Status -eq 'unknown').Count

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("License Compliance Report")
    $lines.Add("=========================")
    $lines.Add("Total: $($sorted.Count) | Approved: $approved | Denied: $denied | Unknown: $unknown")
    $lines.Add("-------------------------")
    foreach ($r in $sorted) {
        $lic = if ([string]::IsNullOrEmpty($r.License)) { '<none>' } else { $r.License }
        $statusUpper = ([string]$r.Status).ToUpper()
        $line = '{0}@{1} :: {2} :: {3}' -f $r.Name, $r.Version, $lic, $statusUpper
        $lines.Add($line)
    }
    return ($lines -join "`n")
}

Export-ModuleMember -Function `
    Read-DependencyManifest, `
    Read-LicenseConfig, `
    Get-DependencyLicense, `
    Get-ComplianceStatus, `
    Invoke-LicenseComplianceReport, `
    Format-ComplianceReport
