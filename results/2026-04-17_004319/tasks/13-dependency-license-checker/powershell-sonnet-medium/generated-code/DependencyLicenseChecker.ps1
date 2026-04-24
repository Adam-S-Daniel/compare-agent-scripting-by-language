# Dependency License Checker
# Parses package.json or requirements.txt, looks up licenses (mocked),
# and generates a compliance report against allow/deny lists.

function Parse-DependencyManifest {
    <#
    .SYNOPSIS
        Parses a dependency manifest file and returns a list of dependencies.
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $fileName = Split-Path $Path -Leaf

    if ($fileName -eq "package.json") {
        return Parse-PackageJson -Path $Path
    }
    elseif ($fileName -eq "requirements.txt") {
        return Parse-RequirementsTxt -Path $Path
    }
    else {
        throw "Unsupported manifest type: $fileName. Supported: package.json, requirements.txt"
    }
}

function Parse-PackageJson {
    param([string]$Path)

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($json.dependencies) {
        foreach ($key in $json.dependencies.PSObject.Properties.Name) {
            $deps.Add([PSCustomObject]@{
                Name         = $key
                Version      = $json.dependencies.$key
                ManifestType = "npm"
            })
        }
    }

    if ($json.devDependencies) {
        foreach ($key in $json.devDependencies.PSObject.Properties.Name) {
            $deps.Add([PSCustomObject]@{
                Name         = $key
                Version      = $json.devDependencies.$key
                ManifestType = "npm"
            })
        }
    }

    return $deps.ToArray()
}

function Parse-RequirementsTxt {
    param([string]$Path)

    $lines = Get-Content $Path
    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in $lines) {
        $line = $line.Trim()
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }

        if ($line -match '^([A-Za-z0-9_\-\.]+)==(.+)$') {
            $deps.Add([PSCustomObject]@{
                Name         = $Matches[1]
                Version      = $Matches[2]
                ManifestType = "pip"
            })
        }
        elseif ($line -match '^([A-Za-z0-9_\-\.]+)') {
            $deps.Add([PSCustomObject]@{
                Name         = $Matches[1]
                Version      = ""
                ManifestType = "pip"
            })
        }
    }

    return $deps.ToArray()
}

function Get-LicenseInfo {
    <#
    .SYNOPSIS
        Looks up a package's license from the mock database.
        Returns null if the package is not found.
    #>
    param(
        [Parameter(Mandatory)][string]$PackageName,
        [Parameter(Mandatory)][string]$MockDatabasePath
    )

    if (-not (Test-Path $MockDatabasePath)) {
        throw "Mock license database not found: $MockDatabasePath"
    }

    $db = Get-Content $MockDatabasePath -Raw | ConvertFrom-Json

    # Case-insensitive lookup
    foreach ($prop in $db.PSObject.Properties) {
        if ($prop.Name -ieq $PackageName) {
            return $prop.Value
        }
    }

    return $null
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Determines whether a license is approved, denied, or unknown.
    #>
    param(
        [string]$License,
        [hashtable]$Config
    )

    if ([string]::IsNullOrWhiteSpace($License)) {
        return "unknown"
    }

    if ($Config.DenyList -contains $License) {
        return "denied"
    }

    if ($Config.AllowList -contains $License) {
        return "approved"
    }

    return "unknown"
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Builds a compliance report for a list of dependency objects.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Dependencies,
        [Parameter(Mandatory)][hashtable]$Config,
        [Parameter(Mandatory)][string]$MockDatabasePath
    )

    $entries = foreach ($dep in $Dependencies) {
        $license = Get-LicenseInfo -PackageName $dep.Name -MockDatabasePath $MockDatabasePath
        $status  = Test-LicenseCompliance -License $license -Config $Config

        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($license) { $license } else { "UNKNOWN" }
            Status  = $status
        }
    }

    $approved = @($entries | Where-Object { $_.Status -eq "approved" }).Count
    $denied   = @($entries | Where-Object { $_.Status -eq "denied"   }).Count
    $unknown  = @($entries | Where-Object { $_.Status -eq "unknown"  }).Count

    return [PSCustomObject]@{
        Compliant    = ($denied -eq 0)
        Summary      = [PSCustomObject]@{
            Total    = $entries.Count
            Approved = $approved
            Denied   = $denied
            Unknown  = $unknown
        }
        Dependencies = $entries
    }
}

function Load-LicenseConfig {
    param([string]$ConfigPath)

    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    return @{
        AllowList = [string[]]$json.allowList
        DenyList  = [string[]]$json.denyList
    }
}

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS
        Orchestrates the full license compliance check.
    #>
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$MockDatabasePath
    )

    $deps   = Parse-DependencyManifest -Path $ManifestPath
    $config = Load-LicenseConfig -ConfigPath $ConfigPath
    $report = New-ComplianceReport -Dependencies $deps -Config $config -MockDatabasePath $MockDatabasePath

    return $report
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
        Renders the compliance report as a human-readable text block.
    #>
    param([Parameter(Mandatory)][object]$Report)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("=== Dependency License Compliance Report ===")
    $lines.Add("")
    $overall = if ($Report.Compliant) { "COMPLIANT" } else { "NON-COMPLIANT" }
    $lines.Add("Overall Status : $overall")
    $lines.Add("Total          : $($Report.Summary.Total)")
    $lines.Add("Approved       : $($Report.Summary.Approved)")
    $lines.Add("Denied         : $($Report.Summary.Denied)")
    $lines.Add("Unknown        : $($Report.Summary.Unknown)")
    $lines.Add("")
    $lines.Add("--- Details ---")

    foreach ($dep in $Report.Dependencies) {
        $lines.Add("[$($dep.Status.ToUpper().PadRight(8))] $($dep.Name) $($dep.Version)  (License: $($dep.License))")
    }

    return $lines -join "`n"
}

# Entry point is in Run-LicenseCheck.ps1 to keep this file dot-sourceable by tests.
