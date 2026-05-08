# SecretRotationValidator.ps1
#
# Validates a configuration of secrets against rotation policies and produces
# a report grouped by urgency: expired / warning / ok. Output formats:
# markdown (default) or json.
#
# Built via red/green TDD against SecretRotationValidator.Tests.ps1 — each
# function below has corresponding unit tests there.

[CmdletBinding()]
param(
    [string] $ConfigPath,
    [ValidateSet('markdown','json')]
    [string] $Format = 'markdown',
    [int]    $WarningWindowDays = 14,
    [datetime] $Now = (Get-Date),
    [switch] $FailOnExpired
)

function Get-SecretRotationStatus {
    # Classify a single secret as expired/warning/ok and compute days-until-due.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secret,
        [Parameter(Mandatory)] [datetime] $Now,
        [Parameter(Mandatory)] [int] $WarningWindowDays
    )

    if (-not $Secret.PSObject.Properties['name'] -or [string]::IsNullOrWhiteSpace([string]$Secret.name)) {
        throw "Secret is missing required field 'name'."
    }
    $name = [string]$Secret.name

    if ([int]$Secret.rotationPolicyDays -le 0) {
        throw "Secret '$name' has invalid rotationPolicyDays (must be > 0)."
    }

    $rotated = $null
    try {
        $rotated = [datetime]::Parse([string]$Secret.lastRotated, [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        throw "Secret '$name' has invalid lastRotated value '$($Secret.lastRotated)'."
    }

    $dueDate = $rotated.AddDays([int]$Secret.rotationPolicyDays)
    $daysUntilDue = [int][math]::Floor(($dueDate - $Now).TotalDays)

    $urgency = if ($daysUntilDue -lt 0) { 'expired' }
               elseif ($daysUntilDue -le $WarningWindowDays) { 'warning' }
               else { 'ok' }

    [pscustomobject]@{
        name               = $name
        lastRotated        = $rotated.ToString('yyyy-MM-dd')
        rotationPolicyDays = [int]$Secret.rotationPolicyDays
        requiredBy         = @($Secret.requiredBy)
        dueDate            = $dueDate.ToString('yyyy-MM-dd')
        daysUntilDue       = $daysUntilDue
        urgency            = $urgency
    }
}

function Get-SecretRotationReport {
    # Group classified secrets into expired/warning/ok buckets, sorted by urgency.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] [datetime] $Now,
        [Parameter(Mandatory)] [int] $WarningWindowDays
    )

    if (-not $Config.PSObject.Properties['secrets']) {
        throw "Config is missing required 'secrets' array."
    }

    $classified = foreach ($s in $Config.secrets) {
        Get-SecretRotationStatus -Secret $s -Now $Now -WarningWindowDays $WarningWindowDays
    }

    $expired = @($classified | Where-Object urgency -eq 'expired' | Sort-Object daysUntilDue)
    $warning = @($classified | Where-Object urgency -eq 'warning' | Sort-Object daysUntilDue)
    $ok      = @($classified | Where-Object urgency -eq 'ok'      | Sort-Object daysUntilDue)

    [pscustomobject]@{
        generatedAt       = $Now.ToString('yyyy-MM-dd')
        warningWindowDays = $WarningWindowDays
        summary = [pscustomobject]@{
            total   = ($classified | Measure-Object).Count
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
    # Render a report as JSON or markdown.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Report,
        [Parameter(Mandatory)] [string] $Format
    )

    switch ($Format.ToLowerInvariant()) {
        'json' {
            return ($Report | ConvertTo-Json -Depth 6)
        }
        'markdown' {
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine("# Secret Rotation Report")
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("- Generated: $($Report.generatedAt)")
            [void]$sb.AppendLine("- Warning window: $($Report.warningWindowDays) days")
            [void]$sb.AppendLine("- Total: $($Report.summary.total) (expired: $($Report.summary.expired), warning: $($Report.summary.warning), ok: $($Report.summary.ok))")
            [void]$sb.AppendLine("")
            foreach ($section in @(
                @{ Title='Expired'; Items=$Report.expired },
                @{ Title='Warning'; Items=$Report.warning },
                @{ Title='OK';      Items=$Report.ok }
            )) {
                [void]$sb.AppendLine("## $($section.Title) ($($section.Items.Count))")
                [void]$sb.AppendLine("")
                if ($section.Items.Count -eq 0) {
                    [void]$sb.AppendLine("_None_")
                    [void]$sb.AppendLine("")
                    continue
                }
                [void]$sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Due | Required By |")
                [void]$sb.AppendLine("| --- | --- | --- | --- | --- |")
                foreach ($it in $section.Items) {
                    $required = ($it.requiredBy -join ', ')
                    [void]$sb.AppendLine("| $($it.name) | $($it.lastRotated) | $($it.rotationPolicyDays) | $($it.daysUntilDue) | $required |")
                }
                [void]$sb.AppendLine("")
            }
            return $sb.ToString().TrimEnd()
        }
        default {
            throw "Unsupported format '$Format'. Supported: markdown, json."
        }
    }
}

function Invoke-SecretRotationValidator {
    # Top-level entrypoint: load config, build report, format, and optionally
    # signal failure if expired secrets exist.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [string]   $Format = 'markdown',
        [int]      $WarningWindowDays = 14,
        [datetime] $Now = (Get-Date),
        [switch]   $FailOnExpired,
        [switch]   $PassThru
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    try {
        $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse config '$ConfigPath' as JSON: $($_.Exception.Message)"
    }

    $report = Get-SecretRotationReport -Config $config -Now $Now -WarningWindowDays $WarningWindowDays
    $output = Format-RotationReport -Report $report -Format $Format

    $exitCode = 0
    if ($FailOnExpired -and $report.summary.expired -gt 0) {
        $exitCode = 2
    }

    if ($PassThru) {
        return [pscustomobject]@{
            Output   = $output
            Report   = $report
            ExitCode = $exitCode
        }
    }
    return $output
}

# When executed as a script (not dot-sourced), run the entrypoint and exit
# with the appropriate code so the workflow can fail on expired secrets.
if ($MyInvocation.InvocationName -ne '.' -and $PSCommandPath -and $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
    if (-not $ConfigPath) {
        Write-Error "ConfigPath is required when running the script directly."
        exit 64
    }
    $result = Invoke-SecretRotationValidator -ConfigPath $ConfigPath -Format $Format `
        -WarningWindowDays $WarningWindowDays -Now $Now -FailOnExpired:$FailOnExpired -PassThru
    Write-Output $result.Output
    exit $result.ExitCode
}
