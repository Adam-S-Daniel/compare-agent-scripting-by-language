<#
.SYNOPSIS
    Secret Rotation Validator - identifies expired/expiring secrets and generates reports.
.DESCRIPTION
    Reads a JSON configuration of secrets with metadata, evaluates each against its
    rotation policy and a configurable warning window, then outputs a report in
    either markdown table or JSON format, grouped by urgency: expired, warning, ok.
.EXAMPLE
    ./SecretRotationValidator.ps1 -ConfigPath secrets.json -OutputFormat markdown
    ./SecretRotationValidator.ps1 -ConfigPath secrets.json -OutputFormat json -ReferenceDate "2024-06-01"
#>
param(
    [string]$ConfigPath    = "fixtures/secrets-config.json",
    [ValidateSet("markdown", "json")]
    [string]$OutputFormat  = "markdown",
    [int]$WarningDays      = 14,
    # Accept as string so locale-independent parsing works in all environments
    [string]$ReferenceDate = ""
)

# ── Core evaluation function ──────────────────────────────────────────────────

function Get-SecretStatus {
    <#
    .SYNOPSIS Evaluates one secret against its rotation policy.
    Returns a PSCustomObject with Status = "expired" | "warning" | "ok".
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Secret,
        [Parameter(Mandatory)][datetime]$ReferenceDate,
        [Parameter(Mandatory)][int]$WarningDays
    )

    $lastRotated = [datetime]::ParseExact(
        $Secret.lastRotated, "yyyy-MM-dd",
        [System.Globalization.CultureInfo]::InvariantCulture)

    $expiryDate      = $lastRotated.AddDays($Secret.rotationDays)
    $daysUntilExpiry = [int]($expiryDate - $ReferenceDate).TotalDays

    $status = if ($daysUntilExpiry -lt 0) {
        "expired"
    } elseif ($daysUntilExpiry -le $WarningDays) {
        "warning"
    } else {
        "ok"
    }

    return [PSCustomObject]@{
        Name            = $Secret.name
        LastRotated     = $Secret.lastRotated
        ExpiryDate      = $expiryDate.ToString("yyyy-MM-dd")
        DaysUntilExpiry = $daysUntilExpiry
        RotationDays    = $Secret.rotationDays
        RequiredBy      = $Secret.requiredBy
        Status          = $status
    }
}

# ── Output formatters ─────────────────────────────────────────────────────────

function Format-MarkdownReport {
    param([Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]]$Results)

    $expired = @($Results | Where-Object { $_.Status -eq "expired" })
    $warning = @($Results | Where-Object { $_.Status -eq "warning" })
    $ok      = @($Results | Where-Object { $_.Status -eq "ok"      })

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Secret Rotation Report")
    $null = $sb.AppendLine("")

    # ── Expired ──────────────────────────────────────────────────────────
    $null = $sb.AppendLine("## Expired Secrets")
    $null = $sb.AppendLine("")
    if ($expired.Count -eq 0) {
        $null = $sb.AppendLine("_No expired secrets._")
    } else {
        $null = $sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Overdue | Required By |")
        $null = $sb.AppendLine("|------|--------------|-------------|--------------|-------------|")
        foreach ($s in $expired) {
            $overdue    = [Math]::Abs($s.DaysUntilExpiry)
            $requiredBy = ($s.RequiredBy -join ", ")
            $null = $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $overdue | $requiredBy |")
        }
    }
    $null = $sb.AppendLine("")

    # ── Warning ───────────────────────────────────────────────────────────
    $null = $sb.AppendLine("## Warning (Expiring Soon)")
    $null = $sb.AppendLine("")
    if ($warning.Count -eq 0) {
        $null = $sb.AppendLine("_No secrets expiring soon._")
    } else {
        $null = $sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |")
        $null = $sb.AppendLine("|------|--------------|-------------|-------------------|-------------|")
        foreach ($s in $warning) {
            $requiredBy = ($s.RequiredBy -join ", ")
            $null = $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $requiredBy |")
        }
    }
    $null = $sb.AppendLine("")

    # ── OK ────────────────────────────────────────────────────────────────
    $null = $sb.AppendLine("## OK")
    $null = $sb.AppendLine("")
    if ($ok.Count -eq 0) {
        $null = $sb.AppendLine("_No secrets in OK status._")
    } else {
        $null = $sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |")
        $null = $sb.AppendLine("|------|--------------|-------------|-------------------|-------------|")
        foreach ($s in $ok) {
            $requiredBy = ($s.RequiredBy -join ", ")
            $null = $sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $requiredBy |")
        }
    }
    $null = $sb.AppendLine("")

    # ── Summary ───────────────────────────────────────────────────────────
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- **Expired**: $($expired.Count)")
    $null = $sb.AppendLine("- **Warning**: $($warning.Count)")
    $null = $sb.AppendLine("- **OK**: $($ok.Count)")
    $null = $sb.AppendLine("- **Total**: $($Results.Count)")

    return $sb.ToString()
}

function Format-JsonReport {
    param([Parameter(Mandatory)][AllowEmptyCollection()][PSCustomObject[]]$Results)

    $expired = @($Results | Where-Object { $_.Status -eq "expired" })
    $warning = @($Results | Where-Object { $_.Status -eq "warning" })
    $ok      = @($Results | Where-Object { $_.Status -eq "ok"      })

    $report = [ordered]@{
        generatedAt   = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        summary       = [ordered]@{
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
            total   = $Results.Count
        }
        notifications = [ordered]@{
            expired = $expired
            warning = $warning
            ok      = $ok
        }
    }

    return $report | ConvertTo-Json -Depth 6
}

# ── Orchestrator (also used by tests) ─────────────────────────────────────────

function Invoke-SecretRotationValidator {
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [ValidateSet("markdown", "json")]
        [string]$OutputFormat  = "markdown",
        [int]$WarningDays      = 14,
        [string]$ReferenceDate = ""
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # Config-level warningWindowDays overrides the parameter default
    $effectiveWarnDays = if ($config.warningWindowDays) {
        [int]$config.warningWindowDays
    } else {
        $WarningDays
    }

    $refDate = if ($ReferenceDate) {
        [datetime]::ParseExact(
            $ReferenceDate, "yyyy-MM-dd",
            [System.Globalization.CultureInfo]::InvariantCulture)
    } else {
        Get-Date
    }

    $results = @(foreach ($secret in $config.secrets) {
        Get-SecretStatus -Secret $secret -ReferenceDate $refDate -WarningDays $effectiveWarnDays
    })

    if ($OutputFormat -eq "json") {
        return Format-JsonReport -Results $results
    } else {
        return Format-MarkdownReport -Results $results
    }
}

# ── Entry point guard: only execute when run directly, not when dot-sourced ───
# $MyInvocation.InvocationName is '.' when the script is dot-sourced by Pester.
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-SecretRotationValidator `
            -ConfigPath   $ConfigPath `
            -OutputFormat $OutputFormat `
            -WarningDays  $WarningDays `
            -ReferenceDate $ReferenceDate
    } catch {
        Write-Error "Secret rotation validation failed: $_"
        exit 1
    }
}
