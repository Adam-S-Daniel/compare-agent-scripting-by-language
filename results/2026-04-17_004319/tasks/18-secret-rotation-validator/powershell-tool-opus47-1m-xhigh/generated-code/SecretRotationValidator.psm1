#requires -Version 7.0
# SecretRotationValidator.psm1
#
# Library of functions that classify secrets by rotation urgency and emit
# human-readable or machine-readable reports. The module is time-deterministic:
# all date-sensitive functions accept a -Now parameter that tests pin to a
# fixed value. In production, callers omit -Now and the current date is used.

Set-StrictMode -Version 3.0

# ----- internal helpers -------------------------------------------------------

function ConvertTo-DateTimeMidnight {
    # Parses a date (string or datetime) and normalises to midnight UTC so
    # subtraction is in whole days regardless of the caller's timezone.
    param([Parameter(Mandatory)][object] $Value)

    if ($Value -is [datetime]) {
        return [datetime]::SpecifyKind($Value.Date, [System.DateTimeKind]::Utc)
    }

    $parsed = [datetime]::MinValue
    $fmt    = 'yyyy-MM-dd'
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $style   = [System.Globalization.DateTimeStyles]::AssumeUniversal `
               -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    if (-not [datetime]::TryParseExact([string]$Value, $fmt, $culture, $style, [ref] $parsed)) {
        # Fall back to a permissive parse so ISO-8601 with time still works.
        if (-not [datetime]::TryParse([string]$Value, $culture, $style, [ref] $parsed)) {
            throw "Invalid date value: '$Value' (expected yyyy-MM-dd)."
        }
    }
    return [datetime]::SpecifyKind($parsed.Date, [System.DateTimeKind]::Utc)
}

function Assert-SecretShape {
    # Validates that a parsed JSON entry has every field the rest of the code
    # relies on. Fails loudly rather than producing confusing NullReference errors later.
    param([Parameter(Mandatory)] $Secret, [int] $Index)

    $required = @('name', 'lastRotated', 'rotationDays', 'requiredBy')
    foreach ($field in $required) {
        if (-not ($Secret.PSObject.Properties.Name -contains $field)) {
            throw "Secret at index $Index is missing required field '$field'."
        }
    }
    if (-not ($Secret.rotationDays -is [int] -or $Secret.rotationDays -is [long] -or $Secret.rotationDays -is [double])) {
        throw "Secret '$($Secret.name)' has non-numeric rotationDays."
    }
    if ($Secret.rotationDays -le 0) {
        throw "Secret '$($Secret.name)' has non-positive rotationDays '$($Secret.rotationDays)'."
    }
}

# ----- public API -------------------------------------------------------------

function Get-SecretRotationStatus {
    <#
        .SYNOPSIS
        Classifies a single secret as expired / warning / ok.
        .DESCRIPTION
        Expiry = lastRotated + rotationDays. Result carries the absolute
        ExpiresOn date, the signed DaysUntilExpiry, and the urgency Status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secret,
        [Parameter(Mandatory)][int] $WarningDays,
        [object] $Now = (Get-Date)
    )

    $today    = ConvertTo-DateTimeMidnight $Now
    $rotated  = ConvertTo-DateTimeMidnight $Secret.lastRotated
    $expires  = $rotated.AddDays([double]$Secret.rotationDays)
    $daysLeft = [int]([math]::Floor(($expires - $today).TotalDays))

    $status =
        if     ($daysLeft -lt 0)            { 'expired' }
        elseif ($daysLeft -le $WarningDays) { 'warning' }
        else                                { 'ok' }

    [pscustomobject]@{
        name            = $Secret.name
        lastRotated     = $rotated
        rotationDays    = [int]$Secret.rotationDays
        requiredBy      = @($Secret.requiredBy)
        ExpiresOn       = $expires
        DaysUntilExpiry = $daysLeft
        Status          = $status
    }
}

function Import-SecretConfig {
    <#
        .SYNOPSIS
        Loads a secret config from disk and validates schema.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Config file not found: '$Path'."
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Invalid JSON in '$Path': $($_.Exception.Message)"
    }

    if (-not ($parsed.PSObject.Properties.Name -contains 'secrets')) {
        throw "Config '$Path' is missing the top-level 'secrets' array."
    }

    # Normalise to an array: ConvertFrom-Json returns $null for [] and a single
    # object for one-element arrays, so wrap defensively.
    $secrets = @($parsed.secrets)

    for ($i = 0; $i -lt $secrets.Count; $i++) {
        Assert-SecretShape -Secret $secrets[$i] -Index $i
    }
    # Return as a typed array so callers can reliably use .Count.
    return ,$secrets
}

function Invoke-SecretRotationReport {
    <#
        .SYNOPSIS
        Produces a structured report of classified secrets, grouped by urgency.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()] $Secrets,
        [Parameter(Mandatory)][int] $WarningDays,
        [object] $Now = (Get-Date)
    )

    $classified = foreach ($s in $Secrets) {
        Get-SecretRotationStatus -Secret $s -WarningDays $WarningDays -Now $Now
    }
    $classified = @($classified)

    # Sort each group so the most urgent items are first. For expired secrets
    # "most urgent" means most-negative DaysUntilExpiry (longest overdue).
    $expired = @($classified | Where-Object Status -eq 'expired' | Sort-Object DaysUntilExpiry)
    $warning = @($classified | Where-Object Status -eq 'warning' | Sort-Object DaysUntilExpiry)
    $ok      = @($classified | Where-Object Status -eq 'ok'      | Sort-Object DaysUntilExpiry)

    [pscustomobject]@{
        WarningDays = $WarningDays
        GeneratedAt = (ConvertTo-DateTimeMidnight $Now)
        Expired     = $expired
        Warning     = $warning
        Ok          = $ok
        Summary     = [pscustomobject]@{
            Expired = $expired.Count
            Warning = $warning.Count
            Ok      = $ok.Count
            Total   = $classified.Count
        }
    }
}

function Format-SecretRotationReport {
    <#
        .SYNOPSIS
        Renders a report to a string in the requested format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Report,
        [Parameter(Mandatory)][string] $As
    )

    switch ($As.ToLowerInvariant()) {
        'json'     { return (ConvertTo-ReportJson -Report $Report) }
        'markdown' { return (ConvertTo-ReportMarkdown -Report $Report) }
        default    { throw "Unsupported output format '$As'. Use 'markdown' or 'json'." }
    }
}

function ConvertTo-ReportJson {
    param($Report)

    # Projection keeps dates as ISO strings — predictable for downstream tools.
    $project = {
        param($row)
        [ordered]@{
            name            = $row.name
            lastRotated     = $row.lastRotated.ToString('yyyy-MM-dd')
            expiresOn       = $row.ExpiresOn.ToString('yyyy-MM-dd')
            daysUntilExpiry = $row.DaysUntilExpiry
            rotationDays    = $row.rotationDays
            requiredBy      = @($row.requiredBy)
            status          = $row.Status
        }
    }

    $payload = [ordered]@{
        generatedAt = $Report.GeneratedAt.ToString('yyyy-MM-dd')
        warningDays = $Report.WarningDays
        summary     = [ordered]@{
            expired = $Report.Summary.Expired
            warning = $Report.Summary.Warning
            ok      = $Report.Summary.Ok
            total   = $Report.Summary.Total
        }
        expired = @($Report.Expired | ForEach-Object { & $project $_ })
        warning = @($Report.Warning | ForEach-Object { & $project $_ })
        ok      = @($Report.Ok      | ForEach-Object { & $project $_ })
    }
    # Depth 6 is plenty — no deep nesting in this schema.
    return ($payload | ConvertTo-Json -Depth 6)
}

function ConvertTo-ReportMarkdown {
    param($Report)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Generated: $($Report.GeneratedAt.ToString('yyyy-MM-dd'))")
    [void]$sb.AppendLine("Warning window: $($Report.WarningDays) day(s)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Summary — Expired: $($Report.Summary.Expired), Warning: $($Report.Summary.Warning), Ok: $($Report.Summary.Ok), Total: $($Report.Summary.Total)")
    [void]$sb.AppendLine()

    $groups = @(
        @{ Title = 'Expired'; Rows = $Report.Expired }
        @{ Title = 'Warning'; Rows = $Report.Warning }
        @{ Title = 'Ok';      Rows = $Report.Ok      }
    )
    foreach ($g in $groups) {
        if ($g.Rows.Count -eq 0) { continue }   # keep noise low — empty groups are hidden
        [void]$sb.AppendLine("## $($g.Title) ($($g.Rows.Count))")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('| Name | Last Rotated | Expires On | Days | Required By |')
        [void]$sb.AppendLine('| --- | --- | --- | --- | --- |')
        foreach ($row in $g.Rows) {
            $requiredBy = ($row.requiredBy -join ', ')
            [void]$sb.AppendLine(('| {0} | {1} | {2} | {3} | {4} |' -f `
                $row.name,
                $row.lastRotated.ToString('yyyy-MM-dd'),
                $row.ExpiresOn.ToString('yyyy-MM-dd'),
                $row.DaysUntilExpiry,
                $requiredBy))
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString().TrimEnd() + [Environment]::NewLine
}

function Invoke-SecretRotationValidator {
    <#
        .SYNOPSIS
        CLI-friendly entry point: load config, build report, return rendered string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $ConfigPath,
        [Parameter(Mandatory)][int]    $WarningDays,
        [ValidateSet('markdown', 'json')]
        [string] $Format = 'markdown',
        [object] $Now = (Get-Date)
    )

    $secrets = Import-SecretConfig -Path $ConfigPath
    $report  = Invoke-SecretRotationReport -Secrets $secrets -WarningDays $WarningDays -Now $Now
    return (Format-SecretRotationReport -Report $report -As $Format)
}

Export-ModuleMember -Function `
    Get-SecretRotationStatus,
    Import-SecretConfig,
    Invoke-SecretRotationReport,
    Format-SecretRotationReport,
    Invoke-SecretRotationValidator
