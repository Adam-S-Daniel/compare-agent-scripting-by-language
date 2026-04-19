<#
.SYNOPSIS
Secret rotation validator that identifies expired or expiring secrets.

.DESCRIPTION
Processes secret configurations with metadata and generates rotation reports
grouped by urgency. Supports multiple output formats (Markdown, JSON).

.PARAMETER SecretConfigs
Array of secret configuration objects with name, lastRotated, rotationPolicyDays, requiredByServices.

.PARAMETER WarningWindowDays
Number of days before expiration to generate warning (default: 7).

.PARAMETER OutputFormat
Output format: 'markdown', 'json', or 'both' (default: 'both').

.PARAMETER AsOf
Reference date for calculations (default: today).
#>

param(
    [Parameter(Mandatory = $false)]
    [Array]$SecretConfigs = @(),

    [Parameter(Mandatory = $false)]
    [int]$WarningWindowDays = 7,

    [Parameter(Mandatory = $false)]
    [ValidateSet('markdown', 'json', 'both')]
    [string]$OutputFormat = 'both',

    [Parameter(Mandatory = $false)]
    [datetime]$AsOf = (Get-Date)
)

<#
.DESCRIPTION
Calculates expiration status for a given secret.
Returns: 'expired', 'warning', or 'ok'
#>
function Get-SecretStatus {
    param(
        [hashtable]$Secret,
        [datetime]$ReferenceDate,
        [int]$WarningWindow
    )

    [datetime]$lastRotated = [datetime]::ParseExact($Secret.lastRotated, 'yyyy-MM-dd', $null)
    $expirationDate = $lastRotated.AddDays($Secret.rotationPolicyDays)
    $daysUntilExpiration = ($expirationDate - $ReferenceDate).Days

    if ($daysUntilExpiration -lt 0) {
        return 'expired'
    }
    elseif ($daysUntilExpiration -le $WarningWindow) {
        return 'warning'
    }
    else {
        return 'ok'
    }
}

<#
.DESCRIPTION
Generates rotation report with status information.
#>
function Get-RotationReport {
    param(
        [Array]$Secrets,
        [datetime]$ReferenceDate,
        [int]$WarningWindow
    )

    $report = @{
        expired = @()
        warning = @()
        ok = @()
    }

    foreach ($secret in $Secrets) {
        $status = Get-SecretStatus -Secret $secret -ReferenceDate $ReferenceDate -WarningWindow $WarningWindow

        [datetime]$lastRotated = [datetime]::ParseExact($secret.lastRotated, 'yyyy-MM-dd', $null)
        $expirationDate = $lastRotated.AddDays($secret.rotationPolicyDays)
        $daysUntilExpiration = ($expirationDate - $ReferenceDate).Days

        $secretInfo = @{
            name = $secret.name
            lastRotated = $secret.lastRotated
            expirationDate = $expirationDate.ToString('yyyy-MM-dd')
            daysUntilExpiration = $daysUntilExpiration
            rotationPolicy = $secret.rotationPolicyDays
            requiredByServices = $secret.requiredByServices
        }

        $report[$status] += $secretInfo
    }

    return $report
}

<#
.DESCRIPTION
Generates Markdown table format output.
#>
function Get-MarkdownReport {
    param(
        [hashtable]$Report
    )

    $output = @()

    $output += "# Secret Rotation Report"
    $output += ""

    foreach ($urgency in @('expired', 'warning', 'ok')) {
        $count = $Report[$urgency].Count
        $output += "## $([System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($urgency)) ($count)"
        $output += ""

        if ($count -gt 0) {
            $output += "| Name | Last Rotated | Expires | Days Until | Services |"
            $output += "|------|--------------|---------|------------|----------|"

            foreach ($secret in $Report[$urgency]) {
                $services = $secret.requiredByServices -join ', '
                $output += "| $($secret.name) | $($secret.lastRotated) | $($secret.expirationDate) | $($secret.daysUntilExpiration) | $services |"
            }

            $output += ""
        }
    }

    return $output -join "`n"
}

<#
.DESCRIPTION
Generates JSON format output.
#>
function Get-JsonReport {
    param(
        [hashtable]$Report
    )

    return $Report | ConvertTo-Json -Depth 10
}

if ($SecretConfigs.Count -gt 0) {
    $report = Get-RotationReport -Secrets $SecretConfigs -ReferenceDate $AsOf -WarningWindow $WarningWindowDays

    if ($OutputFormat -in @('markdown', 'both')) {
        Write-Output (Get-MarkdownReport -Report $report)
    }

    if ($OutputFormat -in @('json', 'both')) {
        Write-Output (Get-JsonReport -Report $report)
    }
}
