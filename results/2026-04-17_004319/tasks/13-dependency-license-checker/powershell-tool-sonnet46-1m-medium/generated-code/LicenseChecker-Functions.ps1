# LicenseChecker-Functions.ps1
# Pure function library — dot-sourced by both Invoke-LicenseChecker.ps1 and tests.
# No top-level execution; safe to dot-source from Pester BeforeAll blocks.

function Parse-Manifest {
    <#
    .SYNOPSIS Parses a dependency manifest and returns a hashtable of {name -> version}.
    .PARAMETER Path  Path to package.json or requirements.txt.
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $filename  = [System.IO.Path]::GetFileName($Path).ToLower()
    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    $deps      = @{}

    if ($extension -eq '.json') {
        $content = Get-Content $Path -Raw | ConvertFrom-Json

        # Merge dependencies and devDependencies into one flat map
        foreach ($section in @('dependencies', 'devDependencies')) {
            if ($content.$section) {
                $content.$section.PSObject.Properties | ForEach-Object {
                    $deps[$_.Name] = $_.Value
                }
            }
        }
    } elseif ($filename -eq 'requirements.txt') {
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith('#')) {
                # Capture: package-name, optional operator+version
                if ($line -match '^([A-Za-z0-9_.-]+)\s*([><=!,\s][^\s#]*)?') {
                    $pkgName = $matches[1]
                    # Extract version digits after == or >= etc.
                    $versionStr = if ($matches[2]) {
                        $matches[2].Trim() -replace '^[><=!]+\s*', ''
                    } else { '*' }
                    $deps[$pkgName] = $versionStr
                }
            }
        }
    } else {
        throw "Unsupported manifest format: '$($filename)'. Supported: package.json, requirements.txt"
    }

    return $deps
}

function Get-LicenseStatus {
    <#
    .SYNOPSIS  Classifies a license identifier as 'approved', 'denied', or 'unknown'.
    .NOTES     Deny list takes precedence over allow list.
    #>
    param(
        [string]   $License,
        [string[]] $AllowList,
        [string[]] $DenyList
    )

    if (-not $License) { return 'unknown' }

    # Deny beats allow
    if ($DenyList -contains $License)  { return 'denied'   }
    if ($AllowList -contains $License) { return 'approved' }

    return 'unknown'
}

function Get-LicenseForPackage {
    <#
    .SYNOPSIS  Looks up a package's SPDX license identifier from the mock table.
    .RETURNS   License string, or $null when the package is not in the mock data.
    #>
    param(
        [Parameter(Mandatory)][string]    $PackageName,
        [hashtable]                        $MockLicenses = @{}
    )

    if ($MockLicenses -and $MockLicenses.ContainsKey($PackageName)) {
        return $MockLicenses[$PackageName]
    }
    return $null
}

function Invoke-LicenseCheck {
    <#
    .SYNOPSIS  Orchestrates manifest parsing, license lookup, and report generation.
    .RETURNS   Array of [PSCustomObject] with Name, Version, License, Status.
    #>
    param(
        [Parameter(Mandatory)][string]       $ManifestPath,
        [Parameter(Mandatory)][PSCustomObject]$Config,
        [hashtable]                           $MockLicenses = @{}
    )

    $deps      = Parse-Manifest -Path $ManifestPath
    $allowList = [string[]]$Config.allowList
    $denyList  = [string[]]$Config.denyList
    $report    = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($name in ($deps.Keys | Sort-Object)) {
        $version = $deps[$name]
        $license = Get-LicenseForPackage -PackageName $name -MockLicenses $MockLicenses

        $licenseDisplay = if ($license) { $license } else { 'unknown' }
        $status         = Get-LicenseStatus -License $license -AllowList $allowList -DenyList $denyList

        $report.Add([PSCustomObject]@{
            Name    = $name
            Version = $version
            License = $licenseDisplay
            Status  = $status
        })
    }

    return $report.ToArray()
}
