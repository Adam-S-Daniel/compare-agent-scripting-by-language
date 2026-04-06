# DependencyLicenseChecker.ps1
# Module for parsing dependency manifests, looking up licenses,
# checking compliance against allow/deny lists, and generating reports.
#
# Supports: package.json (Node.js), requirements.txt (Python), .csproj (.NET)
# License lookup is injectable via a scriptblock for easy mocking/testing.

# ── Built-in mock license database ──────────────────────────────────────────
# Used as the default license lookup when no external lookup is provided.
# In production, this would be replaced with an API call to a license service.
$script:BuiltInLicenseDb = @{
    "express"          = "MIT"
    "lodash"           = "MIT"
    "react"            = "MIT"
    "axios"            = "MIT"
    "jest"             = "MIT"
    "mocha"            = "MIT"
    "webpack"          = "MIT"
    "typescript"       = "Apache-2.0"
    "flask"            = "BSD-3-Clause"
    "requests"         = "Apache-2.0"
    "numpy"            = "BSD-3-Clause"
    "pandas"           = "BSD-3-Clause"
    "django"           = "BSD-3-Clause"
    "Newtonsoft.Json"  = "MIT"
    "Serilog"          = "Apache-2.0"
    "leftpad"          = "MIT"
}

# ── Parse-DependencyManifest ────────────────────────────────────────────────
# Reads a dependency manifest file and returns an array of objects with
# Name and Version properties. Auto-detects format from file name/extension.
function Parse-DependencyManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Validate the file exists
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Manifest file '$Path' does not exist."
    }

    $fileName = Split-Path -Leaf $Path

    # Route to the appropriate parser based on file name
    if ($fileName -eq "package.json") {
        return Parse-PackageJson -Path $Path
    }
    elseif ($fileName -like "requirements*.txt") {
        return Parse-RequirementsTxt -Path $Path
    }
    elseif ($fileName -like "*.csproj") {
        return Parse-Csproj -Path $Path
    }
    else {
        throw "Unsupported manifest format: '$fileName'. Supported formats: package.json, requirements.txt, *.csproj"
    }
}

# ── Parse-PackageJson (internal) ────────────────────────────────────────────
# Parses a Node.js package.json, combining dependencies and devDependencies.
# Strips version prefix characters (^, ~, >=, etc.).
function Parse-PackageJson {
    [CmdletBinding()]
    param([string]$Path)

    $content = Get-Content -Raw -Path $Path | ConvertFrom-Json
    $results = @()

    # Collect from both dependency sections
    foreach ($section in @('dependencies', 'devDependencies')) {
        # Check property exists first (strict mode safe)
        if (-not ($content.PSObject.Properties.Name -contains $section)) { continue }
        $deps = $content.$section
        if ($null -eq $deps) { continue }

        # ConvertFrom-Json returns PSCustomObject; iterate its properties
        $deps.PSObject.Properties | ForEach-Object {
            $results += [PSCustomObject]@{
                Name    = $_.Name
                Version = ($_.Value -replace '^[~^>=<!\s]+', '')
            }
        }
    }

    # Always return an array (even if empty) so .Count works
    return , $results
}

# ── Parse-RequirementsTxt (internal) ────────────────────────────────────────
# Parses a Python requirements.txt file. Supports ==, >=, <=, ~= specifiers.
# Skips comments (#) and blank lines.
function Parse-RequirementsTxt {
    [CmdletBinding()]
    param([string]$Path)

    $results = @()
    $lines = Get-Content -Path $Path

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Skip blanks and comments
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        # Match patterns like: package==1.0.0, package>=2.0, package~=3.1
        if ($trimmed -match '^([A-Za-z0-9_.-]+)\s*([><=!~]+)\s*(.+)$') {
            $results += [PSCustomObject]@{
                Name    = $Matches[1]
                Version = $Matches[3].Trim()
            }
        }
        elseif ($trimmed -match '^([A-Za-z0-9_.-]+)$') {
            # Package with no version specifier
            $results += [PSCustomObject]@{
                Name    = $Matches[1]
                Version = "any"
            }
        }
    }

    return , $results
}

# ── Parse-Csproj (internal) ─────────────────────────────────────────────────
# Parses a .NET .csproj file, extracting PackageReference elements.
function Parse-Csproj {
    [CmdletBinding()]
    param([string]$Path)

    $results = @()
    [xml]$xml = Get-Content -Raw -Path $Path

    # Find all PackageReference elements regardless of nesting
    $refs = $xml.SelectNodes("//PackageReference")

    foreach ($ref in $refs) {
        $name    = $ref.GetAttribute("Include")
        $version = $ref.GetAttribute("Version")

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $results += [PSCustomObject]@{
                Name    = $name
                Version = if ($version) { $version } else { "any" }
            }
        }
    }

    return , $results
}

# ── Get-DependencyLicense ───────────────────────────────────────────────────
# Looks up the license for a dependency. Accepts an optional -LicenseLookup
# scriptblock for dependency injection (mocking in tests). Falls back to
# the built-in mock database if no lookup is provided.
function Get-DependencyLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [scriptblock]$LicenseLookup = $null
    )

    if ($LicenseLookup) {
        return & $LicenseLookup $Name $Version
    }

    # Default: use built-in mock database
    if ($script:BuiltInLicenseDb.ContainsKey($Name)) {
        return $script:BuiltInLicenseDb[$Name]
    }

    return $null
}

# ── Test-LicenseCompliance ──────────────────────────────────────────────────
# Checks a license string against the allow/deny lists in the config.
# Returns: "approved", "denied", or "unknown".
# Comparison is case-insensitive.
function Test-LicenseCompliance {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$License,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Null or empty license => unknown
    if ([string]::IsNullOrWhiteSpace($License)) {
        return "unknown"
    }

    # Check deny list first (deny takes precedence if somehow in both)
    foreach ($denied in $Config.DeniedLicenses) {
        if ($License -ieq $denied) {
            return "denied"
        }
    }

    # Check allow list
    foreach ($allowed in $Config.AllowedLicenses) {
        if ($License -ieq $allowed) {
            return "approved"
        }
    }

    # Not in either list
    return "unknown"
}

# ── Import-LicenseConfig ───────────────────────────────────────────────────
# Loads and validates a license configuration from a JSON file.
# The config must contain AllowedLicenses and DeniedLicenses arrays.
function Import-LicenseConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file '$Path' does not exist."
    }

    $raw = Get-Content -Raw -Path $Path | ConvertFrom-Json

    # Validate required fields
    if (-not ($raw.PSObject.Properties.Name -contains "AllowedLicenses")) {
        throw "Configuration is missing required field 'AllowedLicenses'."
    }
    if (-not ($raw.PSObject.Properties.Name -contains "DeniedLicenses")) {
        throw "Configuration is missing required field 'DeniedLicenses'."
    }

    # Convert to hashtable for easier consumption
    return @{
        AllowedLicenses = @($raw.AllowedLicenses)
        DeniedLicenses  = @($raw.DeniedLicenses)
    }
}

# ── New-ComplianceReport ────────────────────────────────────────────────────
# Orchestrates the full workflow: parse manifest, look up licenses,
# check compliance, and return a structured report object.
function New-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [hashtable]$Config,

        [scriptblock]$LicenseLookup = $null
    )

    # Step 1: Parse dependencies from the manifest
    $dependencies = Parse-DependencyManifest -Path $ManifestPath

    # Step 2: For each dependency, look up its license and check compliance
    $depResults = @()
    $approved = 0
    $denied   = 0
    $unknown  = 0

    foreach ($dep in $dependencies) {
        $license = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -LicenseLookup $LicenseLookup
        $status  = Test-LicenseCompliance -License $license -Config $Config

        $depResults += [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = if ($license) { $license } else { "UNKNOWN" }
            Status  = $status
        }

        switch ($status) {
            "approved" { $approved++ }
            "denied"   { $denied++ }
            "unknown"  { $unknown++ }
        }
    }

    # Step 3: Build and return the report
    return [PSCustomObject]@{
        GeneratedAt       = (Get-Date -Format "o")
        ManifestFile      = (Split-Path -Leaf $ManifestPath)
        TotalDependencies = $dependencies.Count
        Summary           = [PSCustomObject]@{
            Approved = $approved
            Denied   = $denied
            Unknown  = $unknown
        }
        Dependencies      = $depResults
    }
}

# ── Format-ComplianceReport ─────────────────────────────────────────────────
# Formats a compliance report object as a human-readable text string.
function Format-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("  DEPENDENCY LICENSE COMPLIANCE REPORT")
    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("  Manifest:  $($Report.ManifestFile)")
    [void]$sb.AppendLine("  Generated: $($Report.GeneratedAt)")
    [void]$sb.AppendLine("  Total:     $($Report.TotalDependencies) dependencies")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("-" * 60)
    [void]$sb.AppendLine("  SUMMARY")
    [void]$sb.AppendLine("-" * 60)
    [void]$sb.AppendLine("  Approved: $($Report.Summary.Approved)")
    [void]$sb.AppendLine("  Denied: $($Report.Summary.Denied)")
    [void]$sb.AppendLine("  Unknown: $($Report.Summary.Unknown)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("-" * 60)
    [void]$sb.AppendLine("  DEPENDENCIES")
    [void]$sb.AppendLine("-" * 60)

    # Table header
    $fmt = "  {0,-25} {1,-12} {2,-15} {3,-10}"
    [void]$sb.AppendLine(($fmt -f "NAME", "VERSION", "LICENSE", "STATUS"))
    [void]$sb.AppendLine("  " + ("-" * 56))

    foreach ($dep in $Report.Dependencies) {
        $statusTag = switch ($dep.Status) {
            "approved" { "approved" }
            "denied"   { "denied" }
            "unknown"  { "unknown" }
        }
        [void]$sb.AppendLine(($fmt -f $dep.Name, $dep.Version, $dep.License, $statusTag))
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("=" * 60)

    return $sb.ToString()
}
