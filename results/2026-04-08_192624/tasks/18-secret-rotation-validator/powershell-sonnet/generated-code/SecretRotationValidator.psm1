# SecretRotationValidator.psm1
# Module containing all secret rotation validator functions.
# Isolated from the script entry-point to prevent parameter-set conflicts
# when dot-sourced in Pester tests alongside CmdletBinding scripts.

# ============================================================
# Get-SecretDaysUntilExpiry (TDD Round 1)
# Calculates how many days remain before a secret must be rotated.
# Negative value = already expired; 0 = expires today.
# ============================================================
function Get-SecretDaysUntilExpiry {
    param(
        [Parameter(Mandatory)]
        [DateTime]$LastRotated,

        [Parameter(Mandatory)]
        [int]$RotationPolicyDays,

        # Allow callers to override "today" for deterministic testing.
        [Nullable[DateTime]]$AsOf = $null
    )

    $effectiveAsOf = if ($null -eq $AsOf) { (Get-Date).Date } else { $AsOf.Date }
    $expiryDate    = $LastRotated.AddDays($RotationPolicyDays)
    return [int]($expiryDate - $effectiveAsOf).TotalDays
}

# ============================================================
# Get-SecretUrgency (TDD Round 2)
# Classifies a secret as 'expired', 'warning', or 'ok'.
# ============================================================
function Get-SecretUrgency {
    param(
        [Parameter(Mandatory)]
        [int]$DaysUntilExpiry,

        # Warn when this many days or fewer remain before expiry
        [int]$WarningWindowDays = 30
    )

    if ($DaysUntilExpiry -le 0) {
        return "expired"
    }
    elseif ($DaysUntilExpiry -le $WarningWindowDays) {
        return "warning"
    }
    else {
        return "ok"
    }
}

# ============================================================
# Get-SecretRotationReport (TDD Round 3)
# Builds the full rotation report, grouping secrets by urgency.
# ============================================================
function Get-SecretRotationReport {
    param(
        [Parameter(Mandatory)]
        [array]$Secrets,

        [int]$WarningWindowDays = 30,

        [Nullable[DateTime]]$AsOf = $null
    )

    $effectiveAsOf = if ($null -eq $AsOf) { Get-Date } else { $AsOf }
    $expired = [System.Collections.Generic.List[PSObject]]::new()
    $warning = [System.Collections.Generic.List[PSObject]]::new()
    $ok      = [System.Collections.Generic.List[PSObject]]::new()

    foreach ($secret in $Secrets) {
        $days    = Get-SecretDaysUntilExpiry `
            -LastRotated $secret.LastRotated `
            -RotationPolicyDays $secret.RotationPolicyDays `
            -AsOf $effectiveAsOf
        $urgency = Get-SecretUrgency -DaysUntilExpiry $days -WarningWindowDays $WarningWindowDays

        $enriched = [PSCustomObject]@{
            Name               = $secret.Name
            LastRotated        = $secret.LastRotated
            RotationPolicyDays = $secret.RotationPolicyDays
            DaysUntilExpiry    = $days
            RequiredByServices = $secret.RequiredByServices
            Urgency            = $urgency
        }

        switch ($urgency) {
            "expired" { $expired.Add($enriched) }
            "warning" { $warning.Add($enriched) }
            "ok"      { $ok.Add($enriched) }
        }
    }

    return [PSCustomObject]@{
        expired           = $expired.ToArray()
        warning           = $warning.ToArray()
        ok                = $ok.ToArray()
        summary           = [PSCustomObject]@{
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
        }
        generatedAt       = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        warningWindowDays = $WarningWindowDays
    }
}

# ============================================================
# Format-RotationReportMarkdown (TDD Round 4)
# Renders the report as a human-readable markdown document.
# ============================================================
function Format-RotationReportMarkdown {
    param(
        [Parameter(Mandatory)]
        [PSObject]$Report
    )

    $sb = [System.Text.StringBuilder]::new()

    $null = $sb.AppendLine("# Secret Rotation Report")
    $null = $sb.AppendLine("Generated: $($Report.generatedAt)  |  Warning window: $($Report.warningWindowDays) days")
    $null = $sb.AppendLine()

    # Summary table
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("| Urgency  | Count |")
    $null = $sb.AppendLine("|----------|-------|")
    $null = $sb.AppendLine("| Expired  | $($Report.summary.expired) |")
    $null = $sb.AppendLine("| Warning  | $($Report.summary.warning) |")
    $null = $sb.AppendLine("| OK       | $($Report.summary.ok) |")
    $null = $sb.AppendLine()

    $sections = @(
        @{ key = "expired"; heading = "## Expired Secrets" },
        @{ key = "warning"; heading = "## Warning - Expiring Soon" },
        @{ key = "ok";      heading = "## OK - Up to Date" }
    )

    foreach ($section in $sections) {
        $null = $sb.AppendLine($section.heading)
        $secrets = $Report.($section.key)

        if ($secrets.Count -eq 0) {
            $null = $sb.AppendLine("_None_")
        }
        else {
            $null = $sb.AppendLine("| Name | Days Until Expiry | Rotation Policy (days) | Required By | Last Rotated |")
            $null = $sb.AppendLine("|------|:-----------------:|:----------------------:|-------------|:------------:|")

            foreach ($s in $secrets) {
                $services    = $s.RequiredByServices -join ", "
                $lastRotated = if ($s.LastRotated -is [DateTime]) {
                    $s.LastRotated.ToString("yyyy-MM-dd")
                } else {
                    $s.LastRotated
                }
                $null = $sb.AppendLine("| $($s.Name) | $($s.DaysUntilExpiry) | $($s.RotationPolicyDays) | $services | $lastRotated |")
            }
        }
        $null = $sb.AppendLine()
    }

    return $sb.ToString()
}

# ============================================================
# Format-RotationReportJson (TDD Round 5)
# Serialises the report to JSON for machine consumption.
# ============================================================
function Format-RotationReportJson {
    param(
        [Parameter(Mandatory)]
        [PSObject]$Report
    )

    $output = [ordered]@{
        generatedAt       = $Report.generatedAt
        warningWindowDays = $Report.warningWindowDays
        summary           = [ordered]@{
            expired = $Report.summary.expired
            warning = $Report.summary.warning
            ok      = $Report.summary.ok
        }
        expired = $Report.expired
        warning = $Report.warning
        ok      = $Report.ok
    }

    return $output | ConvertTo-Json -Depth 10
}

# ============================================================
# Read-SecretsConfig (TDD Round 6)
# Loads and validates a JSON configuration file.
# ============================================================
function Read-SecretsConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigFile
    )

    if (-not (Test-Path -Path $ConfigFile)) {
        throw "Config file not found: '$ConfigFile'"
    }

    try {
        $raw    = Get-Content -Path $ConfigFile -Raw
        $config = $raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse JSON config '$ConfigFile': $($_.Exception.Message)"
    }

    return $config
}

# ============================================================
# ConvertTo-SecretObjects (helper)
# Converts raw JSON objects (string dates) into typed PSObjects.
# ============================================================
function ConvertTo-SecretObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$JsonSecrets
    )

    return $JsonSecrets | ForEach-Object {
        [PSCustomObject]@{
            Name               = $_.name
            LastRotated        = [DateTime]$_.lastRotated
            RotationPolicyDays = [int]$_.rotationPolicyDays
            RequiredByServices = @($_.requiredByServices)
        }
    }
}

Export-ModuleMember -Function Get-SecretDaysUntilExpiry,
                              Get-SecretUrgency,
                              Get-SecretRotationReport,
                              Format-RotationReportMarkdown,
                              Format-RotationReportJson,
                              Read-SecretsConfig,
                              ConvertTo-SecretObjects
