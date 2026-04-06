# LicenseChecker.ps1
# Dependency license compliance checker.
#
# Approach:
#   1. Parse a dependency manifest (package.json or requirements.txt) to get
#      a list of {Name, Version} objects.
#   2. Load a license config (allow-list / deny-list) from a JSON file.
#   3. Look up each dependency's license via a mock lookup table (so tests
#      remain deterministic — no real HTTP calls needed).
#   4. Classify each license as 'approved', 'denied', or 'unknown'.
#   5. Produce a structured compliance report and a human-readable summary.

# ---------------------------------------------------------------------------
# Parse-PackageJson
# Reads the "dependencies" block of a package.json file and returns an array
# of [PSCustomObject]@{Name; Version} with version prefixes (^, ~) stripped.
# ---------------------------------------------------------------------------
function Parse-PackageJson {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest not found: '$Path'"
    }

    $json = Get-Content $Path -Raw | ConvertFrom-Json

    # Only production dependencies (not devDependencies)
    $deps = $json.dependencies

    if ($null -eq $deps) {
        return @()
    }

    # PSObject property iteration works for JSON objects
    $result = foreach ($name in $deps.PSObject.Properties.Name) {
        $rawVersion = $deps.$name
        # Strip leading ^ or ~ from semver ranges
        $cleanVersion = $rawVersion -replace '^[\^~]', ''

        [PSCustomObject]@{
            Name    = $name
            Version = $cleanVersion
        }
    }

    return @($result)
}

# ---------------------------------------------------------------------------
# Parse-RequirementsTxt
# Reads a pip-style requirements.txt file.  Lines starting with '#' or that
# are blank are ignored.  Each remaining line is expected to be "pkg==version".
# ---------------------------------------------------------------------------
function Parse-RequirementsTxt {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest not found: '$Path'"
    }

    $lines = Get-Content $Path

    $result = foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Skip blank lines and comments
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        # Support == (pinned) and >= / ~= / != specifiers — extract first version token
        if ($trimmed -match '^([A-Za-z0-9_\-\.]+)==([^\s,]+)') {
            [PSCustomObject]@{
                Name    = $Matches[1]
                Version = $Matches[2]
            }
        } elseif ($trimmed -match '^([A-Za-z0-9_\-\.]+)') {
            # Package with no version specified
            [PSCustomObject]@{
                Name    = $Matches[1]
                Version = $null
            }
        }
    }

    return @($result)
}

# ---------------------------------------------------------------------------
# Get-LicenseConfig
# Loads the allow-list and deny-list of SPDX license identifiers from a JSON
# configuration file.  Returns [PSCustomObject]@{AllowList; DenyList}.
# ---------------------------------------------------------------------------
function Get-LicenseConfig {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found: '$Path'"
    }

    $json = Get-Content $Path -Raw | ConvertFrom-Json

    return [PSCustomObject]@{
        AllowList = [string[]]$json.allowList
        DenyList  = [string[]]$json.denyList
    }
}

# ---------------------------------------------------------------------------
# Get-DependencyLicense
# Mock license resolver.  Looks up the license string for a given package in
# the provided hashtable.  Returns $null when the package is not listed.
#
# In a real implementation this would call a registry API (e.g. npmjs.org or
# PyPI) but we keep it mockable for deterministic testing.
# ---------------------------------------------------------------------------
function Get-DependencyLicense {
    param(
        [string]    $Name,
        [string]    $Version,
        [hashtable] $MockLookup
    )

    if ($MockLookup.ContainsKey($Name)) {
        return $MockLookup[$Name]
    }

    # Package not found in lookup → license is unknown
    return $null
}

# ---------------------------------------------------------------------------
# Get-ComplianceStatus
# Classifies a single license string according to the loaded config.
# Returns: 'approved', 'denied', or 'unknown'.
# ---------------------------------------------------------------------------
function Get-ComplianceStatus {
    param(
        [AllowNull()][string] $License,
        $Config   # PSCustomObject with AllowList + DenyList arrays
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

# ---------------------------------------------------------------------------
# Invoke-LicenseCheck  (orchestrator)
# Ties everything together: parse manifest → load config → look up licenses
# → classify → return a structured report array.
#
# Each report entry is [PSCustomObject]@{Name; Version; License; Status}.
# ---------------------------------------------------------------------------
function Invoke-LicenseCheck {
    param(
        [string]    $ManifestPath,
        [string]    $ConfigPath,
        [hashtable] $MockLookup
    )

    # 1. Parse the manifest based on file name
    $leafName = Split-Path $ManifestPath -Leaf
    $deps = switch -Wildcard ($leafName) {
        "package.json"      { Parse-PackageJson      -Path $ManifestPath }
        "requirements.txt"  { Parse-RequirementsTxt  -Path $ManifestPath }
        default             { throw "Unsupported manifest format: '$leafName'. Supported: package.json, requirements.txt" }
    }

    # 2. Load license configuration
    $config = Get-LicenseConfig -Path $ConfigPath

    # 3. For each dependency: look up license and classify
    $report = foreach ($dep in $deps) {
        $license = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -MockLookup $MockLookup
        $status  = Get-ComplianceStatus  -License $license -Config $config

        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }

    return @($report)
}

# ---------------------------------------------------------------------------
# Format-ComplianceReport
# Converts a report array into a human-readable string suitable for console
# output or logging.  Includes a per-dependency table and a summary block.
# ---------------------------------------------------------------------------
function Format-ComplianceReport {
    param(
        [object[]] $Report
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    $lines.Add("=" * 70)
    $lines.Add("  DEPENDENCY LICENSE COMPLIANCE REPORT")
    $lines.Add("=" * 70)
    $lines.Add("")

    # Column widths
    $nameWidth    = [Math]::Max(20, ($Report | ForEach-Object { $_.Name.Length }    | Measure-Object -Maximum).Maximum + 2)
    $versionWidth = [Math]::Max(10, ($Report | ForEach-Object { "$($_.Version)".Length } | Measure-Object -Maximum).Maximum + 2)
    $licenseWidth = [Math]::Max(14, ($Report | ForEach-Object { "$($_.License)".Length } | Measure-Object -Maximum).Maximum + 2)

    $header = "{0,-$nameWidth}{1,-$versionWidth}{2,-$licenseWidth}{3}" -f "Package", "Version", "License", "Status"
    $lines.Add($header)
    $lines.Add("-" * 70)

    foreach ($entry in $Report) {
        $licenseDisplay = if ($null -eq $entry.License) { "(none)" } else { $entry.License }
        $row = "{0,-$nameWidth}{1,-$versionWidth}{2,-$licenseWidth}{3}" -f `
            $entry.Name, $entry.Version, $licenseDisplay, $entry.Status.ToUpper()
        $lines.Add($row)
    }

    $lines.Add("")
    $lines.Add("-" * 70)

    # Summary counts
    $approved = ($Report | Where-Object { $_.Status -eq "approved" }).Count
    $denied   = ($Report | Where-Object { $_.Status -eq "denied"   }).Count
    $unknown  = ($Report | Where-Object { $_.Status -eq "unknown"  }).Count
    $total    = $Report.Count

    $lines.Add("SUMMARY: $total dependencies checked")
    $lines.Add("  approved : $approved")
    $lines.Add("  denied   : $denied")
    $lines.Add("  unknown  : $unknown")
    $lines.Add("=" * 70)

    return $lines -join "`n"
}
