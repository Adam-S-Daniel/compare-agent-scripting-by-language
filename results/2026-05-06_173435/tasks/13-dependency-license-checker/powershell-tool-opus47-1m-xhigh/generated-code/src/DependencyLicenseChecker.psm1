# DependencyLicenseChecker.psm1
#
# Public surface:
#   Get-DependencyManifest   parse package.json or requirements.txt
#   Get-LicenseConfig        load allow/deny config JSON
#   Get-DependencyLicense    look up a dependency's license (mockable)
#   Test-LicenseCompliance   classify Approved / Denied / Unknown
#   Invoke-LicenseCheck      orchestrate the four above and write a report
#
# Design notes:
#   Get-DependencyLicense is a *seam*. In production it could call npm view,
#   pip-licenses, etc. Here it reads a JSON "license database" that the caller
#   supplies, which keeps the function pure and easily mockable from Pester.
#   The orchestrator exit code (0 / 1) is what CI uses to fail a build when a
#   denied license is present.

Set-StrictMode -Version 3.0

function Get-DependencyManifest {
    <#
    .SYNOPSIS
        Parse a dependency manifest into a list of @{Name; Version} records.
    .DESCRIPTION
        Supports package.json (Node) and requirements.txt (Python) by file
        extension / name. Unsupported formats raise a clear error so the caller
        can fail fast instead of silently returning an empty list.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Manifest file not found: $Path"
    }

    $name = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    $ext  = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    if ($name -eq 'package.json') {
        return Get-PackageJsonDependencies -Path $Path
    }
    if ($name -eq 'requirements.txt' -or $ext -eq '.txt') {
        return Get-RequirementsTxtDependencies -Path $Path
    }

    throw "Unsupported manifest format: $name. Supported: package.json, requirements.txt."
}

function Get-PackageJsonDependencies {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    try {
        $json = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse package.json '$Path': $($_.Exception.Message)"
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($section in @('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies')) {
        if ($json.PSObject.Properties.Name -contains $section -and $null -ne $json.$section) {
            foreach ($prop in $json.$section.PSObject.Properties) {
                $results.Add([pscustomobject]@{
                    Name    = $prop.Name
                    Version = [string]$prop.Value
                    Source  = $section
                })
            }
        }
    }
    # Return as a fixed array so callers can use Count / index uniformly,
    # and Pester's Should -HaveCount works whether there is 0/1/many rows.
    return ,$results.ToArray()
}

function Get-RequirementsTxtDependencies {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -ErrorAction Stop
    $results = New-Object System.Collections.Generic.List[object]

    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $line)              { continue }
        if ($line.StartsWith('#'))   { continue }
        if ($line.StartsWith('-'))   { continue }   # -e, -r, etc.

        # Strip inline comments after a "#".
        $hashIdx = $line.IndexOf('#')
        if ($hashIdx -ge 0) { $line = $line.Substring(0, $hashIdx).Trim() }
        if (-not $line) { continue }

        # Match: name <op> version  where <op> is one of ==, >=, <=, ~=, !=, >, <
        if ($line -match '^\s*([A-Za-z0-9_.\-]+)\s*(==|>=|<=|~=|!=|>|<)\s*([^\s;]+)') {
            $depName    = $matches[1]
            $op         = $matches[2]
            $depVersion = $matches[3]
            $value      = if ($op -eq '==') { $depVersion } else { "$op$depVersion" }
            $results.Add([pscustomobject]@{
                Name    = $depName
                Version = $value
                Source  = 'requirements.txt'
            })
        }
        elseif ($line -match '^\s*([A-Za-z0-9_.\-]+)\s*$') {
            $results.Add([pscustomobject]@{
                Name    = $matches[1]
                Version = ''
                Source  = 'requirements.txt'
            })
        }
    }
    return ,$results.ToArray()
}

function Get-LicenseConfig {
    <#
    .SYNOPSIS
        Load the JSON allow/deny configuration into an object with two arrays.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "License config not found: $Path"
    }

    try {
        $obj = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop |
               ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse license config '$Path' (invalid JSON): $($_.Exception.Message)"
    }

    $allow = @()
    $deny  = @()
    if ($obj.PSObject.Properties.Name -contains 'allow' -and $null -ne $obj.allow) { $allow = @($obj.allow) }
    if ($obj.PSObject.Properties.Name -contains 'deny'  -and $null -ne $obj.deny ) { $deny  = @($obj.deny)  }

    return [pscustomobject]@{
        Allow = $allow
        Deny  = $deny
    }
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Classify a license string as 'Approved', 'Denied', or 'Unknown'.
    .DESCRIPTION
        Deny wins over allow (defense-in-depth: if a license is on both lists
        we still refuse it). Comparison is case-insensitive.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()]
        [string]$License,

        [Parameter(Mandatory)]
        [psobject]$Config
    )

    if ([string]::IsNullOrWhiteSpace($License)) { return 'Unknown' }

    foreach ($d in $Config.Deny ) { if ($d -and ($License -ieq $d)) { return 'Denied'   } }
    foreach ($a in $Config.Allow) { if ($a -and ($License -ieq $a)) { return 'Approved' } }
    return 'Unknown'
}

function Get-DependencyLicense {
    <#
    .SYNOPSIS
        Look up the license for a dependency.
    .DESCRIPTION
        This function is the test seam. It reads a JSON file shaped like:
          { "react@18.2.0": "MIT", "lodash": "MIT", "evil-pkg": "GPL-3.0" }
        Exact "name@version" wins; falls back to a name-only entry; otherwise
        returns $null (which the caller treats as Unknown).
        Pester tests can Mock this function directly.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Version,
        [Parameter(Mandatory)][string]$DatabasePath
    )

    if (-not (Test-Path -LiteralPath $DatabasePath -PathType Leaf)) {
        throw "License database not found: $DatabasePath"
    }

    try {
        $db = Get-Content -LiteralPath $DatabasePath -Raw -ErrorAction Stop |
              ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse license database '$DatabasePath': $($_.Exception.Message)"
    }

    $exactKey = if ($Version) { "$Name@$Version" } else { $Name }
    if ($db.PSObject.Properties.Name -contains $exactKey -and $db.$exactKey) {
        return [string]$db.$exactKey
    }
    if ($db.PSObject.Properties.Name -contains $Name -and $db.$Name) {
        return [string]$db.$Name
    }
    return $null
}

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
        Run the full compliance check and write a JSON report.
    .DESCRIPTION
        Returns an integer exit code: 0 if every dependency is Approved,
        1 if any dependency is Denied or Unknown.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$DatabasePath,
        [Parameter(Mandatory)][string]$ReportPath
    )

    $deps   = Get-DependencyManifest -Path $ManifestPath
    $config = Get-LicenseConfig      -Path $ConfigPath

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($d in $deps) {
        $license = Get-DependencyLicense -Name $d.Name -Version $d.Version -DatabasePath $DatabasePath
        $status  = Test-LicenseCompliance -License $license -Config $config
        $rows.Add([pscustomobject]@{
            Name    = $d.Name
            Version = $d.Version
            Source  = $d.Source
            License = $license
            Status  = $status
        })
    }

    $summary = [pscustomobject]@{
        Total    = $rows.Count
        Approved = @($rows | Where-Object Status -eq 'Approved').Count
        Denied   = @($rows | Where-Object Status -eq 'Denied').Count
        Unknown  = @($rows | Where-Object Status -eq 'Unknown').Count
    }

    $report = [pscustomobject]@{
        Manifest     = (Resolve-Path -LiteralPath $ManifestPath).Path
        GeneratedAt  = (Get-Date).ToUniversalTime().ToString('o')
        Summary      = $summary
        Dependencies = $rows
    }

    $reportDir = Split-Path -Parent $ReportPath
    if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8

    # Human-readable summary on stdout for CI logs.
    Write-Host "=== License Compliance Report ==="
    Write-Host ("Manifest: {0}" -f $report.Manifest)
    Write-Host ("Total: {0}  Approved: {1}  Denied: {2}  Unknown: {3}" -f `
        $summary.Total, $summary.Approved, $summary.Denied, $summary.Unknown)
    foreach ($row in $rows) {
        $licenseDisplay = if ($row.License) { $row.License } else { '<no-data>' }
        Write-Host ("  [{0}] {1}@{2}  license={3}" -f $row.Status, $row.Name, $row.Version, $licenseDisplay)
    }

    if ($summary.Denied -gt 0 -or $summary.Unknown -gt 0) { return 1 }
    return 0
}

Export-ModuleMember -Function `
    Get-DependencyManifest,
    Get-LicenseConfig,
    Get-DependencyLicense,
    Test-LicenseCompliance,
    Invoke-LicenseCheck
