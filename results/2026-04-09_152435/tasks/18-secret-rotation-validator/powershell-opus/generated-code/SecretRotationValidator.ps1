#!/usr/bin/env pwsh
# SecretRotationValidator.ps1
#
# Validates secret rotation status against configured policies and generates
# reports grouped by urgency (EXPIRED, WARNING, OK).
#
# TDD approach: Tests were written first (see SecretRotationValidator.Tests.ps1),
# then this implementation was built to satisfy them.
#
# Approach:
#   1. Read a JSON config containing secrets with rotation metadata
#   2. Compare each secret's expiry (lastRotated + rotationPolicyDays) to a reference date
#   3. Classify each secret as EXPIRED, WARNING, or OK based on the warning window
#   4. Output results in markdown table or JSON format

[CmdletBinding()]
param(
    # Path to the JSON configuration file containing secret definitions
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    # Number of days before expiry to trigger a warning. -1 means use config value or default (14).
    [Parameter()]
    [int]$WarningWindowDays = -1,

    # Output format: markdown table or JSON
    [Parameter()]
    [ValidateSet("markdown", "json")]
    [string]$OutputFormat = "markdown",

    # Reference date for expiry calculations (yyyy-MM-dd). Defaults to today.
    [Parameter()]
    [string]$ReferenceDate = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Determine reference date ---
if ($ReferenceDate -eq "") {
    $refDate = (Get-Date).Date
} else {
    try {
        $refDate = [DateTime]::ParseExact($ReferenceDate, "yyyy-MM-dd", $null)
    } catch {
        Write-Error "Invalid ReferenceDate format '$ReferenceDate'. Expected yyyy-MM-dd."
        exit 1
    }
}

# --- Read and validate config ---
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

try {
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config file: $_"
    exit 1
}

if (-not $config.PSObject.Properties['secrets'] -or $config.secrets.Count -eq 0) {
    Write-Error "Config must contain a non-empty 'secrets' array."
    exit 1
}

# --- Resolve warning window: param > config > default(14) ---
if ($WarningWindowDays -eq -1) {
    if ($config.PSObject.Properties['warningWindowDays']) {
        $WarningWindowDays = [int]$config.warningWindowDays
    } else {
        $WarningWindowDays = 14
    }
}

# --- Classify secrets by rotation status ---
$expired = @()
$warning = @()
$ok = @()

foreach ($secret in $config.secrets) {
    # Validate required fields
    foreach ($field in @('name', 'lastRotated', 'rotationPolicyDays', 'requiredBy')) {
        if (-not $secret.PSObject.Properties[$field]) {
            Write-Error "Secret entry missing required field '$field'."
            exit 1
        }
    }

    try {
        $lastRotated = [DateTime]::ParseExact($secret.lastRotated, "yyyy-MM-dd", $null)
    } catch {
        Write-Error "Invalid lastRotated date for secret '$($secret.name)': '$($secret.lastRotated)'. Expected yyyy-MM-dd."
        exit 1
    }

    $expiryDate = $lastRotated.AddDays([int]$secret.rotationPolicyDays)
    $daysUntilExpiry = ($expiryDate - $refDate).Days
    $requiredByStr = ($secret.requiredBy -join ", ")

    $entry = [PSCustomObject]@{
        Name            = $secret.name
        LastRotated     = $secret.lastRotated
        PolicyDays      = [int]$secret.rotationPolicyDays
        ExpiryDate      = $expiryDate.ToString("yyyy-MM-dd")
        DaysUntilExpiry = $daysUntilExpiry
        RequiredBy      = $requiredByStr
        Status          = ""
    }

    if ($daysUntilExpiry -lt 0) {
        $entry.Status = "EXPIRED"
        $expired += $entry
    } elseif ($daysUntilExpiry -le $WarningWindowDays) {
        $entry.Status = "WARNING"
        $warning += $entry
    } else {
        $entry.Status = "OK"
        $ok += $entry
    }
}

# --- Generate output ---
if ($OutputFormat -eq "json") {
    # Build a structured report object for JSON serialization
    $report = [ordered]@{
        referenceDate     = $refDate.ToString("yyyy-MM-dd")
        warningWindowDays = $WarningWindowDays
        summary           = [ordered]@{
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
        }
        expired = @($expired | ForEach-Object {
            [ordered]@{
                name            = $_.Name
                lastRotated     = $_.LastRotated
                policyDays      = $_.PolicyDays
                expiryDate      = $_.ExpiryDate
                daysUntilExpiry = $_.DaysUntilExpiry
                requiredBy      = $_.RequiredBy
                status          = $_.Status
            }
        })
        warning = @($warning | ForEach-Object {
            [ordered]@{
                name            = $_.Name
                lastRotated     = $_.LastRotated
                policyDays      = $_.PolicyDays
                expiryDate      = $_.ExpiryDate
                daysUntilExpiry = $_.DaysUntilExpiry
                requiredBy      = $_.RequiredBy
                status          = $_.Status
            }
        })
        ok = @($ok | ForEach-Object {
            [ordered]@{
                name            = $_.Name
                lastRotated     = $_.LastRotated
                policyDays      = $_.PolicyDays
                expiryDate      = $_.ExpiryDate
                daysUntilExpiry = $_.DaysUntilExpiry
                requiredBy      = $_.RequiredBy
                status          = $_.Status
            }
        })
    }
    $report | ConvertTo-Json -Depth 5
} else {
    # Markdown table output grouped by urgency
    Write-Output "# Secret Rotation Report"
    Write-Output "Reference Date: $($refDate.ToString('yyyy-MM-dd'))"
    Write-Output "Warning Window: $WarningWindowDays days"
    Write-Output ""

    # EXPIRED section
    Write-Output "## EXPIRED ($($expired.Count))"
    if ($expired.Count -gt 0) {
        Write-Output "| Name | Last Rotated | Policy (days) | Expiry Date | Days Overdue | Required By |"
        Write-Output "|------|-------------|---------------|-------------|-------------|-------------|"
        foreach ($s in $expired) {
            $overdue = [Math]::Abs($s.DaysUntilExpiry)
            Write-Output "| $($s.Name) | $($s.LastRotated) | $($s.PolicyDays) | $($s.ExpiryDate) | $overdue | $($s.RequiredBy) |"
        }
    } else {
        Write-Output "No expired secrets."
    }
    Write-Output ""

    # WARNING section
    Write-Output "## WARNING ($($warning.Count))"
    if ($warning.Count -gt 0) {
        Write-Output "| Name | Last Rotated | Policy (days) | Expiry Date | Days Until Expiry | Required By |"
        Write-Output "|------|-------------|---------------|-------------|-------------------|-------------|"
        foreach ($s in $warning) {
            Write-Output "| $($s.Name) | $($s.LastRotated) | $($s.PolicyDays) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $($s.RequiredBy) |"
        }
    } else {
        Write-Output "No secrets in warning state."
    }
    Write-Output ""

    # OK section
    Write-Output "## OK ($($ok.Count))"
    if ($ok.Count -gt 0) {
        Write-Output "| Name | Last Rotated | Policy (days) | Expiry Date | Days Until Expiry | Required By |"
        Write-Output "|------|-------------|---------------|-------------|-------------------|-------------|"
        foreach ($s in $ok) {
            Write-Output "| $($s.Name) | $($s.LastRotated) | $($s.PolicyDays) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $($s.RequiredBy) |"
        }
    } else {
        Write-Output "No secrets in ok state."
    }
    Write-Output ""
    Write-Output "Summary: $($expired.Count) expired, $($warning.Count) warning, $($ok.Count) ok"
}

exit 0
