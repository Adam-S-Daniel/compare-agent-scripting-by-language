# SecretRotation.psm1
# Pure functions for evaluating secret rotation status.
# Built incrementally via TDD (red/green).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable] $Secret,
        [Parameter(Mandatory)] [datetime] $ReferenceDate,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    foreach ($k in 'name','lastRotated','rotationPolicyDays') {
        if (-not $Secret.ContainsKey($k)) {
            throw "Secret is missing required field: $k"
        }
    }
    if ($Secret.rotationPolicyDays -le 0) {
        throw "Secret '$($Secret.name)': rotationPolicyDays must be > 0"
    }
    if ($WarningDays -lt 0) { throw 'WarningDays must be >= 0' }

    $lastRotated = [datetime]::Parse([string]$Secret.lastRotated, [System.Globalization.CultureInfo]::InvariantCulture)
    $expiresAt   = $lastRotated.AddDays([int]$Secret.rotationPolicyDays)
    $daysLeft    = [int][math]::Floor(($expiresAt - $ReferenceDate).TotalDays)

    $status = if ($daysLeft -lt 0) { 'expired' }
              elseif ($daysLeft -le $WarningDays) { 'warning' }
              else { 'ok' }

    [pscustomobject]@{
        Name              = [string]$Secret.name
        LastRotated       = $lastRotated
        ExpiresAt         = $expiresAt
        DaysUntilExpiry   = $daysLeft
        Status            = $status
        RequiredBy        = @($Secret.requiredBy)
        RotationPolicyDays = [int]$Secret.rotationPolicyDays
    }
}

function Get-SecretRotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Secrets,
        [Parameter(Mandatory)] [datetime] $ReferenceDate,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    # Normalize each secret to a hashtable since JSON parsing yields PSCustomObject.
    $evaluated = foreach ($s in $Secrets) {
        $h = @{}
        foreach ($p in $s.PSObject.Properties) { $h[$p.Name] = $p.Value }
        Get-SecretStatus -Secret $h -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    [pscustomobject]@{
        ReferenceDate = $ReferenceDate
        WarningDays   = $WarningDays
        Expired = @($evaluated | Where-Object { $_.Status -eq 'expired' } | Sort-Object DaysUntilExpiry, Name)
        Warning = @($evaluated | Where-Object { $_.Status -eq 'warning' } | Sort-Object DaysUntilExpiry, Name)
        Ok      = @($evaluated | Where-Object { $_.Status -eq 'ok' }      | Sort-Object DaysUntilExpiry, Name)
        Counts  = [pscustomobject]@{
            Expired = @($evaluated | Where-Object { $_.Status -eq 'expired' }).Count
            Warning = @($evaluated | Where-Object { $_.Status -eq 'warning' }).Count
            Ok      = @($evaluated | Where-Object { $_.Status -eq 'ok' }).Count
            Total   = @($evaluated).Count
        }
    }
}

function Format-SecretRotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject] $Report,
        [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format
    )

    if ($Format -eq 'json') {
        return ($Report | ConvertTo-Json -Depth 6)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Reference date: $($Report.ReferenceDate.ToString('yyyy-MM-dd'))")
    [void]$sb.AppendLine("Warning window: $($Report.WarningDays) days")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Summary: EXPIRED=$($Report.Counts.Expired) WARNING=$($Report.Counts.Warning) OK=$($Report.Counts.Ok) TOTAL=$($Report.Counts.Total)")
    [void]$sb.AppendLine("")

    foreach ($group in 'Expired','Warning','Ok') {
        [void]$sb.AppendLine("## $group")
        [void]$sb.AppendLine("")
        $items = $Report.$group
        if (-not $items -or $items.Count -eq 0) {
            [void]$sb.AppendLine("_None_")
            [void]$sb.AppendLine("")
            continue
        }
        [void]$sb.AppendLine("| Name | Last Rotated | Expires | Days Left | Required By |")
        [void]$sb.AppendLine("|------|--------------|---------|-----------|-------------|")
        foreach ($i in $items) {
            $req = ($i.RequiredBy -join ', ')
            [void]$sb.AppendLine("| $($i.Name) | $($i.LastRotated.ToString('yyyy-MM-dd')) | $($i.ExpiresAt.ToString('yyyy-MM-dd')) | $($i.DaysUntilExpiry) | $req |")
        }
        [void]$sb.AppendLine("")
    }

    return $sb.ToString().TrimEnd()
}

Export-ModuleMember -Function Get-SecretStatus, Get-SecretRotationReport, Format-SecretRotationReport
