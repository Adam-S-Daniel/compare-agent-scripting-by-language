# Secret Rotation Validator
# Identifies secrets that are expired or expiring within a configurable warning window.
# Generates rotation reports grouped by urgency: expired, warning, ok.
# Supports markdown table and JSON output formats.

<#
.SYNOPSIS
    Evaluates a single secret's rotation status.
.PARAMETER Secret
    Hashtable with keys: name, last_rotated (yyyy-MM-dd), rotation_policy_days, required_by (array).
.PARAMETER WarningWindowDays
    Secrets expiring within this many days are classified as "warning".
.PARAMETER CurrentDate
    Reference date for calculations (defaults to today; injectable for testing).
.OUTPUTS
    Hashtable with Name, Status, DaysUntilExpiry, ExpiryDate, RequiredBy.
#>
function Get-SecretStatus {
    param(
        [Parameter(Mandatory)][hashtable]$Secret,
        [int]$WarningWindowDays = 14,
        [datetime]$CurrentDate = (Get-Date).Date
    )

    $lastRotated = [datetime]::ParseExact($Secret.last_rotated, "yyyy-MM-dd", $null)
    $expiryDate  = $lastRotated.AddDays($Secret.rotation_policy_days)
    # Floor both to date-only so fractional hours don't skew the count
    $expiryDateOnly   = $expiryDate.Date
    $currentDateOnly  = $CurrentDate.Date
    $daysUntilExpiry  = ($expiryDateOnly - $currentDateOnly).Days

    $status = if ($daysUntilExpiry -lt 0) { "expired" }
              elseif ($daysUntilExpiry -le $WarningWindowDays) { "warning" }
              else { "ok" }

    return @{
        Name            = $Secret.name
        Status          = $status
        DaysUntilExpiry = $daysUntilExpiry
        ExpiryDate      = $expiryDateOnly.ToString("yyyy-MM-dd")
        RequiredBy      = ($Secret.required_by -join ", ")
    }
}

<#
.SYNOPSIS
    Loads a secret config JSON file and classifies every secret.
.PARAMETER ConfigPath
    Path to the JSON config file containing a "secrets" array.
.PARAMETER WarningWindowDays
    Forwarded to Get-SecretStatus.
.PARAMETER OutputFormat
    "markdown" | "json" | "object" (returns the hashtable directly, for unit tests).
.PARAMETER CurrentDate
    Reference date (injectable for testing).
#>
function Invoke-SecretRotationValidator {
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [int]$WarningWindowDays = 14,
        [ValidateSet("markdown", "json", "object")][string]$OutputFormat = "markdown",
        [datetime]$CurrentDate = (Get-Date).Date
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content -Raw $ConfigPath | ConvertFrom-Json

    $results = @{
        expired = [System.Collections.Generic.List[hashtable]]::new()
        warning = [System.Collections.Generic.List[hashtable]]::new()
        ok      = [System.Collections.Generic.List[hashtable]]::new()
    }

    foreach ($secret in $config.secrets) {
        $secretHash = @{
            name                 = $secret.name
            last_rotated         = $secret.last_rotated
            rotation_policy_days = [int]$secret.rotation_policy_days
            required_by          = @($secret.required_by)
        }
        $status = Get-SecretStatus -Secret $secretHash -WarningWindowDays $WarningWindowDays -CurrentDate $CurrentDate
        $results[$status.Status].Add($status)
    }

    # Convert lists to plain arrays for downstream consumers
    $output = @{
        expired = @($results.expired)
        warning = @($results.warning)
        ok      = @($results.ok)
    }

    switch ($OutputFormat) {
        "json"     { return Format-JsonReport -Results $output }
        "markdown" { return Format-MarkdownReport -Results $output }
        "object"   { return $output }
    }
}

<#
.SYNOPSIS
    Formats the classification results as a Markdown report with urgency sections.
#>
function Format-MarkdownReport {
    param([Parameter(Mandatory)][hashtable]$Results)

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Secret Rotation Report")
    $lines.Add("")

    $totalExpired = $Results.expired.Count
    $totalWarning = $Results.warning.Count
    $totalOk      = $Results.ok.Count
    $lines.Add("**Summary:** $totalExpired expired | $totalWarning warning | $totalOk ok")
    $lines.Add("")

    # Helper that appends a section with a table
    $addSection = {
        param([string]$Title, [string]$Emoji, $Items)
        $lines.Add("## $Emoji $Title ($($Items.Count))")
        $lines.Add("")
        if ($Items.Count -eq 0) {
            $lines.Add("_No secrets in this category._")
        } else {
            $lines.Add("| Name | Expiry Date | Days Until Expiry | Required By |")
            $lines.Add("|------|-------------|-------------------|-------------|")
            foreach ($item in $Items) {
                $days = if ($item.DaysUntilExpiry -lt 0) { "**$($item.DaysUntilExpiry)** (overdue)" } else { $item.DaysUntilExpiry }
                $lines.Add("| $($item.Name) | $($item.ExpiryDate) | $days | $($item.RequiredBy) |")
            }
        }
        $lines.Add("")
    }

    & $addSection "Expired Secrets"  "🔴" $Results.expired
    & $addSection "Warning Secrets"  "🟡" $Results.warning
    & $addSection "OK Secrets"       "🟢" $Results.ok

    return $lines -join "`n"
}

<#
.SYNOPSIS
    Formats the classification results as structured JSON.
#>
function Format-JsonReport {
    param([Parameter(Mandatory)][hashtable]$Results)

    $report = @{
        summary = @{
            total_expired = $Results.expired.Count
            total_warning = $Results.warning.Count
            total_ok      = $Results.ok.Count
            total         = $Results.expired.Count + $Results.warning.Count + $Results.ok.Count
        }
        expired = @($Results.expired)
        warning = @($Results.warning)
        ok      = @($Results.ok)
    }

    return $report | ConvertTo-Json -Depth 5
}

# ---------------------------------------------------------------------------
# CLI entry point: reads env vars and runs when invoked directly.
# Pester dot-sources this file to import functions; the guard below prevents
# the CLI block from executing during dot-source (InvocationName is '.' then).
# Note: param() blocks cannot appear inside if-statements in PowerShell, so
# CLI arguments come from environment variables set by the workflow.
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
    $cliConfig        = $env:INPUT_CONFIG_FILE
    $cliWarningDays   = if ($env:INPUT_WARNING_WINDOW_DAYS) { [int]$env:INPUT_WARNING_WINDOW_DAYS } else { 14 }
    $cliOutputFormat  = if ($env:INPUT_OUTPUT_FORMAT) { $env:INPUT_OUTPUT_FORMAT } else { "markdown" }
    $cliReferenceDate = $env:INPUT_REFERENCE_DATE

    if (-not $cliConfig) {
        Write-Error "CONFIG_FILE is required. Set the INPUT_CONFIG_FILE environment variable."
        exit 1
    }

    $currentDate = if ($cliReferenceDate) { [datetime]$cliReferenceDate } else { (Get-Date).Date }

    try {
        $report = Invoke-SecretRotationValidator `
            -ConfigPath $cliConfig `
            -WarningWindowDays $cliWarningDays `
            -OutputFormat $cliOutputFormat `
            -CurrentDate $currentDate

        Write-Output $report
    } catch {
        Write-Error "Validation failed: $_"
        exit 1
    }
}
