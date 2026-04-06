# SecretRotationValidator.psm1
# Secret Rotation Validator — PowerShell strict-mode module
#
# Provides functions to:
#   - Evaluate individual secret rotation status (expired / warning / ok)
#   - Aggregate a collection of secrets into a grouped report
#   - Format the report as a Markdown table or JSON

Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Calculates the rotation status of a single secret.

.DESCRIPTION
    Compares the secret's last-rotated date plus rotation policy against a
    reference date to determine whether the secret is:
      - expired  : past its rotation deadline
      - warning  : within the configurable warning window
      - ok       : comfortably ahead of its deadline

.PARAMETER Secret
    PSCustomObject with properties:
        Name         [string]   — identifier
        LastRotated  [datetime] — date the secret was last rotated
        RotationDays [int]      — rotation policy in days
        RequiredBy   [string[]] — services that depend on this secret

.PARAMETER WarningDays
    Number of days before expiry at which to issue a warning.

.PARAMETER ReferenceDate
    The date to treat as "today". Defaults to [datetime]::Today.
    Inject a fixed date in tests to make assertions deterministic.

.OUTPUTS
    PSCustomObject with:
        Name            [string]   — secret name
        LastRotated     [datetime] — last rotation date
        RotationDays    [int]      — policy in days
        ExpiryDate      [datetime] — computed expiry date
        DaysUntilExpiry [int]      — days remaining (negative = overdue)
        Status          [string]   — 'expired' | 'warning' | 'ok'
        RequiredBy      [string[]] — dependent services
#>
function Get-SecretStatus {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Secret,

        [Parameter(Mandatory)]
        [int]$WarningDays,

        [Parameter()]
        [datetime]$ReferenceDate = [datetime]::Today
    )

    # Compute absolute expiry date
    [datetime]$expiryDate = ([datetime]$Secret.LastRotated).AddDays([int]$Secret.RotationDays)

    # Floor to whole days so tests that inject a date aren't affected by time-of-day
    [int]$daysUntilExpiry = [int][Math]::Floor(($expiryDate - $ReferenceDate).TotalDays)

    # Classify urgency
    [string]$status = if ($daysUntilExpiry -lt 0) {
        'expired'
    } elseif ($daysUntilExpiry -le $WarningDays) {
        'warning'
    } else {
        'ok'
    }

    # Normalize RequiredBy to string[] to satisfy strict mode
    [string[]]$requiredBy = [string[]]@($Secret.RequiredBy | ForEach-Object { [string]$_ })

    return [PSCustomObject]@{
        Name            = [string]$Secret.Name
        LastRotated     = [datetime]$Secret.LastRotated
        RotationDays    = [int]$Secret.RotationDays
        ExpiryDate      = $expiryDate
        DaysUntilExpiry = $daysUntilExpiry
        Status          = $status
        RequiredBy      = $requiredBy
    }
}

<#
.SYNOPSIS
    Generates a grouped rotation report for a collection of secrets.

.DESCRIPTION
    Runs each secret through Get-SecretStatus then partitions results into
    three urgency buckets: Expired, Warning, Ok.

.PARAMETER Secrets
    Array of secret configuration PSCustomObjects.

.PARAMETER WarningDays
    Number of days before expiry to issue a warning.

.PARAMETER ReferenceDate
    Reference date for calculations (injectable for testing).

.OUTPUTS
    Hashtable with keys:
        Expired     [PSCustomObject[]] — secrets past their deadline
        Warning     [PSCustomObject[]] — secrets within the warning window
        Ok          [PSCustomObject[]] — secrets with ample time remaining
        GeneratedAt [datetime]         — when the report was created
        WarningDays [int]              — the window setting used
#>
function Get-RotationReport {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Secrets,

        [Parameter(Mandatory)]
        [int]$WarningDays,

        [Parameter()]
        [datetime]$ReferenceDate = [datetime]::Today
    )

    # Typed generic lists allow us to accumulate results without losing type info
    [System.Collections.Generic.List[PSCustomObject]]$expiredList = `
        [System.Collections.Generic.List[PSCustomObject]]::new()
    [System.Collections.Generic.List[PSCustomObject]]$warningList = `
        [System.Collections.Generic.List[PSCustomObject]]::new()
    [System.Collections.Generic.List[PSCustomObject]]$okList = `
        [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($secret in $Secrets) {
        [PSCustomObject]$statusObj = Get-SecretStatus `
            -Secret $secret `
            -WarningDays $WarningDays `
            -ReferenceDate $ReferenceDate

        switch ($statusObj.Status) {
            'expired' { $expiredList.Add($statusObj) }
            'warning' { $warningList.Add($statusObj) }
            'ok'      { $okList.Add($statusObj) }
            default   { throw "Unexpected status value: '$($statusObj.Status)'" }
        }
    }

    return @{
        Expired     = [PSCustomObject[]]$expiredList.ToArray()
        Warning     = [PSCustomObject[]]$warningList.ToArray()
        Ok          = [PSCustomObject[]]$okList.ToArray()
        GeneratedAt = [datetime]::Now
        WarningDays = $WarningDays
    }
}

<#
.SYNOPSIS
    Formats a rotation report as a Markdown document.

.DESCRIPTION
    Produces a Markdown report with a header, a summary count table, and
    one detail table per urgency group. Empty groups show a placeholder
    rather than an empty table.

.PARAMETER Report
    Hashtable returned by Get-RotationReport.

.OUTPUTS
    Markdown string.
#>
function Format-MarkdownTable {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report
    )

    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("**Generated:** $(([datetime]$Report.GeneratedAt).ToString('yyyy-MM-dd HH:mm:ss'))")
    [void]$sb.AppendLine("**Warning Window:** $([int]$Report.WarningDays) days")
    [void]$sb.AppendLine('')

    # --- Summary table ---
    [PSCustomObject[]]$expiredItems = [PSCustomObject[]]$Report.Expired
    [PSCustomObject[]]$warningItems = [PSCustomObject[]]$Report.Warning
    [PSCustomObject[]]$okItems      = [PSCustomObject[]]$Report.Ok

    [void]$sb.AppendLine('## Summary')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Status | Count |')
    [void]$sb.AppendLine('|--------|-------|')
    [void]$sb.AppendLine("| Expired | $([int]$expiredItems.Count) |")
    [void]$sb.AppendLine("| Warning | $([int]$warningItems.Count) |")
    [void]$sb.AppendLine("| OK | $([int]$okItems.Count) |")
    [void]$sb.AppendLine('')

    # --- Detail sections: Expired → Warning → Ok ---
    # Each section contains a table of secrets or a placeholder if empty.
    [hashtable[]]$sections = @(
        @{ Label = 'Expired Secrets (Action Required)'; Items = $expiredItems }
        @{ Label = 'Warning — Expiring Soon';            Items = $warningItems }
        @{ Label = 'OK — Up to Date';                    Items = $okItems      }
    )

    foreach ($section in $sections) {
        [void]$sb.AppendLine("## $($section.Label)")
        [void]$sb.AppendLine('')

        [PSCustomObject[]]$items = [PSCustomObject[]]$section.Items

        if ($items.Count -eq 0) {
            [void]$sb.AppendLine('*No secrets in this category.*')
            [void]$sb.AppendLine('')
            continue
        }

        [void]$sb.AppendLine('| Name | Last Rotated | Rotation Policy | Expiry Date | Days Until Expiry | Required By |')
        [void]$sb.AppendLine('|------|-------------|----------------|-------------|------------------|-------------|')

        foreach ($item in $items) {
            [string]$name         = [string]$item.Name
            [string]$lastRotated  = ([datetime]$item.LastRotated).ToString('yyyy-MM-dd')
            [string]$rotationDays = "$([int]$item.RotationDays) days"
            [string]$expiryDate   = ([datetime]$item.ExpiryDate).ToString('yyyy-MM-dd')
            [int]$days            = [int]$item.DaysUntilExpiry
            [string]$daysStr      = if ($days -lt 0) {
                "**OVERDUE by $([Math]::Abs($days)) days**"
            } else {
                [string]$days
            }
            [string]$requiredBy = ([string[]]$item.RequiredBy -join ', ')

            [void]$sb.AppendLine("| $name | $lastRotated | $rotationDays | $expiryDate | $daysStr | $requiredBy |")
        }
        [void]$sb.AppendLine('')
    }

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats a rotation report as a JSON string.

.DESCRIPTION
    Serializes the report into a structured JSON document suitable for
    downstream processing (CI pipelines, dashboards, alerting systems).

.PARAMETER Report
    Hashtable returned by Get-RotationReport.

.OUTPUTS
    JSON string.
#>
function Format-JsonOutput {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Report
    )

    [PSCustomObject[]]$expiredItems = [PSCustomObject[]]$Report.Expired
    [PSCustomObject[]]$warningItems = [PSCustomObject[]]$Report.Warning
    [PSCustomObject[]]$okItems      = [PSCustomObject[]]$Report.Ok

    # Scriptblock to serialize one status object to an ordered hashtable
    [scriptblock]$serializeItem = {
        param([PSCustomObject]$Item)
        [ordered]@{
            name            = [string]$Item.Name
            lastRotated     = ([datetime]$Item.LastRotated).ToString('yyyy-MM-dd')
            rotationDays    = [int]$Item.RotationDays
            expiryDate      = ([datetime]$Item.ExpiryDate).ToString('yyyy-MM-dd')
            daysUntilExpiry = [int]$Item.DaysUntilExpiry
            status          = [string]$Item.Status
            requiredBy      = [string[]]$Item.RequiredBy
        }
    }

    [ordered]$output = [ordered]@{
        generatedAt = ([datetime]$Report.GeneratedAt).ToString('yyyy-MM-ddTHH:mm:ss')
        warningDays = [int]$Report.WarningDays
        summary     = [ordered]@{
            expired = [int]$expiredItems.Count
            warning = [int]$warningItems.Count
            ok      = [int]$okItems.Count
            total   = [int]($expiredItems.Count + $warningItems.Count + $okItems.Count)
        }
        secrets     = [ordered]@{
            expired = @($expiredItems | ForEach-Object { & $serializeItem $_ })
            warning = @($warningItems | ForEach-Object { & $serializeItem $_ })
            ok      = @($okItems      | ForEach-Object { & $serializeItem $_ })
        }
    }

    return $output | ConvertTo-Json -Depth 10
}

<#
.SYNOPSIS
    Entry point: validates secrets and returns a formatted report.

.DESCRIPTION
    Combines Get-RotationReport with Format-MarkdownTable or Format-JsonOutput
    into a single call. Suitable for use in CI/CD pipelines or scripts.

.PARAMETER Secrets
    Array of secret configuration PSCustomObjects, each with:
        Name         [string]   — secret identifier
        LastRotated  [datetime] — date last rotated
        RotationDays [int]      — rotation policy in days
        RequiredBy   [string[]] — dependent service names

.PARAMETER WarningDays
    Days before expiry at which to classify a secret as 'warning'. Default: 14.

.PARAMETER OutputFormat
    'Markdown' (default) or 'Json'.

.PARAMETER ReferenceDate
    Reference date for calculations. Defaults to today. Inject for testing.

.OUTPUTS
    Formatted string (Markdown or JSON).
#>
function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Secrets,

        [Parameter()]
        [int]$WarningDays = 14,

        [Parameter()]
        [ValidateSet('Markdown', 'Json')]
        [string]$OutputFormat = 'Markdown',

        [Parameter()]
        [datetime]$ReferenceDate = [datetime]::Today
    )

    [hashtable]$report = Get-RotationReport `
        -Secrets $Secrets `
        -WarningDays $WarningDays `
        -ReferenceDate $ReferenceDate

    if ($OutputFormat -eq 'Markdown') {
        return Format-MarkdownTable -Report $report
    } else {
        return Format-JsonOutput -Report $report
    }
}

# Export all public functions
Export-ModuleMember -Function @(
    'Get-SecretStatus'
    'Get-RotationReport'
    'Format-MarkdownTable'
    'Format-JsonOutput'
    'Invoke-SecretRotationValidator'
)
