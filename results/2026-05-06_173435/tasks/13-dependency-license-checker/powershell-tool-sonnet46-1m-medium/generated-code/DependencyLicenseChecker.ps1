# DependencyLicenseChecker.ps1
# Parses dependency manifests, looks up licenses, and produces a compliance report.
# Supports package.json (npm) and requirements.txt (pip).
#
# Usage (run directly):
#   ./DependencyLicenseChecker.ps1 -ManifestPath <path> -ConfigPath <path> [-MockDataPath <path>]
#
# Usage (dot-sourced in tests):
#   . ./DependencyLicenseChecker.ps1
#   $report = Get-ComplianceReport ...
#
# param() must be at the top; when dot-sourced all params default to "" so
# the script-mode entry-point guard below skips execution entirely.

[CmdletBinding()]
param(
    [string]$ManifestPath = "",
    [string]$ConfigPath   = "",
    [string]$MockDataPath = ""
)

#region --- Helpers ---

# Strips semver range prefixes (^, ~, >=, <=, >, <, !=, ~=) from a version string.
function Get-NormalizedVersion {
    param([string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return "" }
    return ($Version -replace '^[~^>=<! ]+', '').Trim()
}

#endregion

#region --- Config Loading ---

# Loads the allow/deny license lists from a JSON config file.
function Get-LicenseConfig {
    param(
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    return [PSCustomObject]@{
        AllowList = [string[]]$json.allowList
        DenyList  = [string[]]$json.denyList
    }
}

#endregion

#region --- Manifest Parsing ---

# Parses a dependency manifest and returns an array of [Name, Version] objects.
# Supports: any *.json (treated as npm package.json) and *.txt (treated as requirements.txt)
function Get-Dependencies {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [switch]$IncludeDev  # Include devDependencies (package.json only)
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }

    $ext = [System.IO.Path]::GetExtension($ManifestPath).ToLower()

    if ($ext -eq ".json") {
        return Parse-PackageJson -Path $ManifestPath -IncludeDev:$IncludeDev
    }
    elseif ($ext -eq ".txt") {
        return Parse-RequirementsTxt -Path $ManifestPath
    }
    else {
        throw "Manifest type not supported: $ManifestPath. Supported: package.json, requirements.txt"
    }
}

# Parses npm package.json
function Parse-PackageJson {
    param([string]$Path, [switch]$IncludeDev)

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($null -ne $json.dependencies) {
        foreach ($prop in $json.dependencies.PSObject.Properties) {
            $deps.Add([PSCustomObject]@{
                Name    = $prop.Name
                Version = Get-NormalizedVersion $prop.Value
            })
        }
    }

    if ($IncludeDev -and $null -ne $json.devDependencies) {
        foreach ($prop in $json.devDependencies.PSObject.Properties) {
            $deps.Add([PSCustomObject]@{
                Name    = $prop.Name
                Version = Get-NormalizedVersion $prop.Value
            })
        }
    }

    return $deps.ToArray()
}

# Parses pip requirements.txt
function Parse-RequirementsTxt {
    param([string]$Path)

    $lines = Get-Content $Path
    $deps  = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        # Skip blank lines and comment lines
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
        # Skip options like -r, --index-url, etc.
        if ($trimmed.StartsWith('-')) { continue }

        # Parse: name[extras]<specifier><version>
        # e.g. numpy==1.24.0, requests>=2.28.0, django~=4.2.0
        if ($trimmed -match '^([A-Za-z0-9_\-\.]+)(?:\[.*?\])?(?:[~<>=!]+)(.+)$') {
            $deps.Add([PSCustomObject]@{
                Name    = $Matches[1]
                Version = Get-NormalizedVersion $Matches[2]
            })
        }
        elseif ($trimmed -match '^([A-Za-z0-9_\-\.]+)$') {
            $deps.Add([PSCustomObject]@{
                Name    = $Matches[1]
                Version = ""
            })
        }
    }

    return $deps.ToArray()
}

#endregion

#region --- License Status ---

# Determines the compliance status of a single license.
# Returns: "approved", "denied", or "unknown"
function Get-LicenseStatus {
    param(
        [string]$License,
        [string[]]$AllowList,
        [string[]]$DenyList
    )

    if ([string]::IsNullOrWhiteSpace($License)) { return "unknown" }

    # Deny list takes priority — copyleft licenses block everything
    foreach ($denied in $DenyList) {
        if ($License -ieq $denied) { return "denied" }
    }

    foreach ($allowed in $AllowList) {
        if ($License -ieq $allowed) { return "approved" }
    }

    return "unknown"
}

#endregion

#region --- Compliance Report ---

# Builds the compliance report for every dependency in a manifest.
#
# LicenseLookup is a scriptblock: { param($Name, $Version) return $licenseString }
# If null, uses the built-in mock-data lookup (when MockDataPath is supplied) or
# returns $null (unknown) for every package.
function Get-ComplianceReport {
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [scriptblock]$LicenseLookup = $null,
        [string]$MockDataPath = ""
    )

    $config = Get-LicenseConfig -ConfigPath $ConfigPath
    $deps   = Get-Dependencies -ManifestPath $ManifestPath

    # Build the lookup function: prefer passed scriptblock, else mock data file, else null
    $lookupFn = $LicenseLookup
    if ($null -eq $lookupFn -and -not [string]::IsNullOrWhiteSpace($MockDataPath)) {
        if (-not (Test-Path $MockDataPath)) {
            throw "Mock data file not found: $MockDataPath"
        }
        $mockData = Get-Content $MockDataPath -Raw | ConvertFrom-Json
        $lookupFn = {
            param([string]$Name, [string]$Version)
            $val = $mockData.PSObject.Properties[$Name]
            if ($null -ne $val) { return $val.Value }
            return $null
        }
    }

    $report = foreach ($dep in $deps) {
        $license = $null
        if ($null -ne $lookupFn) {
            $license = & $lookupFn $dep.Name $dep.Version
        }

        $status = Get-LicenseStatus -License $license -AllowList $config.AllowList -DenyList $config.DenyList

        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($null -ne $license) { $license } else { "UNKNOWN" }
            Status  = $status
        }
    }

    return $report
}

#endregion

#region --- Report Formatting ---

# Formats the compliance report as a human-readable string.
function Format-ComplianceReport {
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$Report,
        [string]$ManifestPath = ""
    )

    $approved = @($Report | Where-Object { $_.Status -eq "approved" })
    $denied   = @($Report | Where-Object { $_.Status -eq "denied"   })
    $unknown  = @($Report | Where-Object { $_.Status -eq "unknown"  })

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("=== Dependency License Compliance Report ===")
    if ($ManifestPath) {
        $lines.Add("Manifest: $ManifestPath")
    }
    $lines.Add("Date: $(Get-Date -Format 'yyyy-MM-dd')")
    $lines.Add("")

    $lines.Add("APPROVED ($($approved.Count)):")
    foreach ($dep in $approved) {
        $lines.Add("  $($dep.Name)@$($dep.Version) - $($dep.License)")
    }
    $lines.Add("")

    $lines.Add("DENIED ($($denied.Count)):")
    foreach ($dep in $denied) {
        $lines.Add("  $($dep.Name)@$($dep.Version) - $($dep.License)")
    }
    $lines.Add("")

    $lines.Add("UNKNOWN ($($unknown.Count)):")
    foreach ($dep in $unknown) {
        $lines.Add("  $($dep.Name)@$($dep.Version) - $($dep.License)")
    }
    $lines.Add("")

    $lines.Add("Summary: $($approved.Count) approved, $($denied.Count) denied, $($unknown.Count) unknown")

    $overallStatus = if ($denied.Count -gt 0) { "FAIL (denied dependencies found)" } else { "PASS" }
    $lines.Add("Status: $overallStatus")

    return $lines -join "`n"
}

#endregion

#region --- Entry Point ---

# Run as a script (not dot-sourced by tests).
# When dot-sourced, $ManifestPath and $ConfigPath are "" so this block is skipped.
if (-not [string]::IsNullOrWhiteSpace($ManifestPath) -and -not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    try {
        $report = Get-ComplianceReport `
            -ManifestPath $ManifestPath `
            -ConfigPath   $ConfigPath `
            -MockDataPath $MockDataPath

        $formatted = Format-ComplianceReport -Report $report -ManifestPath $ManifestPath
        Write-Host $formatted

        # Exit 0 always — workflow is report-only (does not block on denied licenses)
        exit 0
    }
    catch {
        Write-Error "License checker failed: $_"
        exit 1
    }
}

#endregion
