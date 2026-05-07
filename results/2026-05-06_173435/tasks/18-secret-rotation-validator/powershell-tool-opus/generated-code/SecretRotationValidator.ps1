# Secret Rotation Validator
# Identifies expired/expiring secrets and generates rotation reports.

function Get-SecretConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Configuration file '$Path' does not exist"
    }

    $raw = Get-Content -Path $Path -Raw
    try {
        $secrets = $raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON from '$Path': $_"
    }

    return $secrets
}

function Test-SecretRotation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Secrets,

        [Parameter(Mandatory)]
        [datetime]$ReferenceDate,

        [int]$WarningDays = 14
    )

    $results = foreach ($secret in $Secrets) {
        $lastRotated = [datetime]::Parse($secret.lastRotated)
        $expiryDate = $lastRotated.AddDays($secret.rotationPolicyDays)
        $daysUntilExpiry = ($expiryDate - $ReferenceDate).Days

        if ($daysUntilExpiry -lt 0) {
            $status = 'expired'
        } elseif ($daysUntilExpiry -le $WarningDays) {
            $status = 'warning'
        } else {
            $status = 'ok'
        }

        [PSCustomObject]@{
            name              = $secret.name
            status            = $status
            daysUntilExpiry   = $daysUntilExpiry
            expiryDate        = $expiryDate
            requiredBy        = @($secret.requiredBy)
            rotationPolicyDays = $secret.rotationPolicyDays
        }
    }

    return $results
}

function Format-RotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Results,

        [Parameter(Mandatory)]
        [ValidateSet('json', 'markdown')]
        [string]$Format
    )

    if ($Format -notin @('json', 'markdown')) {
        throw "Unsupported format: '$Format'. Use 'json' or 'markdown'."
    }

    $expired = @($Results | Where-Object { $_.status -eq 'expired' })
    $warning = @($Results | Where-Object { $_.status -eq 'warning' })
    $ok      = @($Results | Where-Object { $_.status -eq 'ok' })

    switch ($Format) {
        'json' {
            $output = [PSCustomObject]@{
                summary = [PSCustomObject]@{
                    total   = $Results.Count
                    expired = $expired.Count
                    warning = $warning.Count
                    ok      = $ok.Count
                }
                secrets = @($Results | ForEach-Object {
                    [PSCustomObject]@{
                        name            = $_.name
                        status          = $_.status
                        daysUntilExpiry = $_.daysUntilExpiry
                        expiryDate      = $_.expiryDate.ToString('yyyy-MM-dd')
                        requiredBy      = @($_.requiredBy)
                        rotationPolicyDays = $_.rotationPolicyDays
                    }
                })
            }
            return ($output | ConvertTo-Json -Depth 5)
        }
        'markdown' {
            $lines = @()
            $lines += '# Secret Rotation Report'
            $lines += ''
            $lines += "**Total:** $($Results.Count) | **EXPIRED:** $($expired.Count) | **WARNING:** $($warning.Count) | **OK:** $($ok.Count)"
            $lines += ''
            $lines += '| Name | Status | Days Until Expiry | Expiry Date | Required By | Policy (days) |'
            $lines += '|------|--------|-------------------|-------------|-------------|---------------|'
            foreach ($r in $Results) {
                $services = ($r.requiredBy -join ', ')
                $lines += "| $($r.name) | $($r.status.ToUpper()) | $($r.daysUntilExpiry) | $($r.expiryDate.ToString('yyyy-MM-dd')) | $services | $($r.rotationPolicyDays) |"
            }

            $lines += ''
            $lines += '## Expired'
            $lines += ''
            if ($expired.Count -eq 0) { $lines += 'None.' }
            else {
                foreach ($s in $expired) {
                    $lines += "- **$($s.name)**: $([Math]::Abs($s.daysUntilExpiry)) days overdue, used by $($s.requiredBy -join ', ')"
                }
            }

            $lines += ''
            $lines += '## Warning'
            $lines += ''
            if ($warning.Count -eq 0) { $lines += 'None.' }
            else {
                foreach ($s in $warning) {
                    $lines += "- **$($s.name)**: expires in $($s.daysUntilExpiry) days, used by $($s.requiredBy -join ', ')"
                }
            }

            $lines += ''
            $lines += '## OK'
            $lines += ''
            if ($ok.Count -eq 0) { $lines += 'None.' }
            else {
                foreach ($s in $ok) {
                    $lines += "- **$($s.name)**: $($s.daysUntilExpiry) days remaining"
                }
            }

            return ($lines -join "`n")
        }
    }
}

function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [datetime]$ReferenceDate = (Get-Date),

        [int]$WarningDays = 14,

        [ValidateSet('json', 'markdown')]
        [string]$Format = 'json'
    )

    $secrets = Get-SecretConfig -Path $ConfigPath
    $results = Test-SecretRotation -Secrets $secrets -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    $report = Format-RotationReport -Results $results -Format $Format

    return $report
}
