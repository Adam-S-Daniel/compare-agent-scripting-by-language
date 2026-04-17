<#
.SYNOPSIS
    Dependency License Checker.

.DESCRIPTION
    Parses a dependency manifest (package.json or requirements.txt), looks up
    each dependency's license, classifies it against an allow-list / deny-list
    config, and emits a compliance report.

    The license lookup is intentionally decoupled: the core pipeline accepts a
    `[hashtable]` mapping (dep name -> SPDX identifier). Tests supply an
    in-memory hashtable; the CLI loads one from JSON on disk. Neither touches
    the network, which keeps this deterministic in CI.

.PARAMETER ManifestPath
    Path to a package.json or requirements.txt file.

.PARAMETER ConfigPath
    Path to a JSON file with {"allow": [...], "deny": [...]}.

.PARAMETER LicenseDbPath
    Path to a JSON file with { "<dep-name>": "<SPDX-id>", ... }. Mocks the
    "real" license lookup that would otherwise hit npm/PyPI/etc.

.PARAMETER OutputJson
    If supplied, machine-readable JSON is written to this path in addition to
    the human-readable text report on stdout.

.PARAMETER FailOnDenied
    If set (default), exits non-zero when any denied license is found.
#>
[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ConfigPath,
    [string]$LicenseDbPath,
    [string]$OutputJson,
    [switch]$FailOnDenied
)

# A sentinel the rest of the pipeline recognises for "we could not determine a
# license". Kept in one place so tests and production agree on the spelling.
$script:UNKNOWN_LICENSE = 'UNKNOWN'

function Read-Manifest {
    <#
        Parses a manifest file and returns a collection of
        [pscustomobject]@{ Name=...; Version=... } rows.

        Supports package.json (npm) and requirements.txt (pip). Anything else
        is rejected with an explicit error — we'd rather fail loudly than
        silently ignore a real manifest we don't understand.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "manifest not found: $Path"
    }

    # We match by suffix (e.g. `fixtures/all-approved-package.json` also counts
    # as a package.json). This lets the fixtures carry a descriptive prefix
    # without needing to each live in their own directory. A bare filename of
    # `Gemfile` or anything else still hits the "unsupported" branch.
    $name = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()

    if ($name -eq 'package.json' -or $name.EndsWith('-package.json')) {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $rows = [System.Collections.Generic.List[pscustomobject]]::new()

        foreach ($section in 'dependencies', 'devDependencies') {
            $block = $json.$section
            if ($null -eq $block) { continue }
            foreach ($prop in $block.PSObject.Properties) {
                $rows.Add([pscustomobject]@{
                    Name    = $prop.Name
                    Version = [string]$prop.Value
                })
            }
        }
        return $rows.ToArray()
    }

    if ($name -eq 'requirements.txt' -or $name.EndsWith('-requirements.txt')) {
        $rows = [System.Collections.Generic.List[pscustomobject]]::new()
        foreach ($line in Get-Content -LiteralPath $Path) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            if ($trimmed.StartsWith('#'))               { continue }

            # Pick the first operator we recognise to split name/version.
            # Anything else (e.g. markers after ';') we drop for this simple
            # mock implementation.
            $operators = @('===', '==', '~=', '!=', '>=', '<=', '>', '<')
            $depName   = $trimmed
            $depVer    = 'unspecified'
            foreach ($op in $operators) {
                $idx = $trimmed.IndexOf($op)
                if ($idx -ge 0) {
                    $depName = $trimmed.Substring(0, $idx).Trim()
                    $depVer  = $trimmed.Substring($idx + $op.Length).Trim()
                    # Strip trailing environment markers like ` ; python_version < '3.9'`.
                    $semi = $depVer.IndexOf(';')
                    if ($semi -ge 0) { $depVer = $depVer.Substring(0, $semi).Trim() }
                    break
                }
            }
            $rows.Add([pscustomobject]@{ Name = $depName; Version = $depVer })
        }
        return $rows.ToArray()
    }

    throw "unsupported manifest format: $name (expected package.json or requirements.txt)"
}

function Get-DependencyLicense {
    <#
        Returns the SPDX license id for a given dependency.

        This is the seam for the "real" license resolver. In production you'd
        swap this for an npm registry / PyPI call; for testing and CI we pass
        a hashtable mock so the pipeline is deterministic.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][hashtable]$LookupTable
    )

    if ($LookupTable.ContainsKey($Name)) {
        return [string]$LookupTable[$Name]
    }
    return $script:UNKNOWN_LICENSE
}

function Get-ComplianceStatus {
    <#
        Classifies a license string as 'approved', 'denied', or 'unknown'.

        Deny-list wins over allow-list: if a license somehow ends up in both
        (operator error, merged configs, etc.) we err on the side of refusing
        it. The UNKNOWN sentinel is always 'unknown', never 'approved'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$License,
        [Parameter(Mandatory)]$Config
    )

    $allow = @($Config.allow)
    $deny  = @($Config.deny)

    if ($deny  -contains $License) { return 'denied'   }
    if ($License -eq $script:UNKNOWN_LICENSE) { return 'unknown' }
    if ($allow -contains $License) { return 'approved' }
    return 'unknown'
}

function Invoke-LicenseCheck {
    <#
        End-to-end pipeline: read manifest, resolve licenses, classify them,
        and package the result. Returns a pscustomobject with .Results and
        .Summary fields suitable for both formatting and assertions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][hashtable]$LookupTable
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "config not found: $ConfigPath"
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if (-not $config.PSObject.Properties.Name.Contains('allow') -or
        -not $config.PSObject.Properties.Name.Contains('deny')) {
        throw "config must contain both 'allow' and 'deny' keys (got: $ConfigPath)"
    }

    $deps    = Read-Manifest -Path $ManifestPath
    $results = [System.Collections.Generic.List[pscustomobject]]::new()
    $counts  = @{ approved = 0; denied = 0; unknown = 0 }

    foreach ($dep in $deps) {
        $license = Get-DependencyLicense -Name $dep.Name `
                                         -Version $dep.Version `
                                         -LookupTable $LookupTable
        $status  = Get-ComplianceStatus -License $license -Config $config
        $counts[$status] += 1

        $results.Add([pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        })
    }

    [pscustomobject]@{
        Results = $results.ToArray()
        Summary = [pscustomobject]@{
            Approved  = $counts['approved']
            Denied    = $counts['denied']
            Unknown   = $counts['unknown']
            Total     = $results.Count
            HasDenied = $counts['denied'] -gt 0
        }
    }
}

function Format-ComplianceReport {
    <#
        Renders the report object into a human-readable text report suitable
        for the CI job log and the GitHub Actions step summary.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('Dependency License Compliance Report')
    $lines.Add('=====================================')
    $lines.Add('')
    $lines.Add(('{0,-30} {1,-15} {2,-20} {3}' -f 'Name', 'Version', 'License', 'Status'))
    $lines.Add(('{0,-30} {1,-15} {2,-20} {3}' -f ('-' * 30), ('-' * 15), ('-' * 20), ('-' * 8)))
    foreach ($row in $Report.Results) {
        $lines.Add(('{0,-30} {1,-15} {2,-20} {3}' -f $row.Name, $row.Version, $row.License, $row.Status))
    }
    $lines.Add('')
    $lines.Add('Summary:')
    $lines.Add(('  approved: {0}' -f $Report.Summary.Approved))
    $lines.Add(('  denied: {0}'   -f $Report.Summary.Denied))
    $lines.Add(('  unknown: {0}'  -f $Report.Summary.Unknown))
    $lines.Add(('  total: {0}'    -f $Report.Summary.Total))
    if ($Report.Summary.HasDenied) {
        $lines.Add('')
        $lines.Add('RESULT: FAIL (denied licenses present)')
    } else {
        $lines.Add('')
        $lines.Add('RESULT: PASS')
    }
    return ($lines -join [Environment]::NewLine)
}

# CLI entry point — only runs when this script is invoked directly, not when
# dot-sourced by the test file.
if ($MyInvocation.InvocationName -ne '.' -and $ManifestPath -and $ConfigPath -and $LicenseDbPath) {
    try {
        if (-not (Test-Path -LiteralPath $LicenseDbPath)) {
            throw "license DB not found: $LicenseDbPath"
        }
        $dbJson  = Get-Content -LiteralPath $LicenseDbPath -Raw | ConvertFrom-Json
        $lookup  = @{}
        foreach ($prop in $dbJson.PSObject.Properties) { $lookup[$prop.Name] = [string]$prop.Value }

        $report  = Invoke-LicenseCheck -ManifestPath $ManifestPath `
                                       -ConfigPath   $ConfigPath `
                                       -LookupTable  $lookup
        $text    = Format-ComplianceReport -Report $report
        Write-Output $text

        if ($OutputJson) {
            $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputJson -Encoding utf8
        }

        if ($FailOnDenied -and $report.Summary.HasDenied) {
            exit 2
        }
        exit 0
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}
