<#
.SYNOPSIS
    Secret Rotation Validator: classify secrets as expired / warning / ok and
    emit a rotation report in markdown or JSON.

.DESCRIPTION
    Reads a JSON config describing secrets (name, lastRotated, rotationPolicyDays,
    requiredBy), then for each secret computes daysUntilExpiry against an "as-of"
    date (today by default) and groups them by urgency.

    The script is dot-source friendly: loading it makes the helper functions
    available without running the CLI. The CLI runs only when -Config is supplied
    or the -Run switch is set, so Pester can dot-source for unit tests.

.PARAMETER Config
    Path to the secrets JSON config file.

.PARAMETER WarningDays
    Threshold (in days) for the "warning" bucket. Secrets whose daysUntilExpiry is
    between 0 and this value (inclusive) are classified as warning.

.PARAMETER AsOf
    The reference date for expiry calculation (yyyy-MM-dd). Defaults to today.
    Exposed so tests are deterministic.

.PARAMETER Format
    Output format: 'markdown' (default) or 'json'.
#>
[CmdletBinding()]
param(
    [string]$Config,
    [int]$WarningDays = 14,
    [string]$AsOf,
    [ValidateSet('markdown', 'json')]
    [string]$Format = 'markdown'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Date {
    param([Parameter(Mandatory)][string]$Value)
    # Parse a yyyy-MM-dd date string into a [datetime]. Centralised so date
    # parsing failures produce a single, consistent error message.
    try {
        return [datetime]::ParseExact(
            $Value, 'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture
        )
    } catch {
        throw "Invalid date '$Value' (expected yyyy-MM-dd): $($_.Exception.Message)"
    }
}

function Read-SecretConfig {
    <#
    .SYNOPSIS
        Load a JSON config of secrets from disk.
    .DESCRIPTION
        The config must be an object with a top-level 'secrets' array. Each
        element is passed straight through to Get-SecretRotationStatus, which
        does the per-secret field validation.
    #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse config '$Path' as JSON: $($_.Exception.Message)"
    }

    # Iterate via ForEach-Object so an empty PSObject (no properties) doesn't
    # blow up under Set-StrictMode -Version Latest, where indexing into an
    # empty collection's .Name property is treated as a missing-member error.
    $topLevelNames = @($parsed.PSObject.Properties | ForEach-Object { $_.Name })
    if ($topLevelNames -notcontains 'secrets') {
        throw "Config '$Path' must contain a top-level 'secrets' array."
    }

    # Wrap with @() so a single-item secrets list is still iterable as an array.
    return @($parsed.secrets)
}

function Get-SecretRotationStatus {
    <#
    .SYNOPSIS
        Classify a single secret by its days-until-expiry.
    .DESCRIPTION
        Buckets:
          expired  — daysUntilExpiry < 0
          warning  — 0 <= daysUntilExpiry <= WarningDays
          ok       — daysUntilExpiry > WarningDays
    #>
    param(
        [Parameter(Mandatory)][object]$Secret,
        [Parameter(Mandatory)][string]$AsOf,
        [Parameter(Mandatory)][int]$WarningDays
    )

    $present = @($Secret.PSObject.Properties | ForEach-Object { $_.Name })
    foreach ($field in 'name', 'lastRotated', 'rotationPolicyDays') {
        if ($present -notcontains $field) {
            throw "Secret is missing required field '$field'."
        }
    }
    if ($Secret.rotationPolicyDays -le 0) {
        throw "Secret '$($Secret.name)' has non-positive rotationPolicyDays: $($Secret.rotationPolicyDays)."
    }

    $lastRotated = ConvertTo-Date $Secret.lastRotated
    $asOfDate    = ConvertTo-Date $AsOf
    $expiresAt   = $lastRotated.AddDays($Secret.rotationPolicyDays)
    $daysUntilExpiry = [int]($expiresAt - $asOfDate).TotalDays

    $status = if ($daysUntilExpiry -lt 0) { 'expired' }
              elseif ($daysUntilExpiry -le $WarningDays) { 'warning' }
              else { 'ok' }

    # Type as string[] so a single-element value isn't unwrapped to a scalar
    # when assigned into the pscustomobject below (PowerShell silently unwraps
    # 1-element arrays during certain expression assignments).
    [string[]]$requiredBy = @()
    if (($present -contains 'requiredBy') -and $null -ne $Secret.requiredBy) {
        [string[]]$requiredBy = @($Secret.requiredBy)
    }

    [pscustomobject]@{
        name               = $Secret.name
        lastRotated        = $Secret.lastRotated
        rotationPolicyDays = [int]$Secret.rotationPolicyDays
        expiresAt          = $expiresAt.ToString('yyyy-MM-dd')
        daysUntilExpiry    = $daysUntilExpiry
        status             = $status
        requiredBy         = $requiredBy
    }
}

function Get-RotationReport {
    <#
    .SYNOPSIS
        Build a rotation report from a list of secrets, grouped by urgency.
    .DESCRIPTION
        Each secret is classified via Get-SecretRotationStatus, then placed in
        one of three buckets: expired, warning, ok. Within each bucket, the
        most-urgent secret (smallest daysUntilExpiry) comes first so that human
        readers see the items that need attention soonest.
    #>
    param(
        [Parameter(Mandatory)][object[]]$Secrets,
        [Parameter(Mandatory)][string]$AsOf,
        [Parameter(Mandatory)][int]$WarningDays
    )

    $classified = foreach ($s in $Secrets) {
        Get-SecretRotationStatus -Secret $s -AsOf $AsOf -WarningDays $WarningDays
    }

    # Force into arrays so a single-member or empty bucket still serialises as
    # a JSON array rather than a scalar / null.
    $expired = @($classified | Where-Object { $_.status -eq 'expired' } | Sort-Object daysUntilExpiry)
    $warning = @($classified | Where-Object { $_.status -eq 'warning' } | Sort-Object daysUntilExpiry)
    $ok      = @($classified | Where-Object { $_.status -eq 'ok' }      | Sort-Object daysUntilExpiry)

    [pscustomobject]@{
        asOf        = $AsOf
        warningDays = $WarningDays
        counts      = [pscustomobject]@{
            expired = $expired.Count
            warning = $warning.Count
            ok      = $ok.Count
            total   = $expired.Count + $warning.Count + $ok.Count
        }
        expired     = $expired
        warning     = $warning
        ok          = $ok
    }
}

function Format-RotationReportMarkdown {
    <#
    .SYNOPSIS
        Render a rotation report as a markdown document with a section per bucket.
    #>
    param([Parameter(Mandatory)][object]$Report)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("Generated as of **$($Report.asOf)** with a warning window of **$($Report.warningDays)** days.")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("**Summary**: Expired: **$($Report.counts.expired)**, Warning: **$($Report.counts.warning)**, OK: **$($Report.counts.ok)** (total: $($Report.counts.total)).")
    [void]$sb.AppendLine()

    foreach ($bucket in @(
        @{ Title = 'Expired'; Items = $Report.expired }
        @{ Title = 'Warning'; Items = $Report.warning }
        @{ Title = 'OK';      Items = $Report.ok      }
    )) {
        [void]$sb.AppendLine("## $($bucket.Title) ($($bucket.Items.Count))")
        [void]$sb.AppendLine()
        if ($bucket.Items.Count -eq 0) {
            [void]$sb.AppendLine('_None_')
        } else {
            [void]$sb.AppendLine('| Name | Last Rotated | Expires | Days | Required By |')
            [void]$sb.AppendLine('|------|--------------|---------|------|-------------|')
            foreach ($s in $bucket.Items) {
                $reqBy = if ($s.requiredBy.Count -gt 0) { $s.requiredBy -join ', ' } else { '-' }
                [void]$sb.AppendLine("| $($s.name) | $($s.lastRotated) | $($s.expiresAt) | $($s.daysUntilExpiry) | $reqBy |")
            }
        }
        [void]$sb.AppendLine()
    }

    return $sb.ToString().TrimEnd("`r","`n")
}

function Format-RotationReportJson {
    <#
    .SYNOPSIS
        Render a rotation report as a pretty-printed JSON string.
    .DESCRIPTION
        Uses ConvertTo-Json with sufficient depth to capture nested fields and
        the requiredBy arrays. Empty buckets serialise as [] (not null) thanks
        to the @(...) wrapping in Get-RotationReport.
    #>
    param([Parameter(Mandatory)][object]$Report)
    return $Report | ConvertTo-Json -Depth 6
}

function Invoke-SecretRotationValidator {
    <#
    .SYNOPSIS
        Top-level orchestration: load config, build report, render in chosen format.
    .OUTPUTS
        Returns a hashtable with `Output` (the rendered string) and `ExitCode`
        (0 = all ok, 1 = warnings present, 2 = expired present). The script
        wrapper at the bottom of this file is what actually exits the process.
    #>
    param(
        [Parameter(Mandatory)][string]$Config,
        [Parameter(Mandatory)][string]$AsOf,
        [Parameter(Mandatory)][int]$WarningDays,
        [Parameter(Mandatory)][ValidateSet('markdown','json')][string]$Format
    )

    $secrets = Read-SecretConfig -Path $Config
    $report  = Get-RotationReport -Secrets $secrets -AsOf $AsOf -WarningDays $WarningDays

    $rendered = switch ($Format) {
        'markdown' { Format-RotationReportMarkdown -Report $report }
        'json'     { Format-RotationReportJson     -Report $report }
    }

    $exitCode = if ($report.counts.expired -gt 0) { 2 }
                elseif ($report.counts.warning -gt 0) { 1 }
                else { 0 }

    return @{ Output = $rendered; ExitCode = $exitCode; Report = $report }
}

# ----------------------------------------------------------------------------
# CLI dispatch
# ----------------------------------------------------------------------------
# Run the CLI only when invoked as a script (i.e., -Config was passed).
# Dot-sourcing for tests passes no parameters, so this block is skipped and the
# helper functions are simply made available in the caller's scope.
if ($PSBoundParameters.ContainsKey('Config') -or -not [string]::IsNullOrEmpty($Config)) {
    try {
        $effectiveAsOf = if ([string]::IsNullOrEmpty($AsOf)) {
            (Get-Date).ToString('yyyy-MM-dd')
        } else { $AsOf }

        $result = Invoke-SecretRotationValidator `
            -Config $Config `
            -AsOf $effectiveAsOf `
            -WarningDays $WarningDays `
            -Format $Format

        # Write the rendered report to stdout. Use Write-Output so the caller
        # captures it cleanly through pipes / file redirects.
        Write-Output $result.Output
        exit $result.ExitCode
    } catch {
        # Exit code 3 distinguishes config / runtime errors from "found expired
        # secrets" (2) or "warnings only" (1) so a CI step can react accordingly.
        [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
        exit 3
    }
}
