# Secret Rotation Validator
# Reads a config of secrets (name, lastRotated, rotationDays, requiredBy) and
# classifies them as expired, warning, or ok relative to a reference date.
# Supports markdown and json output formats.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Secret,
        [Parameter(Mandatory)] [datetime] $ReferenceDate,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    foreach ($field in 'name','lastRotated','rotationDays') {
        if (-not $Secret.PSObject.Properties[$field]) {
            throw "Secret is missing required field '$field'"
        }
    }

    if ($Secret.rotationDays -le 0) {
        throw "Secret '$($Secret.name)' has invalid rotationDays '$($Secret.rotationDays)' (must be > 0)"
    }

    $lastRotated = [datetime]::Parse($Secret.lastRotated)
    $expiresOn   = $lastRotated.AddDays([int]$Secret.rotationDays)
    $daysLeft    = [int][math]::Floor(($expiresOn - $ReferenceDate).TotalDays)

    $urgency =
        if ($daysLeft -lt 0)                 { 'expired' }
        elseif ($daysLeft -le $WarningDays)  { 'warning' }
        else                                 { 'ok' }

    [pscustomobject]@{
        name         = $Secret.name
        lastRotated  = $lastRotated.ToString('yyyy-MM-dd')
        expiresOn    = $expiresOn.ToString('yyyy-MM-dd')
        daysLeft     = $daysLeft
        urgency      = $urgency
        requiredBy   = if ($Secret.PSObject.Properties['requiredBy']) { @($Secret.requiredBy) } else { @() }
    }
}

function Invoke-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [ValidateSet('markdown','json')] [string] $Format = 'markdown',
        [int] $WarningDays = 14,
        [datetime] $ReferenceDate = (Get-Date)
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse config '$ConfigPath' as JSON: $($_.Exception.Message)"
    }

    if (-not $config.PSObject.Properties['secrets']) {
        throw "Config must contain a top-level 'secrets' array"
    }

    $results = foreach ($s in @($config.secrets)) {
        Get-SecretStatus -Secret $s -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    # Stable order: expired first, then warning, then ok; within a group sort by daysLeft asc then name.
    $order = @{ expired = 0; warning = 1; ok = 2 }
    $sorted = $results | Sort-Object @{Expression={$order[$_.urgency]}}, daysLeft, name

    switch ($Format) {
        'json'     { Format-JsonReport     -Results $sorted -WarningDays $WarningDays -ReferenceDate $ReferenceDate }
        'markdown' { Format-MarkdownReport -Results $sorted -WarningDays $WarningDays -ReferenceDate $ReferenceDate }
    }
}

function Format-JsonReport {
    param($Results, [int]$WarningDays, [datetime]$ReferenceDate)

    $groups = @{ expired = @(); warning = @(); ok = @() }
    foreach ($r in $Results) { $groups[$r.urgency] += $r }

    $payload = [pscustomobject]@{
        referenceDate = $ReferenceDate.ToString('yyyy-MM-dd')
        warningDays   = $WarningDays
        summary       = [pscustomobject]@{
            expired = $groups['expired'].Count
            warning = $groups['warning'].Count
            ok      = $groups['ok'].Count
        }
        secrets = @($Results)
    }
    $payload | ConvertTo-Json -Depth 6
}

function Format-MarkdownReport {
    param($Results, [int]$WarningDays, [datetime]$ReferenceDate)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Reference date: $($ReferenceDate.ToString('yyyy-MM-dd'))  ")
    [void]$sb.AppendLine("Warning window: $WarningDays days")
    [void]$sb.AppendLine("")

    $counts = @{ expired = 0; warning = 0; ok = 0 }
    foreach ($r in $Results) { $counts[$r.urgency]++ }
    [void]$sb.AppendLine("Summary: expired=$($counts['expired']), warning=$($counts['warning']), ok=$($counts['ok'])")
    [void]$sb.AppendLine("")

    foreach ($group in 'expired','warning','ok') {
        $rows = @($Results | Where-Object { $_.urgency -eq $group })
        [void]$sb.AppendLine("## $($group.ToUpper()) ($($rows.Count))")
        [void]$sb.AppendLine("")
        if ($rows.Count -eq 0) {
            [void]$sb.AppendLine("_No secrets in this category._")
            [void]$sb.AppendLine("")
            continue
        }
        [void]$sb.AppendLine("| Name | Last Rotated | Expires On | Days Left | Required By |")
        [void]$sb.AppendLine("| --- | --- | --- | --- | --- |")
        foreach ($r in $rows) {
            $reqArr = @($r.requiredBy)
            $required = if ($reqArr.Count -gt 0) { ($reqArr -join ', ') } else { '-' }
            [void]$sb.AppendLine("| $($r.name) | $($r.lastRotated) | $($r.expiresOn) | $($r.daysLeft) | $required |")
        }
        [void]$sb.AppendLine("")
    }
    $sb.ToString().TrimEnd()
}

# When run as a script (not dot-sourced), act as CLI.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # no-op: module style usage only. CLI wrapper is a separate script.
    }
}
