# SecretRotationValidator.ps1
# Validates secrets against rotation policies and identifies expiring/expired secrets

class SecretRotationValidator {
    [int]$WarningDays

    SecretRotationValidator([int]$warningDays) {
        $this.WarningDays = $warningDays
    }
}

function New-SecretRotationValidator {
    param(
        [Parameter(Mandatory=$true)]
        [int]$WarningDays
    )

    return [SecretRotationValidator]::new($WarningDays)
}

function Import-SecretsFromJson {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    try {
        $content = Get-Content $ConfigPath -Raw
        $secrets = $content | ConvertFrom-Json
        return $secrets
    }
    catch {
        throw "Failed to parse secrets configuration: $_"
    }
}

function Get-SecretStatus {
    param(
        [Parameter(Mandatory=$true)]
        $Validator,

        [Parameter(Mandatory=$true)]
        $Secret
    )

    $lastRotated = [datetime]::ParseExact($Secret.LastRotated, "yyyy-MM-dd", $null)
    $daysAgo = (Get-Date) - $lastRotated
    $daysUntilExpiry = $Secret.RotationPolicyDays - $daysAgo.Days

    $status = if ($daysUntilExpiry -lt 0) {
        "Expired"
    }
    elseif ($daysUntilExpiry -le $Validator.WarningDays) {
        "Warning"
    }
    else {
        "OK"
    }

    return @{
        Name = $Secret.Name
        Status = $status
        DaysUntilExpiry = [Math]::Max($daysUntilExpiry, 0)
        LastRotated = $Secret.LastRotated
        RotationPolicy = $Secret.RotationPolicyDays
        Services = $Secret.RequiredByServices -join ", "
    }
}

function New-RotationReport {
    param(
        [Parameter(Mandatory=$true)]
        $Validator,

        [Parameter(Mandatory=$true)]
        [array]$Secrets
    )

    $statuses = @()
    foreach ($secret in $Secrets) {
        $status = Get-SecretStatus -Validator $Validator -Secret $secret
        $statuses += $status
    }

    $report = @{
        Expired = $statuses | Where-Object { $_.Status -eq "Expired" }
        Warning = $statuses | Where-Object { $_.Status -eq "Warning" }
        OK = $statuses | Where-Object { $_.Status -eq "OK" }
        AllSecrets = $statuses
        ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    return $report
}

function Format-RotationReportAsMarkdown {
    param(
        [Parameter(Mandatory=$true)]
        $Report
    )

    $markdown = @"
# Secret Rotation Report
**Report Date:** $($Report.ReportDate)

## Summary
- **Expired:** $($Report.Expired.Count)
- **Warning:** $($Report.Warning.Count)
- **OK:** $($Report.OK.Count)

## All Secrets

| Name | Status | Days Until Expiry | Last Rotated | Policy (days) | Services |
|------|--------|-------------------|--------------|---------------|----------|
"@

    foreach ($secret in $Report.AllSecrets) {
        $markdown += "`n| $($secret.Name) | $($secret.Status) | $($secret.DaysUntilExpiry) | $($secret.LastRotated) | $($secret.RotationPolicy) | $($secret.Services) |"
    }

    return $markdown
}

function Format-RotationReportAsJson {
    param(
        [Parameter(Mandatory=$true)]
        $Report
    )

    $jsonReport = @{
        ReportDate = $Report.ReportDate
        Summary = @{
            Expired = $Report.Expired.Count
            Warning = $Report.Warning.Count
            OK = $Report.OK.Count
        }
        Expired = @($Report.Expired)
        Warning = @($Report.Warning)
        OK = @($Report.OK)
    }

    return $jsonReport | ConvertTo-Json -Depth 10
}
