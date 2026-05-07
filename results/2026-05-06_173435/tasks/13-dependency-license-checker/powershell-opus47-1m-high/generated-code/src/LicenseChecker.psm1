# LicenseChecker.psm1
#
# Dependency license compliance checker.
#
# Public surface:
#   Get-ManifestDependency     - parse a manifest into [Name, Version] records
#   Get-DependencyLicense      - resolve a license for a dependency (mockable)
#   Test-LicenseCompliance     - classify a license as approved / denied / unknown
#   New-LicenseReport          - produce a structured + human-readable report
#   Invoke-LicenseCheck        - orchestrator used by the entry script
#
# Approach:
# The license-resolver is injected so the unit tests don't need network access
# and so the act-driven CI can feed deterministic fixture data through the
# pipeline. The two supported manifests are package.json (npm) and a
# requirements.txt-style flat file. The compliance rules use SPDX-style ids
# matched case-insensitively against an allow-list and deny-list. Deny wins
# over allow when a license appears in both lists.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-ManifestDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $fileName  = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()

    # Dispatch on extension: .json -> npm-style package manifest;
    # .txt -> pip-style requirements.txt. The fixtures may use suffixes
    # like package.basic.json, so we don't require an exact filename.
    if ($extension -eq '.json') {
        return _ParsePackageJson $Path
    }
    if ($extension -eq '.txt') {
        return _ParseRequirementsTxt $Path
    }
    throw "Unsupported manifest format: $fileName (expected .json or .txt)"
}

function _ParsePackageJson {
    param([string] $Path)

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Manifest is empty: $Path"
    }

    try {
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON in $Path : $($_.Exception.Message)"
    }

    $deps = [System.Collections.Generic.List[object]]::new()
    foreach ($section in @('dependencies', 'devDependencies')) {
        if ($json.PSObject.Properties.Name -contains $section) {
            $node = $json.$section
            if ($null -eq $node) { continue }
            foreach ($prop in $node.PSObject.Properties) {
                $deps.Add([pscustomobject]@{
                    Name    = $prop.Name
                    Version = ($prop.Value -replace '^[\^~>=<\s]+', '').Trim()
                    Scope   = $section
                })
            }
        }
    }
    return ,$deps.ToArray()
}

function _ParseRequirementsTxt {
    param([string] $Path)

    $deps = [System.Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        $stripped = ($line -replace '#.*$', '').Trim()
        if ([string]::IsNullOrWhiteSpace($stripped)) { continue }
        # Handle pkg==1.0.0, pkg>=1.0, pkg~=1.0, pkg (no version)
        if ($stripped -match '^([A-Za-z0-9_.\-]+)\s*(?:==|>=|<=|~=|>|<)?\s*([A-Za-z0-9_.\-]*)\s*$') {
            $deps.Add([pscustomobject]@{
                Name    = $Matches[1]
                Version = $Matches[2]
                Scope   = 'install'
            })
        } else {
            Write-Warning "Skipping unparseable requirements line: $stripped"
        }
    }
    return ,$deps.ToArray()
}

function Get-DependencyLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter()] [hashtable] $LicenseData
    )

    if ($null -eq $LicenseData) {
        # No fixture data supplied -> unknown. The function deliberately does
        # NOT reach out to the network; an integration with npmjs / pypi would
        # plug in here behind the same interface.
        return $null
    }

    $key = "{0}@{1}" -f $Name, $Version
    if ($LicenseData.ContainsKey($key))  { return [string]$LicenseData[$key] }
    if ($LicenseData.ContainsKey($Name)) { return [string]$LicenseData[$Name] }
    return $null
}

function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [Parameter()] [AllowNull()] [string] $License,
        [Parameter(Mandatory)] [string[]] $AllowList,
        [Parameter(Mandatory)] [string[]] $DenyList
    )

    if ([string]::IsNullOrWhiteSpace($License)) {
        return 'unknown'
    }

    $lic = $License.Trim()
    foreach ($d in $DenyList) {
        if ($lic -ieq $d) { return 'denied' }
    }
    foreach ($a in $AllowList) {
        if ($lic -ieq $a) { return 'approved' }
    }
    return 'unknown'
}

function New-LicenseReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Findings
    )

    $approved = @($Findings | Where-Object { $_.Status -eq 'approved' })
    $denied   = @($Findings | Where-Object { $_.Status -eq 'denied' })
    $unknown  = @($Findings | Where-Object { $_.Status -eq 'unknown' })

    $compliant = ($denied.Count -eq 0)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('Dependency License Compliance Report')
    $lines.Add('====================================')
    $lines.Add("Total dependencies : $($Findings.Count)")
    $lines.Add("Approved           : $($approved.Count)")
    $lines.Add("Denied             : $($denied.Count)")
    $lines.Add("Unknown            : $($unknown.Count)")
    $lines.Add("Status             : " + $(if ($compliant) { 'COMPLIANT' } else { 'NON-COMPLIANT' }))
    $lines.Add('')
    $lines.Add('Details:')
    foreach ($f in $Findings) {
        $licDisplay = if ([string]::IsNullOrWhiteSpace($f.License)) { '<none>' } else { $f.License }
        $lines.Add(("- {0}@{1} | license={2} | status={3}" -f $f.Name, $f.Version, $licDisplay, $f.Status))
    }

    return [pscustomobject]@{
        Compliant = $compliant
        Total     = $Findings.Count
        Approved  = $approved.Count
        Denied    = $denied.Count
        Unknown   = $unknown.Count
        Findings  = $Findings
        Text      = ($lines -join [Environment]::NewLine)
    }
}

function Invoke-LicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ManifestPath,
        [Parameter(Mandatory)] [string] $ConfigPath,
        [Parameter()] [hashtable] $LicenseData,
        [Parameter()] [string] $LicenseDataPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config not found: $ConfigPath"
    }

    $configRaw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $config = $configRaw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse config JSON ${ConfigPath}: $($_.Exception.Message)"
    }

    $allow = @()
    $deny  = @()
    if ($config.PSObject.Properties.Name -contains 'allow' -and $config.allow) { $allow = @($config.allow) }
    if ($config.PSObject.Properties.Name -contains 'deny'  -and $config.deny)  { $deny  = @($config.deny)  }

    if (-not $LicenseData -and $LicenseDataPath) {
        if (-not (Test-Path -LiteralPath $LicenseDataPath)) {
            throw "License data file not found: $LicenseDataPath"
        }
        $LicenseData = @{}
        $obj = Get-Content -LiteralPath $LicenseDataPath -Raw | ConvertFrom-Json
        foreach ($p in $obj.PSObject.Properties) {
            $LicenseData[$p.Name] = [string]$p.Value
        }
    }

    $deps = Get-ManifestDependency -Path $ManifestPath

    $findings = foreach ($d in $deps) {
        $license = Get-DependencyLicense -Name $d.Name -Version $d.Version -LicenseData $LicenseData
        $status  = Test-LicenseCompliance -License $license -AllowList $allow -DenyList $deny
        [pscustomobject]@{
            Name    = $d.Name
            Version = $d.Version
            Scope   = $d.Scope
            License = $license
            Status  = $status
        }
    }

    return New-LicenseReport -Findings @($findings)
}

Export-ModuleMember -Function `
    Get-ManifestDependency, `
    Get-DependencyLicense, `
    Test-LicenseCompliance, `
    New-LicenseReport, `
    Invoke-LicenseCheck
