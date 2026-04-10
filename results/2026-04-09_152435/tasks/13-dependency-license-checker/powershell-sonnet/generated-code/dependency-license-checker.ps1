# dependency-license-checker.ps1
# Parses dependency manifests, checks licenses against allow/deny lists,
# and generates a compliance report.
#
# Supports: package.json (npm), requirements.txt (pip)
# Uses mock license lookup for testing (no real API calls).

param(
    [string]$Manifest,
    [string]$Config,
    [string]$MockLicenses,
    [switch]$IncludeDev
)

# -------------------------------------------------------------------
# Parse-PackageJson
# Extracts dependency name+version pairs from a package.json string.
# Strips semver range operators (^, ~, >=, <=, >, <) from versions.
# -------------------------------------------------------------------
function Parse-PackageJson {
    param(
        [string]$JsonContent,
        [switch]$IncludeDev
    )

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()
    try {
        $pkg = $JsonContent | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to parse package.json: $_"
        return $deps
    }

    # Helper: strip range operators and return clean version
    function Strip-VersionPrefix([string]$raw) {
        if ([string]::IsNullOrWhiteSpace($raw)) { return "*" }
        # Match optional operators then capture the version number or *
        if ($raw -match '^[~^>=<!]*([0-9][^\s]*)$') {
            return $Matches[1]
        }
        return $raw  # e.g. "*", "latest"
    }

    foreach ($depProp in $pkg.dependencies.PSObject.Properties) {
        $deps.Add([PSCustomObject]@{
            Name    = $depProp.Name
            Version = Strip-VersionPrefix $depProp.Value
        })
    }

    if ($IncludeDev -and $pkg.devDependencies) {
        foreach ($depProp in $pkg.devDependencies.PSObject.Properties) {
            $deps.Add([PSCustomObject]@{
                Name    = $depProp.Name
                Version = Strip-VersionPrefix $depProp.Value
            })
        }
    }

    return $deps
}

# -------------------------------------------------------------------
# Parse-RequirementsTxt
# Extracts package name+version pairs from a requirements.txt string.
# Handles: pkg==1.0, pkg>=1.0, pkg~=1.0, pkg (no version = "*")
# Skips blank lines and comments (#).
# -------------------------------------------------------------------
function Parse-RequirementsTxt {
    param([string]$Content)

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in ($Content -split "`n")) {
        $line = $line.Trim()
        # Skip blank lines and comments
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
        # Also skip options flags (e.g. -r, --index-url)
        if ($line.StartsWith('-')) { continue }

        # Match: package_name (optional extras) (operator version)?
        if ($line -match '^([A-Za-z0-9_\-\.]+)(?:\[[^\]]*\])?(?:[><=!~]+([0-9][^\s,;]*))?') {
            $name    = $Matches[1]
            $version = if ($Matches[2]) { $Matches[2] } else { "*" }
            $deps.Add([PSCustomObject]@{ Name = $name; Version = $version })
        }
    }
    return $deps
}

# -------------------------------------------------------------------
# Get-LicenseStatus
# Determines whether a license is APPROVED, DENIED, or UNKNOWN.
# -------------------------------------------------------------------
function Get-LicenseStatus {
    param(
        [string]$License,
        [hashtable]$Config   # Keys: Allow (array), Deny (array)
    )

    if ([string]::IsNullOrWhiteSpace($License) -or $License -eq "UNKNOWN") {
        return "UNKNOWN"
    }

    if ($Config.Allow -contains $License) { return "APPROVED" }
    if ($Config.Deny  -contains $License) { return "DENIED"   }
    return "UNKNOWN"
}

# -------------------------------------------------------------------
# Invoke-LicenseLookup
# Looks up a package's license from the mock database (hashtable).
# Returns $null if the package is not found.
# -------------------------------------------------------------------
function Invoke-LicenseLookup {
    param(
        [string]$PackageName,
        [hashtable]$MockDatabase
    )

    if ($MockDatabase.ContainsKey($PackageName)) {
        return $MockDatabase[$PackageName]
    }
    return $null
}

# -------------------------------------------------------------------
# Invoke-ComplianceCheck
# Runs the full compliance check for a list of dependencies.
# Returns a list of result objects with Name, Version, License, Status.
# -------------------------------------------------------------------
function Invoke-ComplianceCheck {
    param(
        [object[]]$Dependencies,
        [hashtable]$MockDatabase,
        [hashtable]$Config
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($dep in $Dependencies) {
        $license = Invoke-LicenseLookup -PackageName $dep.Name -MockDatabase $MockDatabase
        $licenseName = if ($license) { $license } else { "UNKNOWN" }
        $status  = Get-LicenseStatus -License $licenseName -Config $Config

        $results.Add([PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $licenseName
            Status  = $status
        })
    }
    return $results
}

# -------------------------------------------------------------------
# Format-ComplianceReport
# Generates a human-readable compliance report string.
# -------------------------------------------------------------------
function Format-ComplianceReport {
    param([object[]]$Results)

    $lines = [System.Collections.Generic.List[string]]::new()
    $sep   = "=" * 55

    $lines.Add("DEPENDENCY LICENSE COMPLIANCE REPORT")
    $lines.Add($sep)

    foreach ($r in $Results) {
        $lines.Add("$($r.Name)@$($r.Version): $($r.License) - $($r.Status)")
    }

    $lines.Add($sep)

    $total    = $Results.Count
    $approved = ($Results | Where-Object { $_.Status -eq "APPROVED" }).Count
    $denied   = ($Results | Where-Object { $_.Status -eq "DENIED"   }).Count
    $unknown  = ($Results | Where-Object { $_.Status -eq "UNKNOWN"  }).Count

    $lines.Add("TOTAL: $total | APPROVED: $approved | DENIED: $denied | UNKNOWN: $unknown")

    $overallStatus = if ($denied -gt 0 -or $unknown -gt 0) { "FAILED" } else { "PASSED" }
    $lines.Add("COMPLIANCE STATUS: $overallStatus")

    return $lines -join "`n"
}

# -------------------------------------------------------------------
# Invoke-LicenseCheck (main entry point)
# Reads manifest, config, and mock license DB; runs check; prints report.
# Exits with code 1 if compliance status is FAILED.
# -------------------------------------------------------------------
function Invoke-LicenseCheck {
    param(
        [string]$ManifestPath,
        [string]$ConfigPath,
        [string]$MockLicensesPath
    )

    # --- Load license config ---
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "License config not found: $ConfigPath"
        exit 2
    }
    $configData  = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $licConfig   = @{
        Allow = [string[]]$configData.allow
        Deny  = [string[]]$configData.deny
    }

    # --- Load mock license database ---
    if (-not (Test-Path $MockLicensesPath)) {
        Write-Error "Mock license database not found: $MockLicensesPath"
        exit 2
    }
    $mockRaw = Get-Content $MockLicensesPath -Raw | ConvertFrom-Json
    $mockDb  = @{}
    foreach ($prop in $mockRaw.PSObject.Properties) {
        $mockDb[$prop.Name] = $prop.Value
    }

    # --- Parse manifest ---
    if (-not (Test-Path $ManifestPath)) {
        Write-Error "Manifest not found: $ManifestPath"
        exit 2
    }

    $manifestContent = Get-Content $ManifestPath -Raw
    $manifestFile    = Split-Path $ManifestPath -Leaf

    $deps = switch -Wildcard ($manifestFile) {
        "package.json"      { Parse-PackageJson -JsonContent $manifestContent -IncludeDev:$IncludeDev }
        "requirements.txt"  { Parse-RequirementsTxt -Content $manifestContent }
        default {
            # Try JSON first, then plain text
            if ($manifestFile -like "*.json") {
                Parse-PackageJson -JsonContent $manifestContent -IncludeDev:$IncludeDev
            } else {
                Parse-RequirementsTxt -Content $manifestContent
            }
        }
    }

    if ($deps.Count -eq 0) {
        Write-Warning "No dependencies found in manifest: $ManifestPath"
    }

    # --- Run compliance check ---
    $results = Invoke-ComplianceCheck -Dependencies $deps -MockDatabase $mockDb -Config $licConfig

    # --- Output report ---
    $report = Format-ComplianceReport -Results $results
    Write-Host $report

    # Exit 1 if compliance failed
    $denied  = ($results | Where-Object { $_.Status -eq "DENIED" }).Count
    $unknown = ($results | Where-Object { $_.Status -eq "UNKNOWN" }).Count
    if ($denied -gt 0 -or $unknown -gt 0) {
        exit 1
    }
}

# -------------------------------------------------------------------
# Script entry point
# Only run Invoke-LicenseCheck when the script is called directly
# (not when dot-sourced for testing).
# -------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
    if ($Manifest) {
        $configPath       = if ($Config)       { $Config       } else { Join-Path $PSScriptRoot "config" "license-config.json" }
        $mockLicensesPath = if ($MockLicenses) { $MockLicenses } else { Join-Path $PSScriptRoot "tests" "fixtures" "mock-licenses.json" }
        Invoke-LicenseCheck -ManifestPath $Manifest -ConfigPath $configPath -MockLicensesPath $mockLicensesPath
    }
}
