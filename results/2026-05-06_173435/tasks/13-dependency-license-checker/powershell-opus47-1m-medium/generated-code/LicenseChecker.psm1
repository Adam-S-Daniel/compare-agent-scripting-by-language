# LicenseChecker.psm1
#
# Functions for parsing dependency manifests, classifying licenses against an
# allow/deny policy, and producing a compliance report. License lookup is
# parameterized as a scriptblock so callers (and tests) can swap in a mock
# database without touching the network.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Dependencies {
    <#
    .SYNOPSIS
        Parse a dependency manifest into a flat list of {Name, Version} objects.
    .DESCRIPTION
        Supports two formats keyed off the file name / extension:
          * package.json  -> dependencies + devDependencies maps
          * requirements.txt -> one pinned/unpinned package per line
        Throws when the manifest does not exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found at path '$Path'."
    }

    $name = Split-Path -Leaf $Path
    if ($name -ieq 'package.json') {
        return _ParsePackageJson -Path $Path
    }
    if ($name -imatch 'requirements.*\.txt$' -or $Path -imatch '\.txt$') {
        return _ParseRequirementsTxt -Path $Path
    }
    throw "Unsupported manifest type: '$name'. Supported: package.json, requirements.txt."
}

function _ParsePackageJson {
    param([string] $Path)
    $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $out  = New-Object System.Collections.Generic.List[object]
    foreach ($section in 'dependencies','devDependencies') {
        if ($json.PSObject.Properties.Name -contains $section -and $null -ne $json.$section) {
            foreach ($prop in $json.$section.PSObject.Properties) {
                $out.Add([pscustomobject]@{
                    Name    = $prop.Name
                    # Strip leading range qualifiers like ^ or ~ for reporting.
                    Version = ($prop.Value -replace '^[\^~>=<\s]+','')
                })
            }
        }
    }
    return $out.ToArray()
}

function _ParseRequirementsTxt {
    param([string] $Path)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        # Match name and optional version after ==, >=, <=, ~=, etc.
        if ($line -match '^([A-Za-z0-9_.\-]+)\s*(?:[=<>!~]=?\s*([A-Za-z0-9_.\-+!]+))?') {
            $out.Add([pscustomobject]@{
                Name    = $Matches[1]
                Version = if ($Matches[2]) { $Matches[2] } else { 'unspecified' }
            })
        }
    }
    return $out.ToArray()
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Classify a single license string as 'approved', 'denied', or 'unknown'.
    .DESCRIPTION
        Deny takes precedence: a license that appears in both lists is denied,
        because a misconfigured policy should fail safe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowNull()] [AllowEmptyString()] [string] $License,
        [Parameter(Mandatory)] [object]                                    $Config
    )

    $deny  = @($Config.deny)
    $allow = @($Config.allow)

    if ([string]::IsNullOrWhiteSpace($License)) { return 'unknown' }
    if ($deny  -contains $License)              { return 'denied' }
    if ($allow -contains $License)              { return 'approved' }
    return 'unknown'
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Produce a per-dependency compliance report.
    .PARAMETER LicenseLookup
        Scriptblock { param($name, $version) ... } returning a license string
        or $null. Injected so tests / CI can mock the data source.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]    $Dependencies,
        [Parameter(Mandatory)] [object]      $Config,
        [Parameter(Mandatory)] [scriptblock] $LicenseLookup
    )

    $rows = foreach ($dep in $Dependencies) {
        $license = & $LicenseLookup $dep.Name $dep.Version
        $status  = Test-LicenseCompliance -License $license -Config $Config
        [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ([string]::IsNullOrWhiteSpace($license)) { 'UNKNOWN' } else { $license }
            Status  = $status
        }
    }
    return ,@($rows)
}

Export-ModuleMember -Function Get-Dependencies, Test-LicenseCompliance, New-ComplianceReport
