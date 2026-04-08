# Dependency License Checker
# Parses package manifests, looks up licenses (mockable), and produces a compliance report.
# Approach: each public function is small and single-purpose, making it easy to unit-test.

# ---------------------------------------------------------------------------
# FUNCTION: Parse-PackageJson
# Parses a package.json string and returns an array of [PSCustomObject] with
# Name and Version properties.  -IncludeDev also includes devDependencies.
# ---------------------------------------------------------------------------
function Parse-PackageJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content,
        [switch]$IncludeDev
    )

    # Attempt JSON parse; surface a friendly error on bad input
    try {
        $parsed = $Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON: $_"
    }

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Merge regular and (optionally) dev dependencies into one list
    $buckets = @($parsed.dependencies)
    if ($IncludeDev -and $parsed.devDependencies) {
        $buckets += $parsed.devDependencies
    }

    foreach ($bucket in $buckets) {
        if ($null -eq $bucket) { continue }
        # ConvertFrom-Json returns a PSCustomObject; iterate its NoteProperty members
        foreach ($prop in $bucket.PSObject.Properties) {
            $deps.Add([PSCustomObject]@{
                Name    = $prop.Name
                Version = $prop.Value
            })
        }
    }

    return $deps.ToArray()
}

# ---------------------------------------------------------------------------
# FUNCTION: Parse-RequirementsTxt
# Parses a requirements.txt string (one package per line).
# Handles pinned (==), range (>=, <=, ~=), and bare package names.
# Skips comment lines (#) and blank lines.
# ---------------------------------------------------------------------------
function Parse-RequirementsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Content
    )

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($line in ($Content -split "`n")) {
        $trimmed = $line.Trim()

        # Skip blank lines and comments
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }

        # Match: PackageName[specifier][version]
        # Specifier can be ==, >=, <=, ~=, !=, >, <
        # For exact pins (==) we store just the version number; for range specifiers
        # we keep the operator so callers can see the constraint.
        if ($trimmed -match '^([A-Za-z0-9_\-\.]+)\s*(==|>=|<=|~=|!=|>|<)\s*(.+)$') {
            $specifier = $Matches[2]
            $version   = if ($specifier -eq '==') { $Matches[3] } else { "$specifier$($Matches[3])" }
            $deps.Add([PSCustomObject]@{
                Name    = $Matches[1]
                Version = $version
            })
        } else {
            # Bare package name with no version specifier
            $deps.Add([PSCustomObject]@{
                Name    = $trimmed
                Version = "unspecified"
            })
        }
    }

    return $deps.ToArray()
}

# ---------------------------------------------------------------------------
# FUNCTION: Get-DependencyLicense
# Looks up the license for a single package using the provided lookup function.
# $LookupFn must be a [scriptblock] that accepts one string parameter (package name)
# and returns a license string (or $null when unknown).
# This design allows tests to inject a mock without touching production code.
# ---------------------------------------------------------------------------
function Get-DependencyLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]   $PackageName,
        [Parameter(Mandatory)][scriptblock] $LookupFn
    )

    return & $LookupFn $PackageName
}

# ---------------------------------------------------------------------------
# FUNCTION: Test-LicenseCompliance
# Given a license string and a config hashtable with AllowedLicenses and
# DeniedLicenses arrays, returns "approved", "denied", or "unknown".
# ---------------------------------------------------------------------------
function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [string]   $License,
        [Parameter(Mandatory)][hashtable] $Config
    )

    if ([string]::IsNullOrWhiteSpace($License)) { return "unknown" }

    if ($Config.DeniedLicenses -contains $License)  { return "denied"   }
    if ($Config.AllowedLicenses -contains $License) { return "approved" }

    return "unknown"
}

# ---------------------------------------------------------------------------
# FUNCTION: New-ComplianceReport
# Combines the dependency list, license lookup, and compliance config into a
# report object with per-entry detail and an aggregated summary.
# ---------------------------------------------------------------------------
function New-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]    $Dependencies,
        [Parameter(Mandatory)][hashtable]   $Config,
        [Parameter(Mandatory)][scriptblock] $LookupFn
    )

    $entries = foreach ($dep in $Dependencies) {
        $license = Get-DependencyLicense -PackageName $dep.Name -LookupFn $LookupFn
        $status  = Test-LicenseCompliance -License $license -Config $Config

        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }

    # Aggregate summary
    $approved = @($entries | Where-Object { $_.Status -eq "approved" }).Count
    $denied   = @($entries | Where-Object { $_.Status -eq "denied"   }).Count
    $unknown  = @($entries | Where-Object { $_.Status -eq "unknown"  }).Count

    $summary = [PSCustomObject]@{
        Total     = $entries.Count
        Approved  = $approved
        Denied    = $denied
        Unknown   = $unknown
        Compliant = ($denied -eq 0)
    }

    return [PSCustomObject]@{
        Entries = $entries
        Summary = $summary
    }
}

# ---------------------------------------------------------------------------
# FUNCTION: Format-ComplianceReport
# Renders a compliance report object to a human-readable string.
# ---------------------------------------------------------------------------
function Format-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object] $Report
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("  DEPENDENCY LICENSE COMPLIANCE REPORT")
    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("")

    # Column headers
    [void]$sb.AppendLine(("{0,-30} {1,-15} {2,-15} {3}" -f "Package", "Version", "License", "Status"))
    [void]$sb.AppendLine("-" * 80)

    foreach ($entry in $Report.Entries) {
        $licDisplay = if ($null -eq $entry.License) { "(unknown)" } else { $entry.License }
        [void]$sb.AppendLine(("{0,-30} {1,-15} {2,-15} {3}" -f $entry.Name, $entry.Version, $licDisplay, $entry.Status))
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("SUMMARY")
    [void]$sb.AppendLine("-" * 30)
    [void]$sb.AppendLine("Total:    $($Report.Summary.Total)")
    [void]$sb.AppendLine("Approved: $($Report.Summary.Approved)")
    [void]$sb.AppendLine("Denied:   $($Report.Summary.Denied)")
    [void]$sb.AppendLine("Unknown:  $($Report.Summary.Unknown)")
    [void]$sb.AppendLine("Compliant: $($Report.Summary.Compliant)")
    [void]$sb.AppendLine("=" * 60)

    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# FUNCTION: Invoke-LicenseCheck
# Top-level entry point.  Reads a manifest file, loads config, runs the full
# pipeline, and returns the report object.
# Detects manifest type by file extension (.json → package.json, .txt → requirements.txt).
# ---------------------------------------------------------------------------
function Invoke-LicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]      $ManifestPath,
        [Parameter(Mandatory)][string]      $ConfigPath,
        [Parameter(Mandatory)][scriptblock] $LookupFn
    )

    # --- Load and validate manifest ---
    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest file not found: $ManifestPath"
    }
    $manifestContent = Get-Content -Path $ManifestPath -Raw

    # --- Load and validate config ---
    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }
    $configJson = Get-Content -Path $ConfigPath -Raw
    $configObj  = $configJson | ConvertFrom-Json

    # Convert PSCustomObject → hashtable for Test-LicenseCompliance
    $config = @{
        AllowedLicenses = [string[]]$configObj.AllowedLicenses
        DeniedLicenses  = [string[]]$configObj.DeniedLicenses
    }

    # --- Parse manifest based on file extension ---
    $ext = [System.IO.Path]::GetExtension($ManifestPath).ToLower()
    switch ($ext) {
        ".json" {
            $dependencies = Parse-PackageJson -Content $manifestContent
        }
        ".txt" {
            $dependencies = Parse-RequirementsTxt -Content $manifestContent
        }
        default {
            throw "Unsupported manifest format '$ext'. Expected .json or .txt"
        }
    }

    # --- Build and return report ---
    return New-ComplianceReport -Dependencies $dependencies -Config $config -LookupFn $LookupFn
}
