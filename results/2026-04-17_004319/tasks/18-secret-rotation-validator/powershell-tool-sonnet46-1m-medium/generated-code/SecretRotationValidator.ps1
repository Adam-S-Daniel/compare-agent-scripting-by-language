# SecretRotationValidator.ps1
# Validates secrets against rotation policies and generates urgency reports.

<#
.SYNOPSIS
    Computes the rotation status of a single secret.
.DESCRIPTION
    Compares LastRotated + RotationDays against ReferenceDate.
    Returns a hashtable with Urgency (expired/warning/ok), DaysUntilExpiry,
    and the original secret fields.
#>
function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Secret,
        [Parameter(Mandatory)][datetime]$ReferenceDate,
        [int]$WarningDays = 14
    )

    $lastRotated  = [datetime]::Parse($Secret.LastRotated)
    $expiryDate   = $lastRotated.AddDays($Secret.RotationDays)
    $daysLeft     = [int][Math]::Floor(($expiryDate - $ReferenceDate).TotalDays)

    $urgency = if ($daysLeft -lt 0) {
        'expired'
    } elseif ($daysLeft -le $WarningDays) {
        'warning'
    } else {
        'ok'
    }

    return @{
        Name            = $Secret.Name
        LastRotated     = $Secret.LastRotated
        RotationDays    = $Secret.RotationDays
        RequiredBy      = $Secret.RequiredBy
        ExpiryDate      = $expiryDate.ToString('yyyy-MM-dd')
        DaysUntilExpiry = $daysLeft
        Urgency         = $urgency
    }
}

<#
.SYNOPSIS
    Builds a rotation report grouping secrets by urgency.
#>
function Get-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Secrets,
        [Parameter(Mandatory)][datetime]$ReferenceDate,
        [int]$WarningDays = 14
    )

    $statuses = $Secrets | ForEach-Object {
        $s = if ($_ -is [hashtable]) { $_ } else {
            # PSCustomObject -> hashtable
            $h = @{}
            $_.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
            # RequiredBy may come back as PSCustomObject array; normalize to string[]
            if ($h.ContainsKey('RequiredBy') -and $null -ne $h['RequiredBy']) {
                $h['RequiredBy'] = @($h['RequiredBy'] | ForEach-Object { "$_" })
            }
            $h
        }
        Get-SecretStatus -Secret $s -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    }

    return @{
        Expired     = @($statuses | Where-Object { $_.Urgency -eq 'expired' })
        Warning     = @($statuses | Where-Object { $_.Urgency -eq 'warning' })
        Ok          = @($statuses | Where-Object { $_.Urgency -eq 'ok' })
        GeneratedAt = $ReferenceDate.ToString('o')
        WarningDays = $WarningDays
    }
}

<#
.SYNOPSIS
    Formats a rotation report as Markdown or JSON.
#>
function Format-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Report,
        [ValidateSet('Markdown','JSON')]
        [string]$Format = 'Markdown'
    )

    if ($Format -eq 'JSON') {
        $obj = [ordered]@{
            generatedAt = $Report.GeneratedAt
            warningDays = $Report.WarningDays
            expired     = @($Report.Expired | ForEach-Object { [ordered]@{
                name            = $_.Name
                lastRotated     = $_.LastRotated
                rotationDays    = $_.RotationDays
                expiryDate      = $_.ExpiryDate
                daysUntilExpiry = $_.DaysUntilExpiry
                requiredBy      = $_.RequiredBy
            }})
            warning     = @($Report.Warning | ForEach-Object { [ordered]@{
                name            = $_.Name
                lastRotated     = $_.LastRotated
                rotationDays    = $_.RotationDays
                expiryDate      = $_.ExpiryDate
                daysUntilExpiry = $_.DaysUntilExpiry
                requiredBy      = $_.RequiredBy
            }})
            ok          = @($Report.Ok | ForEach-Object { [ordered]@{
                name            = $_.Name
                lastRotated     = $_.LastRotated
                rotationDays    = $_.RotationDays
                expiryDate      = $_.ExpiryDate
                daysUntilExpiry = $_.DaysUntilExpiry
                requiredBy      = $_.RequiredBy
            }})
        }
        return $obj | ConvertTo-Json -Depth 5
    }

    # Markdown format
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Secret Rotation Report")
    $lines.Add("")
    $lines.Add("Generated: $($Report.GeneratedAt)  |  Warning window: $($Report.WarningDays) days")
    $lines.Add("")

    foreach ($group in @('Expired','Warning','Ok')) {
        $items = $Report[$group]
        $lines.Add("## $group")
        $lines.Add("")

        if ($items.Count -eq 0) {
            $lines.Add("_None_")
            $lines.Add("")
            continue
        }

        $lines.Add("| Name | Last Rotated | Policy (days) | Expires | Days Until Expiry | Required By |")
        $lines.Add("|------|-------------|---------------|---------|-------------------|-------------|")

        foreach ($item in $items) {
            $reqBy = ($item.RequiredBy -join ', ')
            $lines.Add("| $($item.Name) | $($item.LastRotated) | $($item.RotationDays) | $($item.ExpiryDate) | $($item.DaysUntilExpiry) | $reqBy |")
        }
        $lines.Add("")
    }

    return $lines -join "`n"
}

<#
.SYNOPSIS
    End-to-end validator: reads a JSON config, builds and returns a report.
.DESCRIPTION
    Config JSON schema:
    {
      "warningDays": 14,          # optional, defaults to 14
      "secrets": [
        {
          "Name": "...",
          "LastRotated": "YYYY-MM-DD",
          "RotationDays": 90,
          "RequiredBy": ["svc1","svc2"]
        }
      ]
    }
#>
function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [datetime]$ReferenceDate = (Get-Date),
        [int]$WarningDays = 14
    )

    if (-not (Test-Path $ConfigPath)) {
        throw [System.IO.FileNotFoundException]::new(
            "Config file not found: $ConfigPath", $ConfigPath
        )
    }

    $raw    = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $warn   = if ($null -ne $raw.warningDays) { [int]$raw.warningDays } else { $WarningDays }

    # Normalize secrets from PSCustomObject to hashtable[]
    $secrets = @($raw.secrets | ForEach-Object {
        $h = @{}
        $_.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
        if ($h.ContainsKey('RequiredBy') -and $null -ne $h['RequiredBy']) {
            $h['RequiredBy'] = @($h['RequiredBy'] | ForEach-Object { "$_" })
        }
        $h
    })

    return Get-RotationReport -Secrets $secrets -ReferenceDate $ReferenceDate -WarningDays $warn
}
