#Requires -Version 5.1
# SecretRotationValidator.psm1
# Core module — all business logic lives here so both the script
# and the test file can import it independently.

function Get-SecretStatus {
    <#
    .SYNOPSIS
    Evaluates a single secret against its rotation policy.

    .OUTPUTS
    PSCustomObject with fields: Name, LastRotated, RotationDays, RequiredBy,
    ExpiryDate, DaysUntilExpiry, DaysOverdue, Status (expired|warning|ok).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Secret,

        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate,

        [Parameter(Mandatory = $false)]
        [int]$WarningDays = 30
    )

    $lastRotated    = [datetime]::ParseExact($Secret.lastRotated, "yyyy-MM-dd", $null)
    $expiryDate     = $lastRotated.AddDays($Secret.rotationDays)
    # Negative when expired (expiry is in the past relative to reference date)
    $daysUntilExpiry = [int]($expiryDate - $ReferenceDate).TotalDays

    $status = if ($daysUntilExpiry -lt 0) {
        "expired"
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        "warning"
    }
    else {
        "ok"
    }

    [PSCustomObject]@{
        Name             = $Secret.name
        LastRotated      = $Secret.lastRotated
        RotationDays     = $Secret.rotationDays
        RequiredBy       = $Secret.requiredBy
        ExpiryDate       = $expiryDate.ToString("yyyy-MM-dd")
        DaysUntilExpiry  = $daysUntilExpiry
        # DaysOverdue is 0 for non-expired secrets
        DaysOverdue      = [Math]::Max(0, -$daysUntilExpiry)
        Status           = $status
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
    Builds a report hashtable grouping all secrets by urgency.

    .OUTPUTS
    Hashtable with keys: Expired, Warning, Ok (arrays of secret status objects),
    ReferenceDate (string), WarningDays (int).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Secrets,

        [Parameter(Mandatory = $true)]
        [datetime]$ReferenceDate,

        [Parameter(Mandatory = $false)]
        [int]$WarningDays = 30
    )

    $results = $Secrets | ForEach-Object {
        Get-SecretStatus -Secret $_ -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    @{
        Expired       = @($results | Where-Object { $_.Status -eq "expired" })
        Warning       = @($results | Where-Object { $_.Status -eq "warning" })
        Ok            = @($results | Where-Object { $_.Status -eq "ok" })
        ReferenceDate = $ReferenceDate.ToString("yyyy-MM-dd")
        WarningDays   = $WarningDays
    }
}

function Format-JsonReport {
    <#
    .SYNOPSIS
    Serialises a rotation report hashtable to a JSON string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Report
    )

    $Report | ConvertTo-Json -Depth 10
}

function Format-MarkdownReport {
    <#
    .SYNOPSIS
    Formats a rotation report hashtable as a Markdown document with tables
    grouped by urgency (expired → warning → ok).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Report
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Reference Date**: $($Report.ReferenceDate)")
    [void]$sb.AppendLine("**Warning Window**: $($Report.WarningDays) days")
    [void]$sb.AppendLine("")

    # Summary table
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Status | Count |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Expired | $($Report.Expired.Count) |")
    [void]$sb.AppendLine("| Warning | $($Report.Warning.Count) |")
    [void]$sb.AppendLine("| OK | $($Report.Ok.Count) |")
    [void]$sb.AppendLine("")

    if ($Report.Expired.Count -gt 0) {
        [void]$sb.AppendLine("## Expired Secrets (ACTION REQUIRED)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Overdue | Required By |")
        [void]$sb.AppendLine("|------|-------------|-------------|--------------|-------------|")
        foreach ($s in $Report.Expired) {
            [void]$sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysOverdue) | $($s.RequiredBy -join ', ') |")
        }
        [void]$sb.AppendLine("")
    }

    if ($Report.Warning.Count -gt 0) {
        [void]$sb.AppendLine("## Expiring Soon (Warning)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |")
        [void]$sb.AppendLine("|------|-------------|-------------|-------------------|-------------|")
        foreach ($s in $Report.Warning) {
            [void]$sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $($s.RequiredBy -join ', ') |")
        }
        [void]$sb.AppendLine("")
    }

    if ($Report.Ok.Count -gt 0) {
        [void]$sb.AppendLine("## Current Secrets (OK)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Last Rotated | Expiry Date | Days Until Expiry | Required By |")
        [void]$sb.AppendLine("|------|-------------|-------------|-------------------|-------------|")
        foreach ($s in $Report.Ok) {
            [void]$sb.AppendLine("| $($s.Name) | $($s.LastRotated) | $($s.ExpiryDate) | $($s.DaysUntilExpiry) | $($s.RequiredBy -join ', ') |")
        }
        [void]$sb.AppendLine("")
    }

    $sb.ToString()
}

Export-ModuleMember -Function Get-SecretStatus, Get-RotationReport, Format-JsonReport, Format-MarkdownReport
