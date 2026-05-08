# SecretRotationValidator
#
# Pure functions for classifying secrets by rotation urgency, plus a CLI entry
# point. Designed to be dot-sourced by tests and by the runner script.
#
# A "secret" is a hashtable / PSCustomObject with:
#   name                : string
#   lastRotated         : ISO date string (yyyy-MM-dd)
#   rotationPolicyDays  : int  -- max days between rotations
#   requiredBy          : string[]  -- services that consume the secret
#
# Status buckets:
#   expired : daysUntilExpiry <  0
#   warning : 0 <= daysUntilExpiry <= WarningDays
#   ok      : daysUntilExpiry >  WarningDays

Set-StrictMode -Version Latest

function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secret,
        [Parameter(Mandatory)] [datetime] $Now,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    $rawDate = $Secret.lastRotated
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$rawDate, [ref]$parsed)) {
        throw "Invalid lastRotated value '$rawDate' for secret '$($Secret.name)'"
    }

    $expiresOn = $parsed.AddDays([int]$Secret.rotationPolicyDays)
    $daysUntil = [int][math]::Floor(($expiresOn - $Now).TotalDays)

    $status =
        if ($daysUntil -lt 0)              { 'expired' }
        elseif ($daysUntil -le $WarningDays) { 'warning' }
        else                                { 'ok' }

    [pscustomobject]@{
        name             = [string]$Secret.name
        status           = $status
        lastRotated      = $parsed.ToString('yyyy-MM-dd')
        rotationPolicyDays = [int]$Secret.rotationPolicyDays
        daysUntilExpiry  = $daysUntil
        requiredBy       = @($Secret.requiredBy)
    }
}

function Invoke-SecretRotationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] [datetime] $Now,
        [Parameter(Mandatory)] [int] $WarningDays,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [string] $Format
    )

    if (-not $Config.PSObject.Properties.Match('secrets') -or $null -eq $Config.secrets) {
        throw "Config is missing required 'secrets' array"
    }

    $evaluated = foreach ($s in $Config.secrets) { Get-SecretStatus -Secret $s -Now $Now -WarningDays $WarningDays }
    $expired = @($evaluated | Where-Object status -EQ 'expired' | Sort-Object daysUntilExpiry)
    $warning = @($evaluated | Where-Object status -EQ 'warning' | Sort-Object daysUntilExpiry)
    $ok      = @($evaluated | Where-Object status -EQ 'ok'      | Sort-Object daysUntilExpiry)

    switch ($Format.ToLowerInvariant()) {
        'json' {
            return ([pscustomobject]@{
                generatedAt = $Now.ToString('yyyy-MM-ddTHH:mm:ssZ')
                warningDays = $WarningDays
                expired     = $expired
                warning     = $warning
                ok          = $ok
            } | ConvertTo-Json -Depth 6)
        }
        'markdown' {
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine("# Secret Rotation Report")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("Generated at: $($Now.ToString('yyyy-MM-dd'))  |  Warning window: $WarningDays days")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("| Name | Status | Days Until Expiry | Required By |")
            [void]$sb.AppendLine("|------|--------|-------------------|-------------|")
            foreach ($row in @($expired) + @($warning) + @($ok)) {
                $req = ($row.requiredBy -join ', ')
                [void]$sb.AppendLine("| $($row.name) | $($row.status) | $($row.daysUntilExpiry) | $req |")
            }
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("**Summary:** expired=$($expired.Count) warning=$($warning.Count) ok=$($ok.Count)")
            return $sb.ToString()
        }
        default {
            throw "Unsupported format '$Format' (expected: json, markdown)"
        }
    }
}

function Invoke-SecretRotationValidatorCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [int] $WarningDays = 7,
        [ValidateSet('json','markdown')] [string] $Format = 'markdown',
        [datetime] $Now = (Get-Date),
        [switch] $PassThru
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $config = $raw | ConvertFrom-Json -Depth 10
    } catch {
        throw "Failed to parse JSON config '$ConfigPath': $($_.Exception.Message)"
    }

    $report = Invoke-SecretRotationReport -Config $config -Now $Now -WarningDays $WarningDays -Format $Format

    # Determine if any secret is expired (used by callers to set a non-zero exit
    # code, e.g. fail a CI job when rotation is overdue).
    $hasExpired = $false
    foreach ($s in $config.secrets) {
        $st = Get-SecretStatus -Secret $s -Now $Now -WarningDays $WarningDays
        if ($st.status -eq 'expired') { $hasExpired = $true; break }
    }

    if ($PassThru) {
        return [pscustomobject]@{ Output = $report; HasExpired = $hasExpired }
    }
    return $report
}
