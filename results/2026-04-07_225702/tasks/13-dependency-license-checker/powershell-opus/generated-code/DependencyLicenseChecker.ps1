# DependencyLicenseChecker.ps1
# Parses dependency manifests, checks licenses against allow/deny lists,
# and generates a compliance report.

function Get-Dependencies {
    <#
    .SYNOPSIS
        Parses a dependency manifest file and returns a list of dependencies.
    .DESCRIPTION
        Supports package.json (npm) and requirements.txt (Python).
        Returns objects with Name and Version properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Manifest file not found: $Path"
    }

    $fileName = [System.IO.Path]::GetFileName($Path)
    $results = @()

    switch ($fileName) {
        "package.json" {
            $pkg = Get-Content -Path $Path -Raw | ConvertFrom-Json
            # Collect both dependencies and devDependencies
            foreach ($section in @('dependencies', 'devDependencies')) {
                if ($pkg.PSObject.Properties[$section]) {
                    $deps = $pkg.$section
                    foreach ($prop in $deps.PSObject.Properties) {
                        $results += [PSCustomObject]@{
                            Name    = $prop.Name
                            Version = $prop.Value
                        }
                    }
                }
            }
        }
        "requirements.txt" {
            # Parse pip requirements: lines like "package==1.0" or "package>=1.0"
            $lines = Get-Content -Path $Path
            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                # Skip blank lines and comments
                if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
                # Split on version specifiers (==, >=, <=, ~=, !=, >, <)
                if ($trimmed -match '^([A-Za-z0-9_.-]+)\s*[><=!~]=?\s*(.+)$') {
                    $results += [PSCustomObject]@{
                        Name    = $Matches[1]
                        Version = $Matches[2].Trim()
                    }
                } else {
                    # Package with no version pinned
                    $results += [PSCustomObject]@{
                        Name    = $trimmed
                        Version = "*"
                    }
                }
            }
        }
        default {
            throw "Unsupported manifest format: $fileName"
        }
    }

    return $results
}

function Get-DependencyLicense {
    <#
    .SYNOPSIS
        Looks up the license for a dependency by name.
    .DESCRIPTION
        Uses a hashtable as a mock license database. Returns the license string
        if found, or "Unknown" if the package is not in the database.
        In production, this would call a registry API (npm, PyPI, etc.).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$LicenseDatabase
    )

    if ($LicenseDatabase.ContainsKey($Name)) {
        return $LicenseDatabase[$Name]
    }
    return "Unknown"
}

function Test-LicenseCompliance {
    <#
    .SYNOPSIS
        Checks a license against allow/deny lists and returns its compliance status.
    .DESCRIPTION
        Returns "Denied" if on the deny list (deny takes precedence),
        "Approved" if on the allow list, or "Unknown" otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$License,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Deny list takes precedence — safety first
    if ($Config.DenyList -contains $License) {
        return "Denied"
    }
    if ($Config.AllowList -contains $License) {
        return "Approved"
    }
    return "Unknown"
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Generates a full compliance report for all dependencies in a manifest.
    .DESCRIPTION
        Orchestrates: parse manifest -> look up each license -> check compliance.
        Returns a report object with Entries (per-dependency details) and Summary counts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [hashtable]$LicenseDatabase,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $dependencies = Get-Dependencies -Path $ManifestPath
    $entries = @()

    foreach ($dep in $dependencies) {
        $license = Get-DependencyLicense -Name $dep.Name -LicenseDatabase $LicenseDatabase
        $status = Test-LicenseCompliance -License $license -Config $Config

        $entries += [PSCustomObject]@{
            Name    = $dep.Name
            Version = $dep.Version
            License = $license
            Status  = $status
        }
    }

    # Compute summary counts
    $approved = @($entries | Where-Object { $_.Status -eq "Approved" }).Count
    $denied   = @($entries | Where-Object { $_.Status -eq "Denied" }).Count
    $unknown  = @($entries | Where-Object { $_.Status -eq "Unknown" }).Count

    return [PSCustomObject]@{
        Entries = $entries
        Summary = [PSCustomObject]@{
            Total    = $entries.Count
            Approved = $approved
            Denied   = $denied
            Unknown  = $unknown
        }
    }
}

function Import-LicenseConfig {
    <#
    .SYNOPSIS
        Loads license allow/deny list configuration from a JSON file.
    .DESCRIPTION
        Expects a JSON file with "allowList" and "denyList" arrays.
        Returns a hashtable with AllowList and DenyList keys.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return @{
        AllowList = @($raw.allowList)
        DenyList  = @($raw.denyList)
    }
}

function Format-ComplianceReport {
    <#
    .SYNOPSIS
        Formats a compliance report object as a human-readable text string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("=== Dependency License Compliance Report ===")
    [void]$sb.AppendLine()

    foreach ($entry in $Report.Entries) {
        $statusTag = switch ($entry.Status) {
            "Approved" { "[APPROVED]" }
            "Denied"   { "[DENIED]"   }
            default    { "[UNKNOWN]"  }
        }
        [void]$sb.AppendLine("  $statusTag $($entry.Name)@$($entry.Version) - License: $($entry.License)")
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine("--- Summary ---")
    [void]$sb.AppendLine("  Total: $($Report.Summary.Total) | Approved: $($Report.Summary.Approved) | Denied: $($Report.Summary.Denied) | Unknown: $($Report.Summary.Unknown)")

    return $sb.ToString()
}
