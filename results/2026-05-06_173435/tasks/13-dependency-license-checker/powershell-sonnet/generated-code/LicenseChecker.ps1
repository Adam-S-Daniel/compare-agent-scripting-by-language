# Dependency License Compliance Checker
# Functions are defined here; dot-source this file in tests or call Invoke-LicenseCheck.ps1 directly.

<#
.SYNOPSIS
    Parse a dependency manifest and return an array of [PSCustomObject] with Name and Version.

.DESCRIPTION
    Supports package.json (npm) and requirements.txt (pip == pinned).
    Type check is performed before existence check so that an unsupported filename
    gives a more helpful error even when the file happens not to exist.
#>
function Get-DependenciesFromManifest {
    param(
        [Parameter(Mandatory)][string]$ManifestPath
    )

    $filename = [System.IO.Path]::GetFileName($ManifestPath)

    # Unsupported type → bail early with clear message
    if ($filename -notin @("package.json", "requirements.txt")) {
        throw "Unsupported manifest type: '$filename'. Supported types: package.json, requirements.txt"
    }

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: '$ManifestPath'"
    }

    $deps = [System.Collections.ArrayList]::new()

    switch ($filename) {
        "package.json" {
            $json = Get-Content $ManifestPath -Raw | ConvertFrom-Json
            foreach ($prop in $json.dependencies.PSObject.Properties) {
                # Strip leading non-numeric characters (e.g. ^, ~, >=) from version
                $ver = $prop.Value -replace '^[^0-9]*', ''
                $null = $deps.Add([PSCustomObject]@{ Name = $prop.Name; Version = $ver })
            }
        }
        "requirements.txt" {
            foreach ($line in (Get-Content $ManifestPath)) {
                $trimmed = $line.Trim()
                # Only handle pinned "name==version" lines; ignore comments and extras
                if ($trimmed -match '^([A-Za-z0-9_\-\.]+)==(.+)$') {
                    $null = $deps.Add([PSCustomObject]@{ Name = $Matches[1]; Version = $Matches[2].Trim() })
                }
            }
        }
    }

    return @($deps)
}

<#
.SYNOPSIS
    Return APPROVED, DENIED, or UNKNOWN based on where the license falls in the config lists.
#>
function Test-LicenseCompliance {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$License,
        [Parameter(Mandatory)][hashtable]$Config
    )

    if ([string]::IsNullOrEmpty($License) -or $License -eq "UNKNOWN") {
        return "UNKNOWN"
    }
    if ($Config.AllowList -contains $License) { return "APPROVED" }
    if ($Config.DenyList  -contains $License) { return "DENIED"   }
    return "UNKNOWN"
}

<#
.SYNOPSIS
    Load allow-list / deny-list config from a JSON file.

.DESCRIPTION
    Expected JSON shape:
        { "allowList": [...], "denyList": [...] }
#>
function Get-LicenseConfig {
    param(
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: '$ConfigPath'"
    }

    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    return @{
        AllowList = @($json.allowList)
        DenyList  = @($json.denyList)
    }
}

<#
.SYNOPSIS
    Build the compliance report by combining dependencies with license lookups.

.PARAMETER LicenseLookup
    A scriptblock with signature: param([string]$Name, [string]$Version) -> [string]
    Inject a mock in tests; use Get-MockLicense or a real registry call in production.
#>
function New-ComplianceReport {
    param(
        [Parameter(Mandatory)][array]$Dependencies,
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][scriptblock]$LicenseLookup
    )

    $report = [System.Collections.ArrayList]::new()
    foreach ($dep in $Dependencies) {
        $license = & $LicenseLookup $dep.Name $dep.Version
        $status  = Test-LicenseCompliance -License $license -Config $Config
        $null = $report.Add([PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        })
    }
    return @($report)
}

<#
.SYNOPSIS
    Render a human-readable compliance report string with a summary section.
#>
function Format-ComplianceReport {
    param(
        [Parameter(Mandatory)][array]$ReportItems
    )

    $lines = [System.Collections.ArrayList]::new()
    $null = $lines.Add("=== DEPENDENCY LICENSE COMPLIANCE REPORT ===")
    $null = $lines.Add("")

    foreach ($item in $ReportItems) {
        $null = $lines.Add("Dependency: $($item.Name)@$($item.Version)")
        $null = $lines.Add("  License: $($item.License)")
        $null = $lines.Add("  Status:  $($item.Status)")
        $null = $lines.Add("")
    }

    $approved = @($ReportItems | Where-Object Status -eq "APPROVED").Count
    $denied   = @($ReportItems | Where-Object Status -eq "DENIED").Count
    $unknown  = @($ReportItems | Where-Object Status -eq "UNKNOWN").Count

    $null = $lines.Add("=== SUMMARY ===")
    $null = $lines.Add("APPROVED: $approved")
    $null = $lines.Add("DENIED:   $denied")
    $null = $lines.Add("UNKNOWN:  $unknown")
    $null = $lines.Add("Total:    $($ReportItems.Count)")

    return $lines -join [System.Environment]::NewLine
}

<#
.SYNOPSIS
    Mock license lookup that reads from fixtures/mock-licenses.json.
    Returned when no real registry is configured.
#>
function Get-MockLicense {
    param([string]$Name, [string]$Version)

    $mockPath = Join-Path $PSScriptRoot "fixtures/mock-licenses.json"
    if (Test-Path $mockPath) {
        $data = Get-Content $mockPath -Raw | ConvertFrom-Json
        $val  = $data.$Name
        if ($null -ne $val) { return $val }
    }
    return "UNKNOWN"
}
