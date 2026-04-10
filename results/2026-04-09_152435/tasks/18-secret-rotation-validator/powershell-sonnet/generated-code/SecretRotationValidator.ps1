# SecretRotationValidator.ps1
# Secret Rotation Validator — identifies expired/expiring secrets and generates rotation reports.
#
# Usage:
#   ./SecretRotationValidator.ps1 -ConfigFile ./fixtures/mixed-secrets.json -Format json
#   ./SecretRotationValidator.ps1 -ConfigFile ./fixtures/mixed-secrets.json -Format markdown -ReferenceDate "2026-04-10"
#
# The script can also be dot-sourced in tests to load functions without executing the main body.

[CmdletBinding()]
param(
    [string]$ConfigFile        = "",
    [ValidateSet("markdown", "json")]
    [string]$Format            = "markdown",
    # ReferenceDate allows injecting a fixed date for deterministic testing.
    # Defaults to today when empty.
    [string]$ReferenceDate     = "",
    [int]$WarningWindowDays    = 14
)

# ============================================================
# FUNCTION: Get-SecretStatus
# Classifies a single secret as expired / warning / ok.
# Accepts both hashtable and PSCustomObject (from ConvertFrom-Json).
# ============================================================
function Get-SecretStatus {
    [CmdletBinding()]
    param(
        # Secret object with: name, lastRotated, rotationPolicyDays, requiredBy
        $Secret,
        [Parameter(Mandatory)]
        [string]$ReferenceDate,
        [int]$WarningWindowDays = 14
    )

    try {
        $ref       = [datetime]::Parse($ReferenceDate)
        $rotated   = [datetime]::Parse($Secret.lastRotated)
        $expiry    = $rotated.AddDays([int]$Secret.rotationPolicyDays)
        # Whole-day difference: truncate to date only to avoid fractional-day surprises
        $refDate    = $ref.Date
        $expiryDate = $expiry.Date
        $daysUntilExpiry = ($expiryDate - $refDate).Days
    }
    catch {
        throw "Failed to parse dates for secret '$($Secret.name)': $_"
    }

    # Classification rules:
    #   daysUntilExpiry < 0  -> expired (past deadline)
    #   0 <= daysUntilExpiry <= WarningWindowDays -> warning (expiring soon)
    #   daysUntilExpiry > WarningWindowDays -> ok
    if ($daysUntilExpiry -lt 0) {
        $urgency = "expired"
    }
    elseif ($daysUntilExpiry -le $WarningWindowDays) {
        $urgency = "warning"
    }
    else {
        $urgency = "ok"
    }

    return [PSCustomObject]@{
        name               = $Secret.name
        lastRotated        = $Secret.lastRotated
        rotationPolicyDays = [int]$Secret.rotationPolicyDays
        requiredBy         = @($Secret.requiredBy)
        expiryDate         = $expiryDate.ToString("yyyy-MM-dd")
        daysUntilExpiry    = $daysUntilExpiry
        urgency            = $urgency
    }
}

# ============================================================
# FUNCTION: New-RotationReport
# Takes an array of status objects and produces a formatted report string.
# Supports "markdown" and "json" output formats.
# ============================================================
function New-RotationReport {
    [CmdletBinding()]
    param(
        [array]$Statuses,
        [ValidateSet("markdown", "json")]
        [string]$Format            = "markdown",
        [string]$ReferenceDate     = (Get-Date -Format "yyyy-MM-dd"),
        [int]$WarningWindowDays    = 14
    )

    # Group secrets by urgency category
    $expired = @($Statuses | Where-Object { $_.urgency -eq "expired" })
    $warning = @($Statuses | Where-Object { $_.urgency -eq "warning" })
    $ok      = @($Statuses | Where-Object { $_.urgency -eq "ok" })

    if ($Format -eq "json") {
        return ConvertTo-JsonReport -Expired $expired -Warning $warning -Ok $ok `
            -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays -Total $Statuses.Count
    }
    else {
        return ConvertTo-MarkdownReport -Expired $expired -Warning $warning -Ok $ok `
            -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays -Total $Statuses.Count
    }
}

# ============================================================
# FUNCTION: ConvertTo-JsonReport  (private helper)
# Serializes the report data as JSON.
# ============================================================
function ConvertTo-JsonReport {
    param(
        [array]$Expired,
        [array]$Warning,
        [array]$Ok,
        [string]$ReferenceDate,
        [int]$WarningWindowDays,
        [int]$Total
    )

    $reportObj = [PSCustomObject]@{
        generatedAt      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        referenceDate    = $ReferenceDate
        warningWindowDays = $WarningWindowDays
        summary          = [PSCustomObject]@{
            total   = $Total
            expired = $Expired.Count
            warning = $Warning.Count
            ok      = $Ok.Count
        }
        notifications    = [PSCustomObject]@{
            expired = $Expired
            warning = $Warning
            ok      = $Ok
        }
    }

    return $reportObj | ConvertTo-Json -Depth 10
}

# ============================================================
# FUNCTION: ConvertTo-MarkdownReport  (private helper)
# Formats the report as a Markdown table.
# ============================================================
function ConvertTo-MarkdownReport {
    param(
        [array]$Expired,
        [array]$Warning,
        [array]$Ok,
        [string]$ReferenceDate,
        [int]$WarningWindowDays,
        [int]$Total
    )

    $sb = [System.Text.StringBuilder]::new()

    $sb.AppendLine("# Secret Rotation Report") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("**Reference Date:** $ReferenceDate") | Out-Null
    $sb.AppendLine("**Warning Window:** $WarningWindowDays days") | Out-Null
    $sb.AppendLine("") | Out-Null

    # Summary table
    $sb.AppendLine("## Summary") | Out-Null
    $sb.AppendLine("") | Out-Null
    $sb.AppendLine("| Category | Count |") | Out-Null
    $sb.AppendLine("|----------|-------|") | Out-Null
    $sb.AppendLine("| Expired  | $($Expired.Count) |") | Out-Null
    $sb.AppendLine("| Warning  | $($Warning.Count) |") | Out-Null
    $sb.AppendLine("| OK       | $($Ok.Count) |") | Out-Null
    $sb.AppendLine("| **Total** | **$Total** |") | Out-Null
    $sb.AppendLine("") | Out-Null

    # Expired secrets section
    if ($Expired.Count -gt 0) {
        $sb.AppendLine("## Expired Secrets — Immediate Action Required") | Out-Null
        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Overdue | Required By |") | Out-Null
        $sb.AppendLine("|------|--------------|-------------|--------------|-------------|") | Out-Null
        foreach ($s in $Expired) {
            $overdue = [Math]::Abs($s.daysUntilExpiry)
            $services = ($s.requiredBy -join ", ")
            $sb.AppendLine("| $($s.name) | $($s.lastRotated) | $($s.expiryDate) | $overdue | $services |") | Out-Null
        }
        $sb.AppendLine("") | Out-Null
    }

    # Warning secrets section
    if ($Warning.Count -gt 0) {
        $sb.AppendLine("## Warning — Expiring Soon") | Out-Null
        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |") | Out-Null
        $sb.AppendLine("|------|--------------|-------------|-------------------|-------------|") | Out-Null
        foreach ($s in $Warning) {
            $services = ($s.requiredBy -join ", ")
            $sb.AppendLine("| $($s.name) | $($s.lastRotated) | $($s.expiryDate) | $($s.daysUntilExpiry) | $services |") | Out-Null
        }
        $sb.AppendLine("") | Out-Null
    }

    # OK secrets section
    if ($Ok.Count -gt 0) {
        $sb.AppendLine("## OK — No Action Needed") | Out-Null
        $sb.AppendLine("") | Out-Null
        $sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |") | Out-Null
        $sb.AppendLine("|------|--------------|-------------|-------------------|-------------|") | Out-Null
        foreach ($s in $Ok) {
            $services = ($s.requiredBy -join ", ")
            $sb.AppendLine("| $($s.name) | $($s.lastRotated) | $($s.expiryDate) | $($s.daysUntilExpiry) | $services |") | Out-Null
        }
        $sb.AppendLine("") | Out-Null
    }

    return $sb.ToString()
}

# ============================================================
# FUNCTION: Invoke-SecretRotationValidator
# Top-level entry point: reads a JSON config file and returns the report.
# ============================================================
function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile,
        [ValidateSet("markdown", "json")]
        [string]$Format         = "markdown",
        [string]$ReferenceDate  = "",
        [int]$WarningWindowDays = 14
    )

    if (-not (Test-Path $ConfigFile)) {
        throw "Config file not found: $ConfigFile"
    }

    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse config file '$ConfigFile': $_"
    }

    # Use config-specified values as defaults when params are not explicitly set
    if ([string]::IsNullOrEmpty($ReferenceDate)) {
        if ($config.referenceDate) {
            $ReferenceDate = $config.referenceDate
        }
        else {
            $ReferenceDate = Get-Date -Format "yyyy-MM-dd"
        }
    }

    # Config warningWindowDays overrides the default (14) if caller didn't specify
    if (-not $PSBoundParameters.ContainsKey('WarningWindowDays') -and $config.warningWindowDays) {
        $WarningWindowDays = [int]$config.warningWindowDays
    }

    if (-not $config.secrets) {
        throw "Config file '$ConfigFile' missing required 'secrets' array"
    }

    # Process each secret
    $statuses = $config.secrets | ForEach-Object {
        Get-SecretStatus -Secret $_ -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays
    }

    return New-RotationReport -Statuses $statuses -Format $Format `
        -ReferenceDate $ReferenceDate -WarningWindowDays $WarningWindowDays
}

# ============================================================
# MAIN EXECUTION
# Only runs when invoked directly (not when dot-sourced in tests).
# Check: when dot-sourced, $MyInvocation.InvocationName is '.'
# ============================================================
if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrEmpty($ConfigFile)) {
        Write-Error "ERROR: -ConfigFile parameter is required."
        Write-Error "Usage: ./SecretRotationValidator.ps1 -ConfigFile <path> [-Format markdown|json] [-ReferenceDate yyyy-MM-dd] [-WarningWindowDays N]"
        exit 1
    }

    try {
        $report = Invoke-SecretRotationValidator `
            -ConfigFile $ConfigFile `
            -Format $Format `
            -ReferenceDate $ReferenceDate `
            -WarningWindowDays $WarningWindowDays

        Write-Output $report
    }
    catch {
        Write-Error "ERROR: $_"
        exit 1
    }
}
