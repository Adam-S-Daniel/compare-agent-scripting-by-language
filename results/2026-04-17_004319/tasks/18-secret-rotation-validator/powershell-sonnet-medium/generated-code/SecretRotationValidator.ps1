# Secret Rotation Validator
# Identifies expired/expiring secrets and generates rotation reports
# Run directly: pwsh -File SecretRotationValidator.ps1 [-Format markdown|json] [-WarningDays 14]
# Dot-source for functions: . ./SecretRotationValidator.ps1

param(
    [string] $Format      = "markdown",
    [int]    $WarningDays = 14,
    [string] $OutputFile  = ""
)

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Determines the rotation status of a single secret.
    .PARAMETER Secret
        Hashtable with Name, LastRotated (datetime), RotationDays (int), RequiredBy (array).
    .PARAMETER ReferenceDate
        The date to compare against (defaults to today). Injected for testability.
    .PARAMETER WarningDays
        Number of days before expiry to trigger a "warning" status.
    #>
    param(
        [Parameter(Mandatory)] [hashtable] $Secret,
        [datetime] $ReferenceDate = (Get-Date),
        [int]      $WarningDays   = 14
    )

    $expiryDate      = $Secret.LastRotated.AddDays($Secret.RotationDays)
    $daysUntilExpiry = [int][math]::Floor(($expiryDate - $ReferenceDate).TotalDays)

    $status = if ($daysUntilExpiry -lt 0) {
        "expired"
    } elseif ($daysUntilExpiry -le $WarningDays) {
        "warning"
    } else {
        "ok"
    }

    return [PSCustomObject]@{
        Name            = $Secret.Name
        LastRotated     = $Secret.LastRotated
        ExpiryDate      = $expiryDate
        DaysUntilExpiry = $daysUntilExpiry
        RotationDays    = $Secret.RotationDays
        RequiredBy      = $Secret.RequiredBy
        Status          = $status
    }
}

function Invoke-SecretRotationReport {
    <#
    .SYNOPSIS
        Processes a list of secrets and groups them by urgency.
    .PARAMETER Secrets
        Array of secret hashtables.
    .PARAMETER ReferenceDate
        Date to use as "today".
    .PARAMETER WarningDays
        Days before expiry to warn.
    #>
    param(
        [Parameter(Mandatory)] [array] $Secrets,
        [datetime] $ReferenceDate = (Get-Date),
        [int]      $WarningDays   = 14
    )

    $statuses = $Secrets | ForEach-Object {
        Get-SecretStatus -Secret $_ -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    return [PSCustomObject]@{
        GeneratedAt = $ReferenceDate
        WarningDays = $WarningDays
        Expired     = @($statuses | Where-Object { $_.Status -eq "expired" })
        Warning     = @($statuses | Where-Object { $_.Status -eq "warning" })
        Ok          = @($statuses | Where-Object { $_.Status -eq "ok" })
    }
}

function Format-RotationReport {
    <#
    .SYNOPSIS
        Formats a rotation report as markdown or JSON.
    .PARAMETER Report
        PSCustomObject from Invoke-SecretRotationReport.
    .PARAMETER Format
        "markdown" or "json".
    #>
    param(
        [Parameter(Mandatory)] $Report,
        [string] $Format = "markdown"
    )

    if ($Format -eq "json") {
        return _Format-Json $Report
    } elseif ($Format -eq "markdown") {
        return _Format-Markdown $Report
    } else {
        throw "Unsupported format: $Format. Use 'markdown' or 'json'."
    }
}

function _Format-Markdown {
    param($Report)

    $tableHeader = "| Name | Status | Days Until Expiry | Expiry Date | Required By |`n| --- | --- | --- | --- | --- |"

    function Get-TableRows($items) {
        if (-not $items -or $items.Count -eq 0) {
            return "| *(none)* | | | | |"
        }
        ($items | ForEach-Object {
            $requiredBy = if ($_.RequiredBy) { $_.RequiredBy -join ", " } else { "" }
            "| $($_.Name) | $($_.Status) | $($_.DaysUntilExpiry) | $($_.ExpiryDate.ToString('yyyy-MM-dd')) | $requiredBy |"
        }) -join "`n"
    }

    $lines = @(
        "# Secret Rotation Report",
        "",
        "Generated: $($Report.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))",
        "Warning window: $($Report.WarningDays) days",
        "",
        "## Expired",
        "",
        $tableHeader,
        (Get-TableRows $Report.Expired),
        "",
        "## Warning",
        "",
        $tableHeader,
        (Get-TableRows $Report.Warning),
        "",
        "## Ok",
        "",
        $tableHeader,
        (Get-TableRows $Report.Ok)
    )

    return $lines -join "`n"
}

function _Format-Json {
    param($Report)

    $toObj = {
        param($item)
        @{
            name            = $item.Name
            status          = $item.Status
            lastRotated     = $item.LastRotated.ToString("yyyy-MM-dd")
            expiryDate      = $item.ExpiryDate.ToString("yyyy-MM-dd")
            daysUntilExpiry = $item.DaysUntilExpiry
            rotationDays    = $item.RotationDays
            requiredBy      = $item.RequiredBy
        }
    }

    $obj = @{
        generatedAt = $Report.GeneratedAt.ToString("yyyy-MM-dd HH:mm:ss")
        warningDays = $Report.WarningDays
        expired     = @($Report.Expired | ForEach-Object { & $toObj $_ })
        warning     = @($Report.Warning | ForEach-Object { & $toObj $_ })
        ok          = @($Report.Ok      | ForEach-Object { & $toObj $_ })
    }

    return $obj | ConvertTo-Json -Depth 5
}

function Get-DefaultSecrets {
    <#
    .SYNOPSIS
        Returns a set of mock secrets for demonstration / CI fixture use.
    #>
    $today = Get-Date

    return @(
        @{ Name = "DB_PASSWORD";         LastRotated = $today.AddDays(-95);  RotationDays = 90;  RequiredBy = @("api-service", "worker") },
        @{ Name = "API_KEY_STRIPE";      LastRotated = $today.AddDays(-82);  RotationDays = 90;  RequiredBy = @("billing") },
        @{ Name = "JWT_SECRET";          LastRotated = $today.AddDays(-10);  RotationDays = 90;  RequiredBy = @("auth-service") },
        @{ Name = "OAUTH_CLIENT_SECRET"; LastRotated = $today.AddDays(-45);  RotationDays = 180; RequiredBy = @("sso") },
        @{ Name = "SMTP_PASSWORD";       LastRotated = $today.AddDays(-200); RotationDays = 180; RequiredBy = @("mailer") },
        @{ Name = "WEBHOOK_SECRET";      LastRotated = $today.AddDays(-5);   RotationDays = 365; RequiredBy = @("github-integration") },
        @{ Name = "ENCRYPTION_KEY";      LastRotated = $today.AddDays(-350); RotationDays = 365; RequiredBy = @("data-service") }
    )
}

# Run as script (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.CommandOrigin -eq 'Runspace') {
    $secrets = Get-DefaultSecrets
    $report  = Invoke-SecretRotationReport -Secrets $secrets -WarningDays $WarningDays
    $output  = Format-RotationReport -Report $report -Format $Format

    if ($OutputFile) {
        $output | Set-Content -Path $OutputFile -Encoding UTF8
        Write-Host "Report written to $OutputFile"
    } else {
        Write-Output $output
    }
}
