# LicenseChecker module
# Parses dependency manifests, looks up licenses, and produces a compliance report.
# License lookups are routed through Get-LicenseForDependency so tests can mock them.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DependenciesFromManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest not found: $Path"
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $fileName  = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()

    if ($extension -eq '.json' -or $fileName -eq 'package.json') {
        return Get-DependenciesFromPackageJson -Path $Path
    }
    elseif ($fileName -eq 'requirements.txt' -or $extension -eq '.txt') {
        return Get-DependenciesFromRequirementsTxt -Path $Path
    }
    else {
        throw "Unsupported manifest format: $Path"
    }
}

function Get-DependenciesFromPackageJson {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON in manifest '$Path': $($_.Exception.Message)"
    }

    $results = @()
    foreach ($section in @('dependencies','devDependencies')) {
        if ($obj.PSObject.Properties.Name -contains $section -and $obj.$section) {
            foreach ($prop in $obj.$section.PSObject.Properties) {
                # Strip leading semver range characters like ^ or ~
                $version = ($prop.Value -as [string]) -replace '^[\^~>=<\s]+',''
                $results += [pscustomobject]@{
                    Name    = $prop.Name
                    Version = $version
                }
            }
        }
    }
    return ,$results
}

function Get-DependenciesFromRequirementsTxt {
    param([string]$Path)
    $results = @()
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) { continue }
        # Match name==version, name>=version, etc.
        if ($trimmed -match '^([A-Za-z0-9_.\-]+)\s*(?:[<>=!~]=?)\s*([A-Za-z0-9_.\-]+)') {
            $results += [pscustomobject]@{
                Name    = $matches[1]
                Version = $matches[2]
            }
        }
        elseif ($trimmed -match '^([A-Za-z0-9_.\-]+)$') {
            $results += [pscustomobject]@{
                Name    = $matches[1]
                Version = ''
            }
        }
    }
    return ,$results
}

$script:LicenseDb = $null

function Set-LicenseDatabase {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Database)
    $script:LicenseDb = $Database
}

function Get-LicenseForDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Version
    )
    # Default implementation consults an in-memory map populated via
    # Set-LicenseDatabase (used by the CLI for the "mocked lookup"). Tests
    # mock this function directly via Pester for finer control.
    if ($script:LicenseDb -and $script:LicenseDb.ContainsKey($Name)) {
        return [string]$script:LicenseDb[$Name]
    }
    return $null
}

function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][string]$License,
        [Parameter(Mandatory)][hashtable]$Config
    )

    if (-not $License) {
        return 'unknown'
    }

    $allow = @()
    $deny  = @()
    if ($Config.ContainsKey('allow') -and $Config.allow) { $allow = @($Config.allow) }
    if ($Config.ContainsKey('deny')  -and $Config.deny)  { $deny  = @($Config.deny)  }

    # Deny wins if a license appears on both lists — safer default.
    if ($deny  -contains $License) { return 'denied'   }
    if ($allow -contains $License) { return 'approved' }
    return 'unknown'
}

function ConvertTo-LicenseConfig {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "License config not found: $Path"
    }
    $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    return @{
        allow = @($obj.allow)
        deny  = @($obj.deny)
    }
}

function New-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][hashtable]$Config
    )

    $deps = Get-DependenciesFromManifest -Path $ManifestPath
    $entries = @()
    foreach ($dep in $deps) {
        $license = Get-LicenseForDependency -Name $dep.Name -Version $dep.Version
        $status  = Test-LicenseCompliance -License $license -Config $Config
        $entries += [pscustomobject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($license) { $license } else { 'UNKNOWN' }
            Status  = $status
        }
    }

    $summary = [pscustomobject]@{
        Total    = $entries.Count
        Approved = @($entries | Where-Object Status -eq 'approved').Count
        Denied   = @($entries | Where-Object Status -eq 'denied').Count
        Unknown  = @($entries | Where-Object Status -eq 'unknown').Count
    }

    return [pscustomobject]@{
        Manifest     = $ManifestPath
        Dependencies = $entries
        Summary      = $summary
    }
}

Export-ModuleMember -Function `
    Get-DependenciesFromManifest, `
    Get-LicenseForDependency, `
    Set-LicenseDatabase, `
    Test-LicenseCompliance, `
    ConvertTo-LicenseConfig, `
    New-ComplianceReport
