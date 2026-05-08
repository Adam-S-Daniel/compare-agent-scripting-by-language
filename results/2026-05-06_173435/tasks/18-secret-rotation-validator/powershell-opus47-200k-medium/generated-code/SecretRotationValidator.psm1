# SecretRotationValidator.psm1
#
# Pure functions for validating secret rotation status. Three layers:
#   Get-SecretStatus           -> classifies one secret as ok/warning/expired
#   Get-SecretRotationReport   -> groups + sorts a list of secrets into buckets
#   Format-SecretRotationReport-> renders a report as markdown or JSON
#
# All time math goes through an injected -Today parameter so the same
# fixtures produce the same output regardless of when the tests run.

Set-StrictMode -Version Latest

function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]   $Secret,
        [Parameter(Mandatory)] [datetime] $Today,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    # Validate required fields up front with messages that name the field,
    # so misconfigured fixtures fail loudly rather than producing junk dates.
    $name = if ($Secret.PSObject.Properties['name']) { [string]$Secret.name } else { '<unnamed>' }

    if (-not $Secret.PSObject.Properties['lastRotated'] -or [string]::IsNullOrWhiteSpace($Secret.lastRotated)) {
        throw "Secret '$name' is missing required field 'lastRotated'."
    }
    if (-not $Secret.PSObject.Properties['rotationDays']) {
        throw "Secret '$name' is missing required field 'rotationDays'."
    }
    $rotationDays = [int]$Secret.rotationDays
    if ($rotationDays -le 0) {
        throw "Secret '$name' has invalid rotationDays '$rotationDays' (must be > 0)."
    }

    $lastRotated = $null
    try   { $lastRotated = [datetime]::Parse([string]$Secret.lastRotated, [System.Globalization.CultureInfo]::InvariantCulture) }
    catch { throw "Secret '$name' has unparseable lastRotated '$($Secret.lastRotated)'." }

    $age           = [int]([math]::Floor(($Today - $lastRotated).TotalDays))
    $dueDate       = $lastRotated.AddDays($rotationDays)
    $daysUntilDue  = [int]([math]::Floor(($dueDate - $Today).TotalDays))
    $daysOverdue   = -$daysUntilDue   # positive when expired, negative when ok

    $status =
        if ($daysOverdue -gt 0)               { 'expired' }
        elseif ($daysUntilDue -le $WarningDays){ 'warning' }
        else                                   { 'ok' }

    $requiredBy = @()
    if ($Secret.PSObject.Properties['requiredBy'] -and $null -ne $Secret.requiredBy) {
        $requiredBy = @($Secret.requiredBy)
    }

    [pscustomobject]@{
        name         = $name
        lastRotated  = $lastRotated.ToString('yyyy-MM-dd')
        rotationDays = $rotationDays
        ageDays      = $age
        daysOverdue  = $daysOverdue
        status       = $status
        requiredBy   = $requiredBy
    }
}

function Get-SecretRotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Secrets,
        [Parameter(Mandatory)] [datetime] $Today,
        [Parameter(Mandatory)] [int]      $WarningDays
    )

    $classified = foreach ($s in $Secrets) { Get-SecretStatus -Secret $s -Today $Today -WarningDays $WarningDays }

    # Group, then sort each bucket so the most-urgent entries come first.
    $expired = @($classified | Where-Object status -eq 'expired' | Sort-Object -Property daysOverdue -Descending)
    $warning = @($classified | Where-Object status -eq 'warning' | Sort-Object -Property daysOverdue -Descending)
    $ok      = @($classified | Where-Object status -eq 'ok'      | Sort-Object -Property daysOverdue -Descending)

    [pscustomobject]@{
        generatedAt = $Today.ToString('yyyy-MM-dd')
        warningDays = $WarningDays
        summary     = [pscustomobject]@{
            total   = @($classified).Count
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
        }
        expired = $expired
        warning = $warning
        ok      = $ok
    }
}

function Format-SecretRotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report,
        [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format
    )

    switch ($Format) {
        'json'     { return ($Report | ConvertTo-Json -Depth 6) }
        'markdown' { return (Format-MarkdownReport -Report $Report) }
        default    { throw "Unsupported Format '$Format'." }   # ValidateSet already guards, kept for safety
    }
}

function Format-MarkdownReport {
    param([Parameter(Mandatory)][object] $Report)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- Generated: $($Report.generatedAt)")
    [void]$sb.AppendLine("- Warning window: $($Report.warningDays) day(s)")
    [void]$sb.AppendLine("- Total: $($Report.summary.total)  (expired: $($Report.summary.expired), warning: $($Report.summary.warning), ok: $($Report.summary.ok))")
    [void]$sb.AppendLine("")

    foreach ($section in @(
            @{ Title='Expired'; Items=$Report.expired },
            @{ Title='Warning'; Items=$Report.warning },
            @{ Title='OK';      Items=$Report.ok      })) {
        [void]$sb.AppendLine("## $($section.Title) ($($section.Items.Count))")
        [void]$sb.AppendLine("")
        if ($section.Items.Count -eq 0) {
            [void]$sb.AppendLine("_None._")
        } else {
            [void]$sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Overdue | Required By |")
            [void]$sb.AppendLine("|------|--------------|---------------|--------------|-------------|")
            foreach ($it in $section.Items) {
                $req = ($it.requiredBy -join ', ')
                [void]$sb.AppendLine("| $($it.name) | $($it.lastRotated) | $($it.rotationDays) | $($it.daysOverdue) | $req |")
            }
        }
        [void]$sb.AppendLine("")
    }
    return $sb.ToString().TrimEnd()
}

Export-ModuleMember -Function Get-SecretStatus, Get-SecretRotationReport, Format-SecretRotationReport
