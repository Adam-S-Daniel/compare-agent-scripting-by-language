# Dependency License Checker
#
# Parses a dependency manifest (package.json or requirements.txt), looks up each
# dependency's license in a mock database, evaluates it against an allow/deny
# list from a config file, and prints a structured compliance report.
#
# Usage:
#   ./Invoke-LicenseChecker.ps1 -ManifestPath fixtures/package.json `
#       -ConfigPath fixtures/license-config.json `
#       -LicenseDbPath fixtures/mock-license-db.json

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath,

    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [string]$LicenseDbPath = '',

    # When set, exit with code 1 if any denied dependency is found
    [switch]$FailOnDenied
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Function: Get-DependenciesFromManifest
# TDD Iteration 1 (GREEN): Parse package.json and requirements.txt manifests.
# ---------------------------------------------------------------------------
function Get-DependenciesFromManifest {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $filename = [System.IO.Path]::GetFileName($Path).ToLower()

    if ($filename -eq 'package.json') {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        $deps = [System.Collections.Generic.List[hashtable]]::new()
        if ($json.dependencies) {
            $json.dependencies.PSObject.Properties | ForEach-Object {
                $deps.Add(@{ Name = $_.Name; Version = $_.Value })
            }
        }
        # devDependencies are included so CI catches license issues in build tools too
        if ($json.devDependencies) {
            $json.devDependencies.PSObject.Properties | ForEach-Object {
                $deps.Add(@{ Name = $_.Name; Version = $_.Value })
            }
        }
        return $deps.ToArray()
    }
    elseif ($filename -eq 'requirements.txt') {
        $deps = [System.Collections.Generic.List[hashtable]]::new()
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            # Skip blank lines and comments
            if ($line -and -not $line.StartsWith('#')) {
                if ($line -match '^([A-Za-z0-9_\-\.]+)==(.+)$') {
                    $deps.Add(@{ Name = $Matches[1]; Version = $Matches[2] })
                }
                elseif ($line -match '^([A-Za-z0-9_\-\.]+)>=(.+)$') {
                    $deps.Add(@{ Name = $Matches[1]; Version = ">=$($Matches[2])" })
                }
                else {
                    $deps.Add(@{ Name = $line; Version = '' })
                }
            }
        }
        return $deps.ToArray()
    }
    else {
        throw "Unsupported manifest: $Path (supported formats: package.json, requirements.txt)"
    }
}

# ---------------------------------------------------------------------------
# Function: Get-LicenseConfig
# TDD Iteration 2 (GREEN): Load allowList and denyList from JSON config.
# ---------------------------------------------------------------------------
function Get-LicenseConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "License config not found: $Path"
    }

    $cfg = Get-Content $Path -Raw | ConvertFrom-Json
    if (-not $cfg.allowList -or -not $cfg.denyList) {
        throw "License config must contain 'allowList' and 'denyList' arrays"
    }
    return $cfg
}

# ---------------------------------------------------------------------------
# Function: Get-MockLicenseDb
# TDD Iteration 3 (GREEN): Load mock license database from JSON file.
# Returns a hashtable of package-name -> SPDX-license-id.
# Packages absent from the DB are treated as UNKNOWN.
# ---------------------------------------------------------------------------
function Get-MockLicenseDb {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path $Path)) {
        return @{}
    }

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $db = @{}
    $json.PSObject.Properties | ForEach-Object { $db[$_.Name] = $_.Value }
    return $db
}

# ---------------------------------------------------------------------------
# Function: Get-LicenseForPackage
# Returns the license string from the DB, or 'UNKNOWN' if not found.
# ---------------------------------------------------------------------------
function Get-LicenseForPackage {
    param([string]$PackageName, [hashtable]$LicenseDb)

    if ($LicenseDb.ContainsKey($PackageName)) {
        return $LicenseDb[$PackageName]
    }
    return 'UNKNOWN'
}

# ---------------------------------------------------------------------------
# Function: Get-ComplianceStatus
# TDD Iteration 3 (GREEN): Map a license to APPROVED / DENIED / UNKNOWN.
# ---------------------------------------------------------------------------
function Get-ComplianceStatus {
    param([string]$License, [string[]]$AllowList, [string[]]$DenyList)

    if ($License -eq 'UNKNOWN')        { return 'UNKNOWN' }
    if ($License -in $DenyList)        { return 'DENIED'  }
    if ($License -in $AllowList)       { return 'APPROVED' }
    return 'UNKNOWN'  # license in DB but not in either list
}

# ---------------------------------------------------------------------------
# Function: New-ComplianceReport
# TDD Iteration 4 (GREEN): Build a report array from dependencies.
# ---------------------------------------------------------------------------
function New-ComplianceReport {
    param(
        [array]$Dependencies,
        [hashtable]$LicenseDb,
        [object]$Config
    )

    $results = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($dep in $Dependencies) {
        $license = Get-LicenseForPackage -PackageName $dep.Name -LicenseDb $LicenseDb
        $status  = Get-ComplianceStatus -License $license `
                       -AllowList $Config.allowList -DenyList $Config.denyList
        $results.Add(@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        })
    }
    return $results.ToArray()
}

# ---------------------------------------------------------------------------
# Main execution
# ---------------------------------------------------------------------------
try {
    $deps      = Get-DependenciesFromManifest -Path $ManifestPath
    $config    = Get-LicenseConfig            -Path $ConfigPath
    $licenseDb = Get-MockLicenseDb            -Path $LicenseDbPath
    $report    = New-ComplianceReport -Dependencies $deps -LicenseDb $licenseDb -Config $config

    Write-Output '=== LICENSE CHECKER REPORT ==='
    Write-Output "MANIFEST: $ManifestPath"
    Write-Output 'PACKAGE|VERSION|LICENSE|STATUS'

    $approved = 0; $denied = 0; $unknown = 0
    foreach ($entry in $report) {
        Write-Output "$($entry.Name)|$($entry.Version)|$($entry.License)|$($entry.Status)"
        switch ($entry.Status) {
            'APPROVED' { $approved++ }
            'DENIED'   { $denied++   }
            'UNKNOWN'  { $unknown++  }
        }
    }

    $total = $approved + $denied + $unknown
    Write-Output "SUMMARY: APPROVED=$approved DENIED=$denied UNKNOWN=$unknown TOTAL=$total"

    if ($denied -gt 0) {
        Write-Output 'COMPLIANCE: FAILED'
    }
    else {
        Write-Output 'COMPLIANCE: PASSED'
    }

    Write-Output '=== END REPORT ==='

    if ($FailOnDenied -and $denied -gt 0) {
        Write-Error "Compliance check failed: $denied denied dependency/dependencies found."
        exit 1
    }
}
catch {
    Write-Error "License checker error: $_"
    exit 1
}
