# Secret Rotation Validator
#
# Reads a JSON config of secrets (mock data) and reports rotation status
# bucketed by urgency: expired, warning, ok. Outputs as markdown, JSON,
# or a raw object.
#
# All time logic is driven by an explicit -AsOfDate parameter so tests
# (and CI) are deterministic regardless of when they run.

Set-StrictMode -Version Latest

function Get-SecretRotationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secret,
        [Parameter(Mandatory)] [datetime] $AsOfDate,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    foreach ($field in 'name','lastRotated','rotationPolicyDays') {
        if (-not ($Secret.PSObject.Properties.Name -contains $field)) {
            throw "Secret is missing required field '$field'."
        }
    }

    try {
        $lastRotated = [datetime]::Parse($Secret.lastRotated)
    } catch {
        throw "Secret '$($Secret.name)' has invalid lastRotated value '$($Secret.lastRotated)'."
    }

    $policyDays      = [int]$Secret.rotationPolicyDays
    $daysSince       = [int]([math]::Floor(($AsOfDate - $lastRotated).TotalDays))
    $daysUntilExpiry = $policyDays - $daysSince

    $status = if ($daysUntilExpiry -le 0) { 'expired' }
              elseif ($daysUntilExpiry -le $WarningDays) { 'warning' }
              else { 'ok' }

    [pscustomobject]@{
        name             = $Secret.name
        lastRotated      = $lastRotated.ToString('yyyy-MM-dd')
        rotationPolicyDays = $policyDays
        requiredBy       = @($Secret.requiredBy)
        daysSinceRotation = $daysSince
        DaysUntilExpiry  = $daysUntilExpiry
        Status           = $status
    }
}

function Format-RotationReportMarkdown {
    param([Parameter(Mandatory)] $Report)

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Secret Rotation Report")
    $lines.Add("")
    $lines.Add("- As of: $($Report.asOfDate)")
    $lines.Add("- Warning window: $($Report.warningDays) days")
    $lines.Add("- Expired: $($Report.summary.expired) | Warning: $($Report.summary.warning) | OK: $($Report.summary.ok)")
    $lines.Add("")

    foreach ($section in @(
        @{ Title = '## Expired'; Items = $Report.expired },
        @{ Title = '## Warning'; Items = $Report.warning },
        @{ Title = '## OK';      Items = $Report.ok }
    )) {
        $lines.Add($section.Title)
        $lines.Add("")
        $lines.Add("| Name | Last Rotated | Days Until Expiry | Required By |")
        $lines.Add("|------|--------------|-------------------|-------------|")
        if ($section.Items.Count -eq 0) {
            $lines.Add("| _(none)_ | | | |")
        } else {
            foreach ($s in $section.Items) {
                $required = ($s.requiredBy -join ', ')
                $lines.Add("| $($s.name) | $($s.lastRotated) | $($s.DaysUntilExpiry) | $required |")
            }
        }
        $lines.Add("")
    }

    return ($lines -join "`n")
}

function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [int] $WarningDays = 14,
        [datetime] $AsOfDate = (Get-Date),
        [ValidateSet('markdown','json','object')] [string] $Format = 'markdown'
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    try {
        $raw = Get-Content -LiteralPath $ConfigPath -Raw
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse config '$ConfigPath': $($_.Exception.Message)"
    }

    if (-not ($config.PSObject.Properties.Name -contains 'secrets')) {
        throw "Config '$ConfigPath' is missing required 'secrets' array."
    }

    $evaluated = foreach ($s in $config.secrets) {
        Get-SecretRotationStatus -Secret $s -AsOfDate $AsOfDate -WarningDays $WarningDays
    }

    # Within each bucket, sort the most-urgent (smallest days-until-expiry) first
    # so report consumers see the worst offenders at the top.
    $expired = @($evaluated | Where-Object Status -eq 'expired' | Sort-Object DaysUntilExpiry)
    $warning = @($evaluated | Where-Object Status -eq 'warning' | Sort-Object DaysUntilExpiry)
    $ok      = @($evaluated | Where-Object Status -eq 'ok'      | Sort-Object DaysUntilExpiry)

    $report = [pscustomobject]@{
        asOfDate    = $AsOfDate.ToString('yyyy-MM-dd')
        warningDays = $WarningDays
        summary     = [pscustomobject]@{
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
            total   = $evaluated.Count
        }
        expired = $expired
        warning = $warning
        ok      = $ok
    }

    switch ($Format) {
        'object'   { return $report }
        'json'     { return ($report | ConvertTo-Json -Depth 6) }
        'markdown' { return Format-RotationReportMarkdown -Report $report }
    }
}

Export-ModuleMember -Function Get-SecretRotationStatus, Invoke-SecretRotationValidator, Format-RotationReportMarkdown
