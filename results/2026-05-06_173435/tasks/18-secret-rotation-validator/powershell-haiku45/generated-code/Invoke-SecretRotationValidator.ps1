# Secret Rotation Validator
# Identifies expired/expiring secrets and generates rotation reports

<#
.SYNOPSIS
    Determines the status of a secret based on rotation policy.

.PARAMETER Secret
    Hashtable or PSCustomObject containing Name, LastRotated, RotationPolicyDays, and RequiredBy
#>
function Get-SecretStatus {
    param(
        $Secret,
        [int]$WarningWindow = 7
    )

    # Calculate days since last rotation
    # Handle both datetime and string date formats
    $lastRotatedDate = $Secret.LastRotated
    if ($lastRotatedDate -is [string]) {
        $lastRotatedDate = [datetime]::Parse($lastRotatedDate)
    }

    $daysSinceRotation = (Get-Date) - $lastRotatedDate
    $daysSinceRotationValue = $daysSinceRotation.Days

    # Determine status
    if ($daysSinceRotationValue -gt $Secret.RotationPolicyDays) {
        return @{
            Name = $Secret.Name
            Status = "expired"
            DaysSinceRotation = $daysSinceRotationValue
            RotationPolicyDays = $Secret.RotationPolicyDays
            DaysOverdue = $daysSinceRotationValue - $Secret.RotationPolicyDays
            RequiredBy = $Secret.RequiredBy
        }
    }
    elseif ($daysSinceRotationValue -gt ($Secret.RotationPolicyDays - $WarningWindow)) {
        return @{
            Name = $Secret.Name
            Status = "warning"
            DaysSinceRotation = $daysSinceRotationValue
            RotationPolicyDays = $Secret.RotationPolicyDays
            DaysUntilExpiry = $Secret.RotationPolicyDays - $daysSinceRotationValue
            RequiredBy = $Secret.RequiredBy
        }
    }
    else {
        return @{
            Name = $Secret.Name
            Status = "ok"
            DaysSinceRotation = $daysSinceRotationValue
            RotationPolicyDays = $Secret.RotationPolicyDays
            DaysUntilExpiry = $Secret.RotationPolicyDays - $daysSinceRotationValue
            RequiredBy = $Secret.RequiredBy
        }
    }
}

<#
.SYNOPSIS
    Validates a collection of secrets against rotation policies.

.PARAMETER Secrets
    Array of hashtables with secret metadata
#>
function Invoke-SecretRotationValidator {
    param(
        [array]$Secrets,

        [int]$WarningWindow = 7,

        [ValidateSet("json", "markdown")]
        [string]$OutputFormat = "markdown"
    )

    if ($null -eq $Secrets -or $Secrets.Count -eq 0) {
        throw "No secrets provided"
    }

    # Process each secret
    $results = @{
        expired = @()
        warning = @()
        ok = @()
    }

    foreach ($secret in $Secrets) {
        $status = Get-SecretStatus -Secret $secret -WarningWindow $WarningWindow
        $results[$status.Status] += $status
    }

    # Format output
    if ($OutputFormat -eq "json") {
        return $results | ConvertTo-Json -Depth 10
    }
    else {
        return Format-SecretRotationReport -Results $results
    }
}

<#
.SYNOPSIS
    Formats secret rotation results as markdown table.
#>
function Format-SecretRotationReport {
    param(
        [hashtable]$Results
    )

    $report = @()

    if ($Results.expired.Count -gt 0) {
        $report += "## Expired Secrets"
        $report += ""
        $report += "| Secret Name | Days Overdue | Required By | Last Rotated |"
        $report += "|---|---|---|---|"
        foreach ($secret in $Results.expired) {
            $lastRotated = (Get-Date).AddDays(-$secret.DaysSinceRotation).ToString("yyyy-MM-dd")
            $requiredByStr = $secret.RequiredBy -join ", "
            $report += "| $($secret.Name) | $($secret.DaysOverdue) | $requiredByStr | $lastRotated |"
        }
        $report += ""
    }

    if ($Results.warning.Count -gt 0) {
        $report += "## Warning - Expiring Soon"
        $report += ""
        $report += "| Secret Name | Days Until Expiry | Required By | Last Rotated |"
        $report += "|---|---|---|---|"
        foreach ($secret in $Results.warning) {
            $lastRotated = (Get-Date).AddDays(-$secret.DaysSinceRotation).ToString("yyyy-MM-dd")
            $requiredByStr = $secret.RequiredBy -join ", "
            $report += "| $($secret.Name) | $($secret.DaysUntilExpiry) | $requiredByStr | $lastRotated |"
        }
        $report += ""
    }

    if ($Results.ok.Count -gt 0) {
        $report += "## Healthy Secrets"
        $report += ""
        $report += "| Secret Name | Days Until Expiry | Required By | Last Rotated |"
        $report += "|---|---|---|---|"
        foreach ($secret in $Results.ok) {
            $lastRotated = (Get-Date).AddDays(-$secret.DaysSinceRotation).ToString("yyyy-MM-dd")
            $requiredByStr = $secret.RequiredBy -join ", "
            $report += "| $($secret.Name) | $($secret.DaysUntilExpiry) | $requiredByStr | $lastRotated |"
        }
        $report += ""
    }

    return $report -join "`n"
}
