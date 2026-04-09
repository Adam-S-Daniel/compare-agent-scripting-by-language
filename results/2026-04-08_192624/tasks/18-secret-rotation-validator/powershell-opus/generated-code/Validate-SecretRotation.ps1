<#
.SYNOPSIS
    Validates secret rotation status against configured policies.

.DESCRIPTION
    Reads a JSON configuration of secrets with metadata (name, last-rotated date,
    rotation policy in days, required-by services). Identifies secrets that are
    expired or expiring within a configurable warning window. Generates a rotation
    report grouped by urgency (expired, warning, ok). Supports markdown table and
    JSON output formats.

.PARAMETER ConfigPath
    Path to the JSON file containing secret definitions.

.PARAMETER WarningDays
    Number of days before expiry to trigger a warning. Defaults to 7.

.PARAMETER OutputFormat
    Output format: "json" or "markdown". Defaults to "markdown".

.PARAMETER ReferenceDate
    Optional reference date for calculations (ISO 8601 string). Defaults to today.
    Useful for deterministic testing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter()]
    [int]$WarningDays = 7,

    [Parameter()]
    [ValidateSet("json", "markdown")]
    [string]$OutputFormat = "markdown",

    [Parameter()]
    [string]$ReferenceDate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Determine the reference date for all calculations
if ($ReferenceDate) {
    try {
        $refDate = [datetime]::Parse($ReferenceDate)
    }
    catch {
        Write-Error "Invalid ReferenceDate '$ReferenceDate'. Use ISO 8601 format (e.g. 2026-04-09)."
        exit 1
    }
}
else {
    $refDate = Get-Date
}

# Validate config file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

# Read and parse config
try {
    $configContent = Get-Content -Path $ConfigPath -Raw
    $config = $configContent | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse configuration file: $_"
    exit 1
}

# Extract secrets array — support both { "secrets": [...] } and bare [...]
if ($config.secrets) {
    $secrets = $config.secrets
}
elseif ($config -is [System.Array]) {
    $secrets = $config
}
else {
    Write-Error "Configuration must contain a 'secrets' array or be a JSON array."
    exit 1
}

# Classify each secret into expired, warning, or ok
$expired = @()
$warning = @()
$ok = @()

foreach ($secret in $secrets) {
    # Validate required fields
    if (-not $secret.name -or -not $secret.lastRotated -or -not $secret.rotationPolicyDays) {
        Write-Warning "Skipping secret with missing required fields: $($secret | ConvertTo-Json -Compress)"
        continue
    }

    try {
        $lastRotated = [datetime]::Parse($secret.lastRotated)
    }
    catch {
        Write-Warning "Skipping secret '$($secret.name)' — invalid lastRotated date: $($secret.lastRotated)"
        continue
    }

    $policyDays = [int]$secret.rotationPolicyDays
    $expiryDate = $lastRotated.AddDays($policyDays)
    $daysUntilExpiry = ($expiryDate - $refDate).Days

    # Build services string
    $services = if ($secret.requiredBy) { ($secret.requiredBy -join ", ") } else { "none" }

    $entry = [PSCustomObject]@{
        Name            = $secret.name
        LastRotated     = $lastRotated.ToString("yyyy-MM-dd")
        PolicyDays      = $policyDays
        ExpiryDate      = $expiryDate.ToString("yyyy-MM-dd")
        DaysUntilExpiry = $daysUntilExpiry
        RequiredBy      = $services
        Status          = ""
    }

    if ($daysUntilExpiry -lt 0) {
        $entry.Status = "EXPIRED"
        $expired += $entry
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        $entry.Status = "WARNING"
        $warning += $entry
    }
    else {
        $entry.Status = "OK"
        $ok += $entry
    }
}

# Build the report based on output format
if ($OutputFormat -eq "json") {
    $report = [PSCustomObject]@{
        referenceDate = $refDate.ToString("yyyy-MM-dd")
        warningDays   = $WarningDays
        summary       = [PSCustomObject]@{
            total   = $secrets.Count
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
        }
        expired       = $expired
        warning       = $warning
        ok            = $ok
    }
    $report | ConvertTo-Json -Depth 5
}
else {
    # Markdown output
    Write-Output "# Secret Rotation Report"
    Write-Output ""
    Write-Output "**Reference Date:** $($refDate.ToString('yyyy-MM-dd'))"
    Write-Output "**Warning Window:** $WarningDays days"
    Write-Output ""
    Write-Output "## Summary"
    Write-Output ""
    Write-Output "| Category | Count |"
    Write-Output "|----------|-------|"
    Write-Output "| Total    | $($secrets.Count) |"
    Write-Output "| Expired  | $($expired.Count) |"
    Write-Output "| Warning  | $($warning.Count) |"
    Write-Output "| OK       | $($ok.Count) |"
    Write-Output ""

    # Helper to render a table section
    function Write-SecretTable {
        param([string]$Title, [array]$Items)
        Write-Output "## $Title"
        Write-Output ""
        if ($Items.Count -eq 0) {
            Write-Output "_None_"
        }
        else {
            Write-Output "| Name | Last Rotated | Policy (days) | Expiry Date | Days Until Expiry | Required By |"
            Write-Output "|------|-------------|---------------|-------------|-------------------|-------------|"
            foreach ($item in $Items) {
                Write-Output "| $($item.Name) | $($item.LastRotated) | $($item.PolicyDays) | $($item.ExpiryDate) | $($item.DaysUntilExpiry) | $($item.RequiredBy) |"
            }
        }
        Write-Output ""
    }

    Write-SecretTable -Title "Expired Secrets" -Items $expired
    Write-SecretTable -Title "Secrets Expiring Soon (Warning)" -Items $warning
    Write-SecretTable -Title "OK Secrets" -Items $ok
}

# Exit with non-zero if any secrets are expired
if ($expired.Count -gt 0) {
    exit 1
}
