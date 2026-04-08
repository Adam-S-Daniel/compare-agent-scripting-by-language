Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Secret Rotation Validator
# Evaluates secrets against their rotation policies and classifies urgency.

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Determines the rotation status of a single secret.
    .DESCRIPTION
        Compares a secret's last-rotated date + policy to a reference date,
        returning Expired / Warning / OK with days remaining or overdue.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Secret,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate,

        [Parameter(Mandatory)]
        [int]$WarningDays
    )

    # Validate required fields
    if (-not $Secret.ContainsKey('Name') -or [string]::IsNullOrWhiteSpace([string]$Secret.Name)) {
        throw "Secret is missing required field 'Name'."
    }
    if (-not $Secret.ContainsKey('LastRotated')) {
        throw "Secret '$($Secret.Name)' is missing required field 'LastRotated'."
    }
    if (-not $Secret.ContainsKey('PolicyDays') -or [int]$Secret.PolicyDays -le 0) {
        throw "Secret '$($Secret.Name)' has invalid 'PolicyDays': must be a positive integer."
    }

    [datetime]$lastRotated = [datetime]$Secret.LastRotated
    [int]$policyDays = [int]$Secret.PolicyDays
    [datetime]$expiryDate = $lastRotated.AddDays($policyDays)
    [int]$daysUntilExpiry = [int]($expiryDate - $ReferenceDate).Days

    if ($daysUntilExpiry -lt 0) {
        # Already expired
        return @{
            Name            = [string]$Secret.Name
            LastRotated     = $lastRotated
            ExpiryDate      = $expiryDate
            PolicyDays      = $policyDays
            RequiredBy      = [string[]]$Secret.RequiredBy
            Urgency         = [string]'Expired'
            DaysOverdue     = [int]([Math]::Abs($daysUntilExpiry))
            DaysUntilExpiry = [int]0
        }
    }
    elseif ($daysUntilExpiry -le $WarningDays) {
        # Within warning window
        return @{
            Name            = [string]$Secret.Name
            LastRotated     = $lastRotated
            ExpiryDate      = $expiryDate
            PolicyDays      = $policyDays
            RequiredBy      = [string[]]$Secret.RequiredBy
            Urgency         = [string]'Warning'
            DaysOverdue     = [int]0
            DaysUntilExpiry = [int]$daysUntilExpiry
        }
    }
    else {
        # OK
        return @{
            Name            = [string]$Secret.Name
            LastRotated     = $lastRotated
            ExpiryDate      = $expiryDate
            PolicyDays      = $policyDays
            RequiredBy      = [string[]]$Secret.RequiredBy
            Urgency         = [string]'OK'
            DaysOverdue     = [int]0
            DaysUntilExpiry = [int]$daysUntilExpiry
        }
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
        Evaluates all secrets and produces a report grouped by urgency.
    .DESCRIPTION
        Iterates over an array of secret hashtables, classifies each one,
        and returns a report with Expired/Warning/OK groups plus a summary.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$Secrets,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate,

        [Parameter()]
        [int]$WarningDays = 7
    )

    [System.Collections.ArrayList]$expired = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$warning = [System.Collections.ArrayList]::new()
    [System.Collections.ArrayList]$ok      = [System.Collections.ArrayList]::new()

    foreach ($secret in $Secrets) {
        [hashtable]$status = Get-SecretStatus -Secret $secret -ReferenceDate $ReferenceDate -WarningDays $WarningDays
        switch ($status.Urgency) {
            'Expired' { [void]$expired.Add($status) }
            'Warning' { [void]$warning.Add($status) }
            'OK'      { [void]$ok.Add($status) }
        }
    }

    return @{
        Expired = [hashtable[]]$expired.ToArray()
        Warning = [hashtable[]]$warning.ToArray()
        OK      = [hashtable[]]$ok.ToArray()
        Summary = @{
            TotalSecrets = [int]$Secrets.Count
            ExpiredCount = [int]$expired.Count
            WarningCount = [int]$warning.Count
            OKCount      = [int]$ok.Count
            ReportDate   = $ReferenceDate
        }
    }
}

# --- Output Formatters ---

function ConvertTo-MarkdownReport {
    <#
    .SYNOPSIS
        Formats a rotation report as a Markdown document with tables.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    # Title and summary
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- **Report Date:** $($Report.Summary.ReportDate.ToString('yyyy-MM-dd'))")
    [void]$sb.AppendLine("- **Total Secrets:** $($Report.Summary.TotalSecrets)")
    [void]$sb.AppendLine("- **Expired:** $($Report.Summary.ExpiredCount)")
    [void]$sb.AppendLine("- **Warning:** $($Report.Summary.WarningCount)")
    [void]$sb.AppendLine("- **OK:** $($Report.Summary.OKCount)")
    [void]$sb.AppendLine("")

    # Helper: emit a table for a group of secrets
    [scriptblock]$writeSection = {
        param([string]$Title, [hashtable[]]$Items)
        [void]$sb.AppendLine("## $Title")
        [void]$sb.AppendLine("")
        if ($Items.Count -eq 0) {
            [void]$sb.AppendLine("_None_")
            [void]$sb.AppendLine("")
            return
        }
        [void]$sb.AppendLine("| Name | Urgency | Last Rotated | Expiry Date | Policy (days) | Days Overdue | Days Until Expiry | Required By |")
        [void]$sb.AppendLine("|------|---------|--------------|-------------|---------------|--------------|-------------------|-------------|")
        foreach ($item in $Items) {
            [string]$services = ($item.RequiredBy -join ', ')
            [string]$row = "| $($item.Name) | $($item.Urgency) | $($item.LastRotated.ToString('yyyy-MM-dd')) | $($item.ExpiryDate.ToString('yyyy-MM-dd')) | $($item.PolicyDays) | $($item.DaysOverdue) | $($item.DaysUntilExpiry) | $services |"
            [void]$sb.AppendLine($row)
        }
        [void]$sb.AppendLine("")
    }

    & $writeSection 'EXPIRED' ([hashtable[]]$Report.Expired)
    & $writeSection 'WARNING' ([hashtable[]]$Report.Warning)
    & $writeSection 'OK'      ([hashtable[]]$Report.OK)

    return $sb.ToString()
}

function ConvertTo-JsonReport {
    <#
    .SYNOPSIS
        Formats a rotation report as JSON.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report
    )

    # Build a serializable structure with ordered keys
    [hashtable]$output = @{
        summary = @{
            ReportDate   = $Report.Summary.ReportDate.ToString('yyyy-MM-dd')
            TotalSecrets = [int]$Report.Summary.TotalSecrets
            ExpiredCount = [int]$Report.Summary.ExpiredCount
            WarningCount = [int]$Report.Summary.WarningCount
            OKCount      = [int]$Report.Summary.OKCount
        }
        expired = @(foreach ($s in $Report.Expired) {
            @{
                Name            = [string]$s.Name
                Urgency         = [string]$s.Urgency
                LastRotated     = $s.LastRotated.ToString('yyyy-MM-dd')
                ExpiryDate      = $s.ExpiryDate.ToString('yyyy-MM-dd')
                PolicyDays      = [int]$s.PolicyDays
                DaysOverdue     = [int]$s.DaysOverdue
                DaysUntilExpiry = [int]$s.DaysUntilExpiry
                RequiredBy      = [string[]]$s.RequiredBy
            }
        })
        warning = @(foreach ($s in $Report.Warning) {
            @{
                Name            = [string]$s.Name
                Urgency         = [string]$s.Urgency
                LastRotated     = $s.LastRotated.ToString('yyyy-MM-dd')
                ExpiryDate      = $s.ExpiryDate.ToString('yyyy-MM-dd')
                PolicyDays      = [int]$s.PolicyDays
                DaysOverdue     = [int]$s.DaysOverdue
                DaysUntilExpiry = [int]$s.DaysUntilExpiry
                RequiredBy      = [string[]]$s.RequiredBy
            }
        })
        ok = @(foreach ($s in $Report.OK) {
            @{
                Name            = [string]$s.Name
                Urgency         = [string]$s.Urgency
                LastRotated     = $s.LastRotated.ToString('yyyy-MM-dd')
                ExpiryDate      = $s.ExpiryDate.ToString('yyyy-MM-dd')
                PolicyDays      = [int]$s.PolicyDays
                DaysOverdue     = [int]$s.DaysOverdue
                DaysUntilExpiry = [int]$s.DaysUntilExpiry
                RequiredBy      = [string[]]$s.RequiredBy
            }
        })
    }

    return ($output | ConvertTo-Json -Depth 5)
}
