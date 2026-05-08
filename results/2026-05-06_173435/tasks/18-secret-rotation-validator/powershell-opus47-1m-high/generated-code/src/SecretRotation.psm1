# SecretRotation.psm1
#
# Core logic for the secret rotation validator. Pure functions that take
# already-loaded data and emit classified results. The script entrypoint
# (Invoke-SecretRotationValidator.ps1) wires these together with file I/O
# and exit codes.
#
# A "secret" is a hashtable / object with the fields:
#   Name         - string, identifier
#   LastRotated  - ISO-8601 date string
#   RotationDays - positive int, max age before expiry
#   RequiredBy   - array of service names that depend on it
#
# The classification rules for a secret evaluated at AsOf with WarningDays:
#   DaysUntilDue  = (LastRotated + RotationDays) - AsOf
#   DaysUntilDue <  0  => 'expired' (DaysOverdue = -DaysUntilDue)
#   DaysUntilDue <= WarningDays => 'warning'
#   else                        => 'ok'

Set-StrictMode -Version 3.0

function Get-SecretRotationStatus {
    <#
    .SYNOPSIS
    Classify a single secret as expired, warning or ok relative to AsOf.

    .DESCRIPTION
    Returns a [pscustomobject] with the original metadata plus Status,
    DaysUntilDue, DueDate and DaysOverdue.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]   $Secret,
        [Parameter(Mandatory)] [datetime] $AsOf,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    if ($null -eq $Secret.RotationDays -or $Secret.RotationDays -le 0) {
        throw "RotationDays must be a positive integer for secret '$($Secret.Name)'."
    }

    $lastRotated = $null
    try {
        # Force ISO/Round-trip parsing so locale doesn't change semantics.
        $lastRotated = [datetime]::Parse(
            [string]$Secret.LastRotated,
            [System.Globalization.CultureInfo]::InvariantCulture)
    }
    catch {
        throw "Invalid LastRotated value for secret '$($Secret.Name)': '$($Secret.LastRotated)'."
    }

    $dueDate      = $lastRotated.AddDays([int]$Secret.RotationDays)
    $daysUntilDue = [int]([math]::Floor(($dueDate.Date - $AsOf.Date).TotalDays))

    $status = if ($daysUntilDue -lt 0) {
        'expired'
    } elseif ($daysUntilDue -le $WarningDays) {
        'warning'
    } else {
        'ok'
    }

    [pscustomobject]@{
        Name         = [string]$Secret.Name
        LastRotated  = $lastRotated.ToString('yyyy-MM-dd')
        RotationDays = [int]$Secret.RotationDays
        RequiredBy   = @($Secret.RequiredBy)
        DueDate      = $dueDate.ToString('yyyy-MM-dd')
        DaysUntilDue = $daysUntilDue
        DaysOverdue  = [Math]::Max(0, -$daysUntilDue)
        Status       = $status
    }
}

function Invoke-SecretRotationReport {
    <#
    .SYNOPSIS
    Classify a list of secrets and bucket them by urgency.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Secrets,
        [Parameter(Mandatory)] [datetime] $AsOf,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    $classified = foreach ($s in $Secrets) {
        Get-SecretRotationStatus -Secret $s -AsOf $AsOf -WarningDays $WarningDays
    }

    # Sort: expired by most overdue first, warning by soonest due, ok by soonest due.
    $expired = @($classified | Where-Object Status -EQ 'expired' | Sort-Object DaysUntilDue)
    $warning = @($classified | Where-Object Status -EQ 'warning' | Sort-Object DaysUntilDue)
    $ok      = @($classified | Where-Object Status -EQ 'ok'      | Sort-Object DaysUntilDue)

    [pscustomobject]@{
        AsOf        = $AsOf.ToString('yyyy-MM-dd')
        WarningDays = $WarningDays
        Expired     = $expired
        Warning     = $warning
        Ok          = $ok
        Summary     = [pscustomobject]@{
            Total   = $classified.Count
            Expired = $expired.Count
            Warning = $warning.Count
            Ok      = $ok.Count
        }
    }
}

function Format-SecretRotationReport {
    <#
    .SYNOPSIS
    Render a report object in markdown or json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]   $Report,
        [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format
    )

    switch ($Format) {
        'markdown' { return _Format-Markdown -Report $Report }
        'json'     { return _Format-Json     -Report $Report }
        default    { throw "Unsupported format '$Format'." }
    }
}

function _Format-Markdown {
    param([object] $Report)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("As of: $($Report.AsOf) (warning window: $($Report.WarningDays) days)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine(("Summary -- Total: {0}, Expired: {1}, Warning: {2}, Ok: {3}" -f
        $Report.Summary.Total, $Report.Summary.Expired,
        $Report.Summary.Warning, $Report.Summary.Ok))
    [void]$sb.AppendLine("")

    foreach ($section in @(
        @{ Title = 'Expired'; Rows = $Report.Expired },
        @{ Title = 'Warning'; Rows = $Report.Warning },
        @{ Title = 'Ok';      Rows = $Report.Ok      }
    )) {
        [void]$sb.AppendLine("## $($section.Title)")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Due | Required By |")
        [void]$sb.AppendLine("|------|--------------|---------------|----------------|-------------|")
        if ($section.Rows.Count -eq 0) {
            [void]$sb.AppendLine("| _(none)_ | | | | |")
        } else {
            foreach ($r in $section.Rows) {
                [void]$sb.AppendLine(("| {0} | {1} | {2} | {3} | {4} |" -f
                    $r.Name, $r.LastRotated, $r.RotationDays,
                    $r.DaysUntilDue, ($r.RequiredBy -join ', ')))
            }
        }
        [void]$sb.AppendLine("")
    }
    return $sb.ToString().TrimEnd()
}

function _Format-Json {
    param([object] $Report)

    $payload = [ordered]@{
        as_of        = $Report.AsOf
        warning_days = $Report.WarningDays
        summary = [ordered]@{
            total   = $Report.Summary.Total
            expired = $Report.Summary.Expired
            warning = $Report.Summary.Warning
            ok      = $Report.Summary.Ok
        }
        expired = @($Report.Expired | ForEach-Object { _ToLowerKeyed $_ })
        warning = @($Report.Warning | ForEach-Object { _ToLowerKeyed $_ })
        ok      = @($Report.Ok      | ForEach-Object { _ToLowerKeyed $_ })
    }
    return ($payload | ConvertTo-Json -Depth 6)
}

function _ToLowerKeyed {
    param([object] $Item)
    [ordered]@{
        name           = $Item.Name
        last_rotated   = $Item.LastRotated
        rotation_days  = $Item.RotationDays
        due_date       = $Item.DueDate
        days_until_due = $Item.DaysUntilDue
        days_overdue   = $Item.DaysOverdue
        status         = $Item.Status
        required_by    = @($Item.RequiredBy)
    }
}

function Read-SecretConfig {
    <#
    .SYNOPSIS
    Load a JSON file containing an array of secret configurations.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Secret configuration file not found: '$Path'."
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JSON from '$Path': $($_.Exception.Message)."
    }

    # Always return an array, even for a single-item config.
    return @($parsed)
}

Export-ModuleMember -Function `
    Get-SecretRotationStatus,
    Invoke-SecretRotationReport,
    Format-SecretRotationReport,
    Read-SecretConfig
