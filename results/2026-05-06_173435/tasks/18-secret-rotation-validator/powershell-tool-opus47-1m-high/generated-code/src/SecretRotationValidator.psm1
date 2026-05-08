# SecretRotationValidator
#
# Pure-logic module: takes plain PowerShell objects in and returns objects/strings
# out. No file I/O, no Get-Date defaults — that lives in the CLI script. Keeping
# the module deterministic makes it trivial to unit-test under Pester.

Set-StrictMode -Version Latest

$script:RequiredFields = @('name', 'lastRotated', 'rotationPolicyDays', 'requiredBy')

function Get-SecretStatus {
    <#
    .SYNOPSIS
        Classify a single secret as expired / warning / ok and compute its expiry math.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]   $Secret,
        [Parameter(Mandatory)] [datetime] $AsOf,
        [Parameter(Mandatory)] [int]      $WarningWindowDays
    )

    $names = @($Secret.PSObject.Properties.Name)
    foreach ($field in $script:RequiredFields) {
        if ($names -notcontains $field) {
            throw "Secret '$($Secret.name)' is missing required field '$field'."
        }
    }

    $lastRotated = [datetime]::Parse([string]$Secret.lastRotated)
    $expiresOn   = $lastRotated.AddDays([int]$Secret.rotationPolicyDays)

    # Compare on calendar-day boundaries: a secret expiring today shows
    # daysUntilExpiry = 0, yesterday = -1, tomorrow = 1.
    $daysUntilExpiry = [int]([math]::Floor(($expiresOn.Date - $AsOf.Date).TotalDays))

    $urgency =
        if     ($daysUntilExpiry -lt 0)                  { 'expired' }
        elseif ($daysUntilExpiry -le $WarningWindowDays) { 'warning' }
        else                                             { 'ok' }

    [pscustomobject][ordered]@{
        name               = [string]$Secret.name
        lastRotated        = $lastRotated.ToString('yyyy-MM-dd')
        rotationPolicyDays = [int]$Secret.rotationPolicyDays
        requiredBy         = @($Secret.requiredBy)
        expiresOn          = $expiresOn.ToString('yyyy-MM-dd')
        daysUntilExpiry    = $daysUntilExpiry
        urgency            = $urgency
    }
}

function Get-SecretRotationReport {
    <#
    .SYNOPSIS
        Build the grouped/summarized report for a collection of secrets.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Secrets,
        [Parameter(Mandatory)] [datetime] $AsOf,
        [Parameter(Mandatory)] [int]      $WarningWindowDays
    )

    $statuses = @(
        foreach ($s in $Secrets) {
            Get-SecretStatus -Secret $s -AsOf $AsOf -WarningWindowDays $WarningWindowDays
        }
    )

    # Stable sort: most-overdue first within each bucket, soonest-to-expire first
    # in the warning bucket — operators care most about what to rotate next.
    $expired = @($statuses | Where-Object urgency -eq 'expired' | Sort-Object daysUntilExpiry, name)
    $warning = @($statuses | Where-Object urgency -eq 'warning' | Sort-Object daysUntilExpiry, name)
    $ok      = @($statuses | Where-Object urgency -eq 'ok'      | Sort-Object daysUntilExpiry, name)

    [pscustomobject][ordered]@{
        asOf              = $AsOf.ToString('yyyy-MM-dd')
        warningWindowDays = $WarningWindowDays
        summary           = [pscustomobject][ordered]@{
            total   = $statuses.Count
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
        }
        expired = $expired
        warning = $warning
        ok      = $ok
    }
}

function Format-RotationReport {
    <#
    .SYNOPSIS
        Render a rotation report as markdown or JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Format
    )

    switch ($Format.ToLowerInvariant()) {
        'markdown' { return _Format-AsMarkdown -Report $Report }
        'json'     { return ($Report | ConvertTo-Json -Depth 6) }
        default    { throw "Unsupported format '$Format'. Use 'markdown' or 'json'." }
    }
}

function _Format-AsMarkdown {
    param([Parameter(Mandatory)] [object] $Report)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("- Date: $($Report.asOf)")
    [void]$sb.AppendLine("- Warning window: $($Report.warningWindowDays) days")
    [void]$sb.AppendLine("- Total: $($Report.summary.total)")
    [void]$sb.AppendLine("- Expired: $($Report.summary.expired)")
    [void]$sb.AppendLine("- Warning: $($Report.summary.warning)")
    [void]$sb.AppendLine("- OK: $($Report.summary.ok)")
    [void]$sb.AppendLine()

    foreach ($section in @(
        @{ Title = 'Expired'; List = @($Report.expired) },
        @{ Title = 'Warning'; List = @($Report.warning) },
        @{ Title = 'OK';      List = @($Report.ok)      }
    )) {
        [void]$sb.AppendLine("## $($section.Title) ($($section.List.Count))")
        [void]$sb.AppendLine()
        if ($section.List.Count -eq 0) {
            [void]$sb.AppendLine('_No secrets in this category._')
            [void]$sb.AppendLine()
            continue
        }
        [void]$sb.AppendLine('| Name | Last Rotated | Expires On | Days Until Expiry | Required By |')
        [void]$sb.AppendLine('|------|--------------|------------|-------------------|-------------|')
        foreach ($s in $section.List) {
            $required = (@($s.requiredBy)) -join ', '
            [void]$sb.AppendLine("| $($s.name) | $($s.lastRotated) | $($s.expiresOn) | $($s.daysUntilExpiry) | $required |")
        }
        [void]$sb.AppendLine()
    }
    return $sb.ToString().TrimEnd()
}

function Read-SecretsConfig {
    <#
    .SYNOPSIS
        Load and validate a secrets-config JSON file. Accepts either a top-level
        array of secrets or an object with a "secrets" array.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Configuration file is empty: $Path"
    }
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$Path': $($_.Exception.Message)"
    }

    if ($parsed -is [System.Collections.IEnumerable] -and -not ($parsed -is [string])) {
        return @($parsed)
    }
    if ($parsed.PSObject.Properties.Name -contains 'secrets') {
        return @($parsed.secrets)
    }
    return @($parsed)
}

Export-ModuleMember -Function Get-SecretStatus, Get-SecretRotationReport, Format-RotationReport, Read-SecretsConfig
