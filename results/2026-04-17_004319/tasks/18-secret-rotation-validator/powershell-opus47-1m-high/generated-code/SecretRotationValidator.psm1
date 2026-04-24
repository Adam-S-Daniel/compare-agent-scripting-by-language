# SecretRotationValidator
#
# Pure functions for evaluating a list of secret-rotation records against a
# rotation policy and formatting the result. No I/O inside the core functions
# (Get-SecretStatus, Get-RotationReport, Format-RotationReport) so they stay
# easy to test; I/O lives in Invoke-SecretRotationValidator.
#
# Record shape (mock data):
#   { name, lastRotated (YYYY-MM-DD), rotationPolicyDays (int), requiredBy (string[]) }
#
# Urgency buckets:
#   expired: dueDate <= now           (exit code 2)
#   warning: now < dueDate <= now + WarningDays   (exit code 1)
#   ok     : dueDate > now + WarningDays (exit code 0)
#
# The CLI returns the worst bucket's exit code so it can fail CI.

Set-StrictMode -Version Latest

function ConvertTo-NormalizedSecret {
    # Accepts either PSCustomObject (from Import-PSD / hashtable) or
    # ConvertFrom-Json output (which uses camelCase). Returns a consistent
    # object with Name / LastRotated / RotationPolicyDays / RequiredBy fields
    # so downstream code never has to worry about casing.
    param([Parameter(Mandatory)] $Secret)

    $props = @{}
    foreach ($p in $Secret.PSObject.Properties) {
        $props[$p.Name.ToLowerInvariant()] = $p.Value
    }

    $name = $props['name']
    $lastRotated = $props['lastrotated']
    $policy = $props['rotationpolicydays']
    $requiredBy = if ($props.ContainsKey('requiredby')) { $props['requiredby'] } else { @() }

    foreach ($field in 'name','lastrotated','rotationpolicydays') {
        if (-not $props.ContainsKey($field) -or $null -eq $props[$field]) {
            throw "Secret is missing required field '$field'."
        }
    }

    [pscustomobject]@{
        Name               = [string]$name
        LastRotated        = [string]$lastRotated
        RotationPolicyDays = [int]$policy
        RequiredBy         = @($requiredBy)
    }
}

function Get-SecretStatus {
    <#
    .SYNOPSIS
    Classify a single secret as expired / warning / ok relative to Now.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secret,
        [Parameter(Mandatory)] [DateTime] $Now,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    $s = ConvertTo-NormalizedSecret -Secret $Secret

    $parsed = [DateTime]::MinValue
    if (-not [DateTime]::TryParse($s.LastRotated, [ref]$parsed)) {
        throw "Secret '$($s.Name)' has invalid LastRotated value: '$($s.LastRotated)'."
    }

    $dueDate = $parsed.AddDays($s.RotationPolicyDays)
    # Use whole-day math so "expires today" is treated as expired, matching
    # operator intuition (the calendar day has arrived).
    $daysUntilDue = [int][Math]::Floor(($dueDate - $Now).TotalDays)

    $status =
        if ($daysUntilDue -le 0) { 'expired' }
        elseif ($daysUntilDue -le $WarningDays) { 'warning' }
        else { 'ok' }

    [pscustomobject]@{
        Name               = $s.Name
        LastRotated        = $s.LastRotated
        RotationPolicyDays = $s.RotationPolicyDays
        RequiredBy         = $s.RequiredBy
        DueDate            = $dueDate.ToString('yyyy-MM-dd')
        DaysUntilDue       = $daysUntilDue
        Status             = $status
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
    Evaluate a list of secrets and bucket them by urgency.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Secrets,
        [Parameter(Mandatory)] [DateTime] $Now,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    $evaluated = foreach ($s in $Secrets) {
        Get-SecretStatus -Secret $s -Now $Now -WarningDays $WarningDays
    }

    # Sort within bucket so output is deterministic: most urgent first inside
    # expired/warning, alphabetical inside ok.
    $expired = @($evaluated | Where-Object Status -EQ 'expired' | Sort-Object DaysUntilDue)
    $warning = @($evaluated | Where-Object Status -EQ 'warning' | Sort-Object DaysUntilDue)
    $ok      = @($evaluated | Where-Object Status -EQ 'ok'      | Sort-Object Name)

    [pscustomobject]@{
        GeneratedAt = $Now
        WarningDays = $WarningDays
        Totals      = [pscustomobject]@{
            Expired = $expired.Count
            Warning = $warning.Count
            Ok      = $ok.Count
        }
        Expired = $expired
        Warning = $warning
        Ok      = $ok
    }
}

function Format-MarkdownSection {
    param([string] $Title, [int] $Count, $Rows)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("## $Title ($Count)")
    $lines.Add('')
    if ($Count -eq 0) {
        $lines.Add('_No secrets in this bucket._')
        $lines.Add('')
        return ($lines -join "`n")
    }
    $lines.Add('| Name | Last Rotated | Policy (days) | Days Until Due | Required By |')
    $lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($r in $Rows) {
        $required = ($r.RequiredBy -join ', ')
        $lines.Add("| $($r.Name) | $($r.LastRotated) | $($r.RotationPolicyDays) | $($r.DaysUntilDue) | $required |")
    }
    $lines.Add('')
    return ($lines -join "`n")
}

function Format-RotationReport {
    <#
    .SYNOPSIS
    Render a rotation report as markdown or JSON.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Report,
        [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format
    )

    if ($Format -eq 'json') {
        $toRow = {
            param($r)
            [pscustomobject]@{
                name               = $r.Name
                lastRotated        = $r.LastRotated
                rotationPolicyDays = $r.RotationPolicyDays
                requiredBy         = $r.RequiredBy
                dueDate            = $r.DueDate
                daysUntilDue       = $r.DaysUntilDue
                status             = $r.Status
            }
        }
        $payload = [pscustomobject]@{
            generatedAt = $Report.GeneratedAt.ToString('o')
            warningDays = $Report.WarningDays
            totals      = [pscustomobject]@{
                expired = $Report.Totals.Expired
                warning = $Report.Totals.Warning
                ok      = $Report.Totals.Ok
            }
            expired = @($Report.Expired | ForEach-Object { & $toRow $_ })
            warning = @($Report.Warning | ForEach-Object { & $toRow $_ })
            ok      = @($Report.Ok      | ForEach-Object { & $toRow $_ })
        }
        return ($payload | ConvertTo-Json -Depth 6)
    }

    $parts = @(
        "# Secret Rotation Report"
        ""
        "- Generated: $($Report.GeneratedAt.ToString('yyyy-MM-dd'))"
        "- Warning window: $($Report.WarningDays) days"
        "- Totals: $($Report.Totals.Expired) expired / $($Report.Totals.Warning) warning / $($Report.Totals.Ok) ok"
        ""
        (Format-MarkdownSection -Title 'Expired' -Count $Report.Totals.Expired -Rows $Report.Expired)
        (Format-MarkdownSection -Title 'Warning' -Count $Report.Totals.Warning -Rows $Report.Warning)
        (Format-MarkdownSection -Title 'OK'      -Count $Report.Totals.Ok      -Rows $Report.Ok)
    )
    return ($parts -join "`n")
}

function Invoke-SecretRotationValidator {
    <#
    .SYNOPSIS
    CLI-ish entry point: read JSON config, build report, emit formatted output.
    .DESCRIPTION
    With -ReturnExitCode, returns an object { Output; ExitCode } instead of
    just the formatted string. This keeps the function testable without having
    to read the shell's $LASTEXITCODE.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [DateTime] $Now = (Get-Date),
        [int] $WarningDays = 14,
        [ValidateSet('markdown','json')] [string] $Format = 'markdown',
        [switch] $ReturnExitCode
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $secrets = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON config '$ConfigPath': $($_.Exception.Message)"
    }

    # Allow either a bare array or an object with a 'secrets' property.
    if ($secrets.PSObject.Properties.Name -contains 'secrets') {
        $secrets = $secrets.secrets
    }
    if ($null -eq $secrets) { $secrets = @() }
    $secrets = @($secrets)

    $report = Get-RotationReport -Secrets $secrets -Now $Now -WarningDays $WarningDays
    $output = Format-RotationReport -Report $report -Format $Format

    $exitCode =
        if ($report.Totals.Expired -gt 0) { 2 }
        elseif ($report.Totals.Warning -gt 0) { 1 }
        else { 0 }

    if ($ReturnExitCode) {
        return [pscustomobject]@{ Output = $output; ExitCode = $exitCode; Report = $report }
    }
    return $output
}

Export-ModuleMember -Function `
    Get-SecretStatus, Get-RotationReport, Format-RotationReport, Invoke-SecretRotationValidator
