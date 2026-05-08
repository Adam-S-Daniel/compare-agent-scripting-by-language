# SecretRotationValidator: Identify and report on secrets nearing rotation deadlines
# Uses Red/Green TDD approach to validate secret metadata and generate urgency-grouped reports

function Parse-SecretConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigJson
    )

    try {
        $config = $ConfigJson | ConvertFrom-Json -ErrorAction Stop
        return $config
    }
    catch {
        throw "Failed to parse configuration JSON: $_"
    }
}

function Test-SecretExpiration {
    param(
        [Parameter(Mandatory = $true)]
        $Secret,
        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate
    )

    $lastRotatedDate = [datetime]::Parse($Secret.lastRotated)
    $expirationDate = $lastRotatedDate.AddDays($Secret.rotationPolicyDays)
    return $ReferenceDate -ge $expirationDate
}

function Test-SecretWarning {
    param(
        [Parameter(Mandatory = $true)]
        $Secret,
        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate,
        [Parameter(Mandatory = $true)]
        [int]$WarningDays
    )

    $lastRotatedDate = [datetime]::Parse($Secret.lastRotated)
    $expirationDate = $lastRotatedDate.AddDays($Secret.rotationPolicyDays)
    $warningStartDate = $expirationDate.AddDays(-$WarningDays)

    return ($ReferenceDate -ge $warningStartDate -and $ReferenceDate -lt $expirationDate)
}

function Get-RotationStatus {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Secrets,
        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate,
        [int]$WarningDays = 7
    )

    $statuses = @()

    foreach ($secret in $Secrets) {
        $lastRotatedDate = [datetime]::Parse($secret.lastRotated)
        $expirationDate = $lastRotatedDate.AddDays($secret.rotationPolicyDays)
        $daysUntilRotation = ($expirationDate - $ReferenceDate).Days

        $status = if (Test-SecretExpiration -Secret $secret -ReferenceDate $ReferenceDate) {
            "expired"
        }
        elseif (Test-SecretWarning -Secret $secret -ReferenceDate $ReferenceDate -WarningDays $WarningDays) {
            "warning"
        }
        else {
            "ok"
        }

        $statusObj = [PSCustomObject]@{
            name                 = $secret.name
            status               = $status
            daysUntilRotation    = $daysUntilRotation
            requiredByServices   = $secret.requiredByServices
            lastRotated          = $secret.lastRotated
            rotationPolicyDays   = $secret.rotationPolicyDays
        }
        $statuses += $statusObj
    }

    return @($statuses)
}

function Format-RotationReport {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Statuses = @(),
        [ValidateSet("markdown", "json")]
        [string]$Format = "markdown"
    )

    if ($Format -eq "json") {
        return $Statuses | ConvertTo-Json
    }
    else {
        # Markdown table format
        $markdown = @"
# Secret Rotation Report

| Secret Name | Status | Days Until Rotation | Services |
|---|---|---|---|
"@

        foreach ($status in $Statuses) {
            $services = if ($status.requiredByServices) {
                $status.requiredByServices -join ", "
            }
            else {
                "N/A"
            }
            $markdown += "`n| $($status.name) | $($status.status) | $($status.daysUntilRotation) | $services |"
        }

        return $markdown
    }
}

function Invoke-SecretRotationValidator {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigJson,
        [datetime]$ReferenceDate = (Get-Date),
        [ValidateSet("markdown", "json")]
        [string]$Format = "markdown",
        [int]$WarningDays = 7
    )

    # Parse configuration
    $secrets = Parse-SecretConfig -ConfigJson $ConfigJson

    # Handle empty or null secrets
    if ($null -eq $secrets) {
        $secrets = @()
    }
    elseif ($secrets -isnot [array]) {
        $secrets = @($secrets)
    }

    # Get rotation statuses
    $statuses = @()
    if ($secrets.Count -gt 0) {
        $statuses = Get-RotationStatus -Secrets $secrets -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    # Generate report
    $report = Format-RotationReport -Statuses $statuses -Format $Format

    return $report
}
