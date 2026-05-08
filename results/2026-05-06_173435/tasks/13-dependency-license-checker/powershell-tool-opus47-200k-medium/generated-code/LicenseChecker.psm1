# LicenseChecker.psm1
#
# Parses dependency manifests (package.json or pip requirements files), looks up
# the license for each dependency through an injectable "lookup" callback (which
# is what the tests mock — the production CLI ships an offline stub map), and
# classifies each dependency against an Allow/Deny list to produce a compliance
# report.
#
# The license-lookup callback is dependency-injected so tests stay deterministic
# and offline. Real implementations could query npm, PyPI, or a SCA service.

Set-StrictMode -Version Latest

function Read-DependencyManifest {
    <#
    .SYNOPSIS
        Reads a manifest file and returns dependency name/version pairs.
    .DESCRIPTION
        Auto-detects the manifest format from the file extension or filename:
            *.json or 'package.json' -> npm-style JSON manifest
            otherwise                -> pip-style requirements.txt
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found at path: $Path"
    }

    $name = Split-Path -Leaf $Path
    $isJson = ($name -ieq 'package.json') -or ($Path -match '\.json$')

    if (-not $isJson) {
        # Sniff content: if the file's first non-whitespace char is '{' it is
        # almost certainly a package.json-style manifest. This lets callers
        # (and tests using New-TemporaryFile) skip naming conventions.
        $firstChar = (Get-Content -LiteralPath $Path -Raw).TrimStart() | Select-Object -First 1
        if ($firstChar -and $firstChar.StartsWith('{')) { $isJson = $true }
    }

    if ($isJson) {
        return Read-PackageJsonManifest -Path $Path
    }
    return Read-RequirementsManifest -Path $Path
}

function Read-PackageJsonManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    try {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse package.json '$Path': $($_.Exception.Message)"
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($section in 'dependencies', 'devDependencies') {
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
    return ,$results.ToArray()
}

function Read-RequirementsManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    $results = New-Object System.Collections.Generic.List[object]
    $lines = Get-Content -LiteralPath $Path
    foreach ($raw in $lines) {
        $line = $raw.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }

        # Split on the first occurrence of any version specifier operator.
        # Pattern matches ==, >=, <=, ~=, !=, >, < or @ to support the common
        # cases in requirements.txt without pulling in a real PEP 508 parser.
        if ($line -match '^(?<name>[A-Za-z0-9_.\-\[\]]+)\s*(?<spec>(==|>=|<=|~=|!=|<|>|@).*)$') {
            $results.Add([pscustomobject]@{
                Name    = $Matches['name'].Trim()
                Version = $Matches['spec'].Trim()
                Source  = 'requirements'
            })
        }
        else {
            # No version pin — record name with empty version.
            $results.Add([pscustomobject]@{
                Name    = $line
                Version = ''
                Source  = 'requirements'
            })
        }
    }
    return ,$results.ToArray()
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Classifies a single license string against an Allow/Deny config.
    .DESCRIPTION
        Returns 'Approved', 'Denied', or 'Unknown'. Deny is authoritative — a
        license appearing in both lists is reported as Denied so a misconfigured
        config errs on the safe side.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()] [string] $License,
        [Parameter(Mandatory)] [hashtable] $Config
    )

    $deny  = @($Config['Deny'])
    $allow = @($Config['Allow'])

    if ([string]::IsNullOrWhiteSpace($License)) { return 'Unknown' }
    if ($deny  -contains $License)              { return 'Denied'  }
    if ($allow -contains $License)              { return 'Approved' }
    return 'Unknown'
}

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
        Reads a manifest, resolves licenses via the supplied lookup, and returns
        a report row per dependency.
    .PARAMETER LicenseLookup
        Scriptblock invoked once per dependency. Receives the package name and
        must return the SPDX license string (or $null for "unknown"). Tests
        inject a deterministic mock; the CLI ships an offline stub.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]      $ManifestPath,
        [Parameter(Mandatory)] [hashtable]   $Config,
        [Parameter(Mandatory)] [scriptblock] $LicenseLookup
    )

    $deps = Read-DependencyManifest -Path $ManifestPath
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($dep in $deps) {
        $license = & $LicenseLookup $dep.Name
        $status  = Test-LicenseCompliance -License $license -Config $Config
        $rows.Add([pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($null -eq $license) { '' } else { [string]$license }
            Status  = $status
        })
    }
    return ,$rows.ToArray()
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
        Renders the report rows as a human-readable plain-text block.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]] $Report)

    $approved = @($Report | Where-Object Status -EQ 'Approved').Count
    $denied   = @($Report | Where-Object Status -EQ 'Denied').Count
    $unknown  = @($Report | Where-Object Status -EQ 'Unknown').Count

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('Dependency License Compliance Report')
    [void]$sb.AppendLine('=====================================')
    [void]$sb.AppendLine(("Total: {0}  Approved: {1}  Denied: {2}  Unknown: {3}" -f $Report.Count, $approved, $denied, $unknown))
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine(('{0,-30} {1,-15} {2,-20} {3}' -f 'Name', 'Version', 'License', 'Status'))
    [void]$sb.AppendLine(('{0,-30} {1,-15} {2,-20} {3}' -f ('-' * 30), ('-' * 15), ('-' * 20), ('-' * 8)))
    foreach ($row in $Report) {
        [void]$sb.AppendLine(('{0,-30} {1,-15} {2,-20} {3}' -f $row.Name, $row.Version, $row.License, $row.Status))
    }
    return $sb.ToString()
}

Export-ModuleMember -Function `
    Read-DependencyManifest, Test-LicenseCompliance, Invoke-LicenseCheck, Format-ComplianceReport
