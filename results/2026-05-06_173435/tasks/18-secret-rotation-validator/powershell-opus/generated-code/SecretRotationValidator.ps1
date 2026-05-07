# Secret Rotation Validator
# Analyzes secret metadata to identify expired/expiring secrets and generates reports.

param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [int]$WarningDays = 7,

    [Parameter(Mandatory = $false)]
    [ValidateSet('json', 'markdown')]
    [string]$OutputFormat = 'json',

    [Parameter(Mandatory = $false)]
    [datetime]$ReferenceDate = (Get-Date)
)

function Get-SecretConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }

    $content = Get-Content $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Configuration file is empty: $Path"
    }

    try {
        $config = $content | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in configuration file: $Path"
    }

    if (-not $config.secrets) {
        throw "Configuration missing 'secrets' array: $Path"
    }

    return $config
}

function Get-SecretStatus {
    param(
        [object]$Secret,
        [int]$WarningDays,
        [datetime]$ReferenceDate
    )

    $lastRotated = [datetime]::Parse($Secret.last_rotated)
    $expirationDate = $lastRotated.AddDays($Secret.rotation_policy_days)
    $daysUntilExpiry = ($expirationDate - $ReferenceDate).Days

    if ($daysUntilExpiry -lt 0) {
        $status = 'expired'
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        $status = 'warning'
    }
    else {
        $status = 'ok'
    }

    return [PSCustomObject]@{
        Name              = $Secret.name
        LastRotated       = $lastRotated
        RotationPolicyDays = $Secret.rotation_policy_days
        ExpirationDate    = $expirationDate
        DaysUntilExpiry   = $daysUntilExpiry
        Status            = $status
        RequiredBy        = $Secret.required_by
    }
}

function Get-RotationReport {
    param(
        [string]$ConfigPath,
        [int]$WarningDays = 7,
        [datetime]$ReferenceDate = (Get-Date)
    )

    $config = Get-SecretConfig -Path $ConfigPath
    $results = @()

    foreach ($secret in $config.secrets) {
        $results += Get-SecretStatus -Secret $secret -WarningDays $WarningDays -ReferenceDate $ReferenceDate
    }

    $grouped = @{
        expired = @($results | Where-Object { $_.Status -eq 'expired' })
        warning = @($results | Where-Object { $_.Status -eq 'warning' })
        ok      = @($results | Where-Object { $_.Status -eq 'ok' })
    }

    return [PSCustomObject]@{
        ReferenceDate = $ReferenceDate
        WarningDays   = $WarningDays
        TotalSecrets  = $results.Count
        Results       = $results
        Grouped       = $grouped
    }
}

function Format-ReportAsJson {
    param([object]$Report)

    $output = @{
        reference_date = $Report.ReferenceDate.ToString('yyyy-MM-dd')
        warning_days   = $Report.WarningDays
        total_secrets  = $Report.TotalSecrets
        summary        = @{
            expired = $Report.Grouped.expired.Count
            warning = $Report.Grouped.warning.Count
            ok      = $Report.Grouped.ok.Count
        }
        secrets        = @{
            expired = @($Report.Grouped.expired | ForEach-Object {
                @{
                    name                = $_.Name
                    last_rotated        = $_.LastRotated.ToString('yyyy-MM-dd')
                    rotation_policy_days = $_.RotationPolicyDays
                    expiration_date     = $_.ExpirationDate.ToString('yyyy-MM-dd')
                    days_until_expiry   = $_.DaysUntilExpiry
                    required_by         = $_.RequiredBy
                }
            })
            warning = @($Report.Grouped.warning | ForEach-Object {
                @{
                    name                = $_.Name
                    last_rotated        = $_.LastRotated.ToString('yyyy-MM-dd')
                    rotation_policy_days = $_.RotationPolicyDays
                    expiration_date     = $_.ExpirationDate.ToString('yyyy-MM-dd')
                    days_until_expiry   = $_.DaysUntilExpiry
                    required_by         = $_.RequiredBy
                }
            })
            ok = @($Report.Grouped.ok | ForEach-Object {
                @{
                    name                = $_.Name
                    last_rotated        = $_.LastRotated.ToString('yyyy-MM-dd')
                    rotation_policy_days = $_.RotationPolicyDays
                    expiration_date     = $_.ExpirationDate.ToString('yyyy-MM-dd')
                    days_until_expiry   = $_.DaysUntilExpiry
                    required_by         = $_.RequiredBy
                }
            })
        }
    }

    return $output | ConvertTo-Json -Depth 5
}

function Format-ReportAsMarkdown {
    param([object]$Report)

    $lines = @()
    $lines += "# Secret Rotation Report"
    $lines += ""
    $lines += "**Reference Date:** $($Report.ReferenceDate.ToString('yyyy-MM-dd'))"
    $lines += "**Warning Window:** $($Report.WarningDays) days"
    $lines += "**Total Secrets:** $($Report.TotalSecrets)"
    $lines += ""
    $lines += "## Summary"
    $lines += ""
    $lines += "| Status | Count |"
    $lines += "|--------|-------|"
    $lines += "| Expired | $($Report.Grouped.expired.Count) |"
    $lines += "| Warning | $($Report.Grouped.warning.Count) |"
    $lines += "| OK | $($Report.Grouped.ok.Count) |"
    $lines += ""

    if ($Report.Grouped.expired.Count -gt 0) {
        $lines += "## Expired Secrets"
        $lines += ""
        $lines += "| Name | Last Rotated | Policy (days) | Expired On | Days Overdue | Required By |"
        $lines += "|------|-------------|---------------|------------|--------------|-------------|"
        foreach ($s in $Report.Grouped.expired) {
            $overdue = [Math]::Abs($s.DaysUntilExpiry)
            $services = $s.RequiredBy -join ', '
            $lines += "| $($s.Name) | $($s.LastRotated.ToString('yyyy-MM-dd')) | $($s.RotationPolicyDays) | $($s.ExpirationDate.ToString('yyyy-MM-dd')) | $overdue | $services |"
        }
        $lines += ""
    }

    if ($Report.Grouped.warning.Count -gt 0) {
        $lines += "## Warning Secrets"
        $lines += ""
        $lines += "| Name | Last Rotated | Policy (days) | Expires On | Days Remaining | Required By |"
        $lines += "|------|-------------|---------------|------------|----------------|-------------|"
        foreach ($s in $Report.Grouped.warning) {
            $services = $s.RequiredBy -join ', '
            $lines += "| $($s.Name) | $($s.LastRotated.ToString('yyyy-MM-dd')) | $($s.RotationPolicyDays) | $($s.ExpirationDate.ToString('yyyy-MM-dd')) | $($s.DaysUntilExpiry) | $services |"
        }
        $lines += ""
    }

    if ($Report.Grouped.ok.Count -gt 0) {
        $lines += "## OK Secrets"
        $lines += ""
        $lines += "| Name | Last Rotated | Policy (days) | Expires On | Days Remaining | Required By |"
        $lines += "|------|-------------|---------------|------------|----------------|-------------|"
        foreach ($s in $Report.Grouped.ok) {
            $services = $s.RequiredBy -join ', '
            $lines += "| $($s.Name) | $($s.LastRotated.ToString('yyyy-MM-dd')) | $($s.RotationPolicyDays) | $($s.ExpirationDate.ToString('yyyy-MM-dd')) | $($s.DaysUntilExpiry) | $services |"
        }
        $lines += ""
    }

    return $lines -join "`n"
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    $report = Get-RotationReport -ConfigPath $ConfigPath -WarningDays $WarningDays -ReferenceDate $ReferenceDate

    if ($OutputFormat -eq 'json') {
        $output = Format-ReportAsJson -Report $report
    }
    else {
        $output = Format-ReportAsMarkdown -Report $report
    }

    Write-Output $output

    # Exit with non-zero if any secrets are expired
    if ($report.Grouped.expired.Count -gt 0) {
        exit 1
    }
}
