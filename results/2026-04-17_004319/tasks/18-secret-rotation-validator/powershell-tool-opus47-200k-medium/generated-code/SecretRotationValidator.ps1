# Secret Rotation Validator
# Reads a secrets config, classifies each secret as expired / warning / ok,
# and renders a report in markdown or JSON.

Set-StrictMode -Version Latest

function Get-SecretRotationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Secrets,
        [int]$WarningDays = 7,
        [datetime]$Now = (Get-Date)
    )

    $expired = [System.Collections.Generic.List[object]]::new()
    $warning = [System.Collections.Generic.List[object]]::new()
    $ok      = [System.Collections.Generic.List[object]]::new()

    foreach ($s in $Secrets) {
        if ($s.rotationDays -lt 0) {
            throw "Invalid rotationDays for secret '$($s.name)': must be >= 0"
        }
        $parsed = [datetime]::MinValue
        if (-not [datetime]::TryParse([string]$s.lastRotated, [ref]$parsed)) {
            throw "Invalid lastRotated date for secret '$($s.name)': $($s.lastRotated)"
        }
        $expiresAt     = $parsed.AddDays([int]$s.rotationDays)
        $daysUntil     = [int][math]::Floor(($expiresAt - $Now).TotalDays)

        $enriched = [pscustomobject]@{
            name            = $s.name
            lastRotated     = $s.lastRotated
            rotationDays    = $s.rotationDays
            requiredBy      = @($s.requiredBy)
            daysUntilExpiry = $daysUntil
        }

        if ($daysUntil -lt 0)                    { $expired.Add($enriched) }
        elseif ($daysUntil -le $WarningDays)     { $warning.Add($enriched) }
        else                                     { $ok.Add($enriched) }
    }

    [pscustomobject]@{
        expired = $expired.ToArray()
        warning = $warning.ToArray()
        ok      = $ok.ToArray()
    }
}

function Format-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Status,
        [ValidateSet('markdown','json')][string]$Format = 'markdown'
    )

    switch ($Format) {
        'json' {
            return [pscustomobject]@{
                expired = @($Status.expired)
                warning = @($Status.warning)
                ok      = @($Status.ok)
            } | ConvertTo-Json -Depth 6
        }
        'markdown' {
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine("# Secret Rotation Report")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("- Expired: $(@($Status.expired).Count)")
            [void]$sb.AppendLine("- Warning: $(@($Status.warning).Count)")
            [void]$sb.AppendLine("- OK: $(@($Status.ok).Count)")
            [void]$sb.AppendLine()

            foreach ($section in @(
                @{ Title='Expired'; Items=$Status.expired },
                @{ Title='Warning'; Items=$Status.warning },
                @{ Title='OK';      Items=$Status.ok }
            )) {
                [void]$sb.AppendLine("## $($section.Title)")
                [void]$sb.AppendLine()
                if (@($section.Items).Count -eq 0) {
                    [void]$sb.AppendLine("_None_")
                    [void]$sb.AppendLine()
                    continue
                }
                [void]$sb.AppendLine("| Name | Last Rotated | Rotation Days | Days Until Expiry | Required By |")
                [void]$sb.AppendLine("|------|--------------|---------------|-------------------|-------------|")
                foreach ($it in $section.Items) {
                    $req = (@($it.requiredBy) -join ', ')
                    [void]$sb.AppendLine("| $($it.name) | $($it.lastRotated) | $($it.rotationDays) | $($it.daysUntilExpiry) | $req |")
                }
                [void]$sb.AppendLine()
            }
            return $sb.ToString().TrimEnd()
        }
        default { throw "Unknown Format: $Format" }
    }
}

function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [int]$WarningDays = 7,
        [ValidateSet('markdown','json')][string]$Format = 'markdown',
        [datetime]$Now = (Get-Date),
        [switch]$AsObject
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if (-not $config.PSObject.Properties['secrets']) {
        throw "Config missing 'secrets' array"
    }

    $status = Get-SecretRotationStatus -Secrets $config.secrets -WarningDays $WarningDays -Now $Now
    if ($AsObject) { return $status }
    return Format-RotationReport -Status $status -Format $Format
}
