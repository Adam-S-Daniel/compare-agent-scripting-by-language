# LicenseChecker.ps1
# Dependency License Checker — parses manifests, looks up licenses (mocked),
# checks against allow/deny lists, and generates a compliance report.

# ── Parse-PackageJson ──────────────────────────────────────────────────────────
# Reads a package.json file and returns an array of [Name, Version] objects
# from the "dependencies" (and optionally "devDependencies") section.
function Parse-PackageJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $json = Get-Content $Path -Raw | ConvertFrom-Json

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($section in @("dependencies", "devDependencies")) {
        if ($json.PSObject.Properties[$section]) {
            $json.$section.PSObject.Properties | ForEach-Object {
                # Strip semver range prefixes (^, ~, >=, etc.)
                $ver = $_.Value -replace '^[\^~>=<]+', ''
                $deps.Add([PSCustomObject]@{
                    Name    = $_.Name
                    Version = $ver
                })
            }
        }
    }
    return $deps
}

# ── Parse-RequirementsTxt ──────────────────────────────────────────────────────
# Reads a requirements.txt file and returns [Name, Version] objects.
# Handles "package==version", "package>=version", and plain "package" lines.
function Parse-RequirementsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $deps = [System.Collections.Generic.List[PSCustomObject]]::new()
    Get-Content $Path | ForEach-Object {
        $line = $_.Trim()
        # Skip comments and blank lines
        if ($line -and $line -notmatch '^\s*#') {
            if ($line -match '^([A-Za-z0-9_\-\.]+)\s*[=><!\^~]+\s*(.+)$') {
                $deps.Add([PSCustomObject]@{
                    Name    = $Matches[1].Trim()
                    Version = $Matches[2].Trim()
                })
            } else {
                # No version pinned
                $deps.Add([PSCustomObject]@{
                    Name    = $line
                    Version = "latest"
                })
            }
        }
    }
    return $deps
}

# ── Get-LicenseConfig ─────────────────────────────────────────────────────────
# Loads a JSON config file containing allowList and denyList arrays.
function Get-LicenseConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content $Path -Raw | ConvertFrom-Json
    return [PSCustomObject]@{
        AllowList = @($raw.allowList)
        DenyList  = @($raw.denyList)
    }
}

# ── Get-DependencyLicense ─────────────────────────────────────────────────────
# Looks up the SPDX license identifier for a dependency.
# In production this would call an API (npmjs.com, PyPI, etc.).
# Here it uses a MockDatabase hashtable for deterministic testing.
function Get-DependencyLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Version,
        [hashtable]$MockDatabase = @{}
    )

    if ($MockDatabase.ContainsKey($Name)) {
        return $MockDatabase[$Name]
    }
    return "UNKNOWN"
}

# ── Get-LicenseStatus ─────────────────────────────────────────────────────────
# Classifies a license string as 'approved', 'denied', or 'unknown'
# based on the supplied config object.
function Get-LicenseStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$License,
        [Parameter(Mandatory)][PSCustomObject]$Config
    )

    if ($Config.DenyList -contains $License) { return "denied"   }
    if ($Config.AllowList -contains $License) { return "approved" }
    return "unknown"
}

# ── Invoke-LicenseCheck ───────────────────────────────────────────────────────
# Orchestrates the full check: parse manifest → lookup licenses → classify.
# Returns an array of report objects with Name, Version, License, Status.
function Invoke-LicenseCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][PSCustomObject]$Config,
        [hashtable]$MockDatabase = @{}
    )

    # Auto-detect manifest type by filename
    $fileName = Split-Path $ManifestPath -Leaf
    $deps = switch -Wildcard ($fileName) {
        "*.json" { Parse-PackageJson     -Path $ManifestPath; break }
        "*.txt"  { Parse-RequirementsTxt -Path $ManifestPath; break }
        default  { throw "Unsupported manifest type: $fileName" }
    }

    $report = foreach ($dep in $deps) {
        $license = Get-DependencyLicense -Name $dep.Name -Version $dep.Version -MockDatabase $MockDatabase
        $status  = Get-LicenseStatus     -License $license -Config $Config
        [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }
    return $report
}

# ── Format-ComplianceReport ───────────────────────────────────────────────────
# Formats the report array as a human-readable string with a summary section.
function Format-ComplianceReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Report
    )

    $sep60 = "=" * 60
    $sep80 = "-" * 80
    $sep61 = "-" * 60

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("DEPENDENCY LICENSE COMPLIANCE REPORT")
    $lines.Add($sep60)
    $lines.Add(("{0,-30} {1,-12} {2,-20} {3}" -f "Package", "Version", "License", "Status"))
    $lines.Add($sep80)

    foreach ($entry in $Report) {
        $statusIcon = switch ($entry.Status) {
            "approved" { "[OK]" }
            "denied"   { "[!!]" }
            default    { "[??]" }
        }
        $lines.Add(("{0,-30} {1,-12} {2,-20} {3} {4}" -f `
            $entry.Name, $entry.Version, $entry.License, $statusIcon, $entry.Status))
    }

    $approved = ($Report | Where-Object { $_.Status -eq "approved" }).Count
    $denied   = ($Report | Where-Object { $_.Status -eq "denied"   }).Count
    $unknown  = ($Report | Where-Object { $_.Status -eq "unknown"  }).Count

    $lines.Add("")
    $lines.Add($sep60)
    $lines.Add("SUMMARY")
    $lines.Add($sep61)
    $lines.Add("Total:    $($Report.Count)")
    $lines.Add("Approved: $approved")
    $lines.Add("Denied:   $denied")
    $lines.Add("Unknown:  $unknown")

    if ($denied -gt 0) {
        $lines.Add("")
        $lines.Add("WARNING: $denied denied license(s) found. Review before shipping.")
    }

    return $lines -join "`n"
}

# ── Get-ComplianceExitCode ────────────────────────────────────────────────────
# Returns 0 if no denied licenses; 1 if any denied license found.
function Get-ComplianceExitCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Report
    )

    $deniedCount = ($Report | Where-Object { $_.Status -eq "denied" }).Count
    return $(if ($deniedCount -gt 0) { 1 } else { 0 })
}
