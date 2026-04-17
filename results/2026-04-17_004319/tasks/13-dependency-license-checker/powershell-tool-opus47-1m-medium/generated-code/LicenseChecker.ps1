# Dependency license compliance checker.
# Exposes four functions used by Pester tests and by the CLI invocation block
# at the bottom. Keep logic side-effect-free so tests can call functions
# directly without touching the filesystem beyond the fixture path.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Dependencies {
    # Parse a package.json-style manifest and return [pscustomobject]@{Name;Version}
    # for every entry in "dependencies" and "devDependencies".
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    $json = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($section in 'dependencies','devDependencies') {
        if ($json.PSObject.Properties[$section]) {
            $node = $json.$section
            if ($null -ne $node) {
                foreach ($p in $node.PSObject.Properties) {
                    $results.Add([pscustomobject]@{ Name = $p.Name; Version = [string]$p.Value })
                }
            }
        }
    }
    return ,$results.ToArray()
}

function Test-LicenseStatus {
    # Classify one license string against allow/deny lists.
    # Precedence: deny > allow > unknown. Unknown/empty licenses always 'unknown'.
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()][string]$License,
        [string[]]$Allow = @(),
        [string[]]$Deny  = @()
    )
    if ([string]::IsNullOrWhiteSpace($License)) { return 'unknown' }
    $l = $License.Trim().ToLowerInvariant()
    if ($Deny  | Where-Object { $_.ToLowerInvariant() -eq $l }) { return 'denied' }
    if ($Allow | Where-Object { $_.ToLowerInvariant() -eq $l }) { return 'approved' }
    return 'unknown'
}

function Invoke-LicenseCheck {
    # Glue: read manifest + config, look up each dep's license via the injected
    # -LicenseLookup scriptblock (mockable), classify, return report objects.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [string]$ConfigPath,
        [string[]]$AllowList,
        [string[]]$DenyList,
        [scriptblock]$LicenseLookup
    )

    if ($ConfigPath) {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            throw "Config not found: $ConfigPath"
        }
        $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        if (-not $AllowList -and $cfg.PSObject.Properties['allow']) { $AllowList = @($cfg.allow) }
        if (-not $DenyList  -and $cfg.PSObject.Properties['deny'])  { $DenyList  = @($cfg.deny)  }
    }
    if (-not $AllowList) { $AllowList = @() }
    if (-not $DenyList)  { $DenyList  = @() }
    if (-not $LicenseLookup) { $LicenseLookup = { param($n,$v) $null } }

    $deps = Get-Dependencies -ManifestPath $ManifestPath
    $out = foreach ($d in $deps) {
        $lic = & $LicenseLookup $d.Name $d.Version
        [pscustomobject]@{
            Name    = $d.Name
            Version = $d.Version
            License = $lic
            Status  = Test-LicenseStatus -License $lic -Allow $AllowList -Deny $DenyList
        }
    }
    return ,@($out)
}

function Format-ComplianceReport {
    # Render a report array as a fixed-column text table with a summary footer.
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add(('{0,-25} {1,-12} {2,-15} {3}' -f 'Name','Version','License','Status'))
    $lines.Add(('-' * 65))
    foreach ($r in $Report) {
        $lines.Add(('{0,-25} {1,-12} {2,-15} {3}' -f $r.Name, $r.Version, ($r.License ?? '<none>'), $r.Status))
    }
    $approved = @($Report | Where-Object Status -eq 'approved').Count
    $denied   = @($Report | Where-Object Status -eq 'denied').Count
    $unknown  = @($Report | Where-Object Status -eq 'unknown').Count
    $lines.Add('')
    $lines.Add("Summary — approved: $approved, denied: $denied, unknown: $unknown")
    return ($lines -join [Environment]::NewLine)
}

# --- CLI entry point ---------------------------------------------------------
# Callable from the workflow: Invoke-LicenseCheckCli reads the mocked license
# lookup from a JSON data file (no network, no SDKs required).
function Invoke-LicenseCheckCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [string]$LicenseDataPath  # optional JSON: { "pkgName": "MIT", ... } for mocked lookup
    )
    $lookup = { param($n,$v) $null }
    if ($LicenseDataPath -and (Test-Path -LiteralPath $LicenseDataPath)) {
        $data = Get-Content -LiteralPath $LicenseDataPath -Raw | ConvertFrom-Json -AsHashtable
        $lookup = { param($n,$v) $data[$n] }.GetNewClosure()
    }
    $report = Invoke-LicenseCheck -ManifestPath $ManifestPath -ConfigPath $ConfigPath -LicenseLookup $lookup
    Write-Output (Format-ComplianceReport -Report $report)
    if (@($report | Where-Object Status -eq 'denied').Count -gt 0) { exit 2 }
    exit 0
}
