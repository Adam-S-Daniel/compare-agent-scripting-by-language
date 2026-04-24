# Dependency License Checker
# Parses dependency manifests (package.json, requirements.txt),
# looks up each package's license (mocked), and generates a compliance report.
#
# Script parameters — only used when running directly (not when dot-sourced in tests)
param(
    [string]$ManifestPath      = "fixtures/package.json",
    [string]$LicenseConfigPath = "fixtures/license-config.json",
    [string]$MockLicensesPath  = "fixtures/mock-licenses.json"
)

# ============================================================
# FUNCTION: Read-DependencyManifest
# Parses a dependency manifest file and returns an array of
# [PSCustomObject]@{ Name; Version } for each dependency found.
# Supports package.json (npm) and requirements.txt (Python).
# ============================================================
function Read-DependencyManifest {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $filename = Split-Path $Path -Leaf
    $extension = [System.IO.Path]::GetExtension($filename).ToLower()

    if ($filename -eq "requirements.txt") {
        return Read-RequirementsTxt -Path $Path
    } elseif ($extension -eq ".json") {
        return Read-PackageJson -Path $Path
    } else {
        throw "File type not supported: $extension. Supported types: package.json, requirements.txt"
    }
}

# Parse npm package.json — includes both dependencies and devDependencies
function Read-PackageJson {
    param([string]$Path)

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($section in @("dependencies", "devDependencies")) {
        $sectionData = $json.$section
        if ($null -eq $sectionData) { continue }
        foreach ($prop in $sectionData.PSObject.Properties) {
            # Strip version range specifiers: ^, ~, >=, <=, >, <, =
            $version = $prop.Value -replace '^[\^~>=<]+', ''
            $deps.Add([PSCustomObject]@{ Name = $prop.Name; Version = $version })
        }
    }

    return $deps.ToArray()
}

# Parse Python requirements.txt — supports pinned (==) and unpinned entries
function Read-RequirementsTxt {
    param([string]$Path)

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()
    $lines = Get-Content $Path | Where-Object { $_ -match '\S' -and -not $_.StartsWith('#') }

    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match '^([A-Za-z0-9_\-\.]+)==(.+)$') {
            $deps.Add([PSCustomObject]@{ Name = $Matches[1]; Version = $Matches[2] })
        } elseif ($line -match '^([A-Za-z0-9_\-\.]+)') {
            # Package listed without a version constraint
            $deps.Add([PSCustomObject]@{ Name = $Matches[1]; Version = "unpinned" })
        }
    }

    return $deps.ToArray()
}

# ============================================================
# FUNCTION: Get-LicenseInfo
# Looks up the license for a package using a mock JSON database.
# Returns "UNKNOWN" if the package is not found.
# ============================================================
function Get-LicenseInfo {
    param(
        [Parameter(Mandatory)][string]$PackageName,
        [Parameter(Mandatory)][string]$MockLicensesPath
    )

    $db = Get-Content $MockLicensesPath -Raw | ConvertFrom-Json
    $license = $db.$PackageName

    if ($null -eq $license) {
        return "UNKNOWN"
    }
    return $license
}

# ============================================================
# FUNCTION: Test-LicenseCompliance
# Checks a license string against allow/deny lists.
# Returns: "APPROVED", "DENIED", or "UNKNOWN"
# ============================================================
function Test-LicenseCompliance {
    param(
        [Parameter(Mandatory)][string]$License,
        [Parameter(Mandatory)][hashtable]$Config
    )

    $normalizedLicense = $License.ToUpper()

    # Check deny list first (explicit deny takes precedence)
    foreach ($denied in $Config.DenyList) {
        if ($denied.ToUpper() -eq $normalizedLicense) {
            return "DENIED"
        }
    }

    # Check allow list
    foreach ($allowed in $Config.AllowList) {
        if ($allowed.ToUpper() -eq $normalizedLicense) {
            return "APPROVED"
        }
    }

    # Not in either list
    return "UNKNOWN"
}

# ============================================================
# CLASS (as PSCustomObject factory): New-ComplianceReport
# Builds a report object from a list of compliance entries.
# The report object has: Entries, ApprovedCount, DeniedCount,
# UnknownCount, and a ToText() script method.
# ============================================================
function New-ComplianceReport {
    param(
        [Parameter(Mandatory)][object[]]$Entries
    )

    $approved = ($Entries | Where-Object { $_.Status -eq "APPROVED" }).Count
    $denied   = ($Entries | Where-Object { $_.Status -eq "DENIED"   }).Count
    $unknown  = ($Entries | Where-Object { $_.Status -eq "UNKNOWN"  }).Count

    $report = [PSCustomObject]@{
        Entries       = $Entries
        ApprovedCount = $approved
        DeniedCount   = $denied
        UnknownCount  = $unknown
    }

    # Add a ToText() method that formats the report for stdout
    $report | Add-Member -MemberType ScriptMethod -Name "ToText" -Value {
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add("COMPLIANCE REPORT")
        $lines.Add("=" * 50)
        foreach ($entry in $this.Entries) {
            $lines.Add("$($entry.Name) ($($entry.Version)): $($entry.License) -> $($entry.Status)")
        }
        $lines.Add("=" * 50)
        $lines.Add("Summary: $($this.ApprovedCount) approved, $($this.DeniedCount) denied, $($this.UnknownCount) unknown")
        return ($lines -join "`n")
    }

    return $report
}

# ============================================================
# FUNCTION: Invoke-LicenseChecker
# Main entry point — orchestrates parsing, lookup, and reporting.
# ============================================================
function Invoke-LicenseChecker {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$LicenseConfigPath,
        [Parameter(Mandatory)][string]$MockLicensesPath
    )

    # Load config
    $configJson = Get-Content $LicenseConfigPath -Raw | ConvertFrom-Json
    $config = @{
        AllowList = @($configJson.allowList)
        DenyList  = @($configJson.denyList)
    }

    # Parse manifest
    $dependencies = Read-DependencyManifest -Path $ManifestPath

    # Build compliance entries
    $entries = foreach ($dep in $dependencies) {
        $license = Get-LicenseInfo -PackageName $dep.Name -MockLicensesPath $MockLicensesPath
        $status  = Test-LicenseCompliance -License $license -Config $config
        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }

    return New-ComplianceReport -Entries $entries
}

# ============================================================
# Script entry point — runs when called directly (not dot-sourced).
# When dot-sourced (. ./Invoke-LicenseChecker.ps1), only function
# definitions are loaded and the block below is skipped.
# ============================================================
if ($MyInvocation.InvocationName -ne '.') {
    $report = Invoke-LicenseChecker `
        -ManifestPath      $ManifestPath `
        -LicenseConfigPath $LicenseConfigPath `
        -MockLicensesPath  $MockLicensesPath

    Write-Output $report.ToText()
}
