Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# SecretRotationValidator
# -----------------------
# Pure functions for classifying secrets against a rotation policy.
# The module keeps date arithmetic in one place (ConvertTo-LocalDate) so that
# parsing / error handling is identical between single-secret and report calls.

function ConvertTo-LocalDate {
    # Parse an incoming string or DateTime into a DateTime (date component only).
    # Callers pass the original raw value in -Context so the error message
    # points at the offending input rather than "".
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Value,
        [Parameter(Mandatory)] [string] $Context
    )
    if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
        throw "Missing value for '$Context'."
    }
    if ($Value -is [datetime]) { return $Value.Date }
    $parsed = [datetime]::MinValue
    $fmt = 'yyyy-MM-dd'
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::AssumeLocal
    if ([datetime]::TryParseExact([string]$Value, $fmt, $culture, $styles, [ref]$parsed)) {
        return $parsed.Date
    }
    if ([datetime]::TryParse([string]$Value, $culture, $styles, [ref]$parsed)) {
        return $parsed.Date
    }
    throw "Invalid date '$Value' for '$Context' (expected yyyy-MM-dd)."
}

function Get-SecretStatus {
    # Classify a single secret. The rotation-due date is lastRotated + policy.
    # Status is: expired (due <= ref), warning (due within WarningDays), ok otherwise.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Secret,
        [Parameter(Mandatory)] $ReferenceDate,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    # Validate inputs with messages that reference the offending field by name,
    # so the Pester tests (and end users) get actionable errors.
    foreach ($field in 'name','lastRotated','rotationPolicyDays') {
        if (-not ($Secret.PSObject.Properties.Name -contains $field)) {
            throw "Secret is missing required field '$field'."
        }
    }
    $policy = [int]$Secret.rotationPolicyDays
    if ($policy -le 0) {
        throw "Invalid rotationPolicyDays '$($Secret.rotationPolicyDays)' for secret '$($Secret.name)': must be > 0."
    }

    $last = ConvertTo-LocalDate -Value $Secret.lastRotated -Context "secret '$($Secret.name)' lastRotated"
    $ref  = ConvertTo-LocalDate -Value $ReferenceDate      -Context 'ReferenceDate'
    $due  = $last.AddDays($policy)
    $days = [int]([math]::Floor(($due - $ref).TotalDays))

    $status = if ($days -lt 0) { 'expired' }
              elseif ($days -le $WarningDays) { 'warning' }
              else { 'ok' }

    # requiredBy is optional; normalize to an array either way.
    $required = @()
    if ($Secret.PSObject.Properties.Name -contains 'requiredBy' -and $null -ne $Secret.requiredBy) {
        $required = @($Secret.requiredBy)
    }

    [pscustomobject]@{
        Name              = [string]$Secret.name
        LastRotated       = $last.ToString('yyyy-MM-dd')
        RotationPolicyDays = $policy
        DueDate           = $due.ToString('yyyy-MM-dd')
        DaysUntilRotation = $days
        Status            = $status
        RequiredBy        = $required
    }
}

function Get-RotationReport {
    # Classify every secret and group by urgency bucket. Expired is sorted most-
    # overdue first; Warning is sorted soonest-expiring first; Ok is by name for
    # stable output across runs.
    [CmdletBinding()]
    param(
        # Allow null/empty so an empty secrets list (e.g. fresh project)
        # produces a valid "all-clear" report rather than a binding error.
        # PowerShell collapses @() to $null at the binding boundary, so we
        # need both AllowNull and AllowEmptyCollection.
        [Parameter(Mandatory)] [AllowNull()] [AllowEmptyCollection()] [object[]] $Secrets,
        [Parameter(Mandatory)] $ReferenceDate,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    $classified = @(
        foreach ($s in $Secrets) {
            Get-SecretStatus -Secret $s -ReferenceDate $ReferenceDate -WarningDays $WarningDays
        }
    )

    # Force arrays with the comma operator so empty buckets stay [object[]] and
    # not $null — important for JSON serialisation and consumer code.
    $expired = ,@( $classified | Where-Object Status -EQ 'expired' | Sort-Object DaysUntilRotation )
    $warning = ,@( $classified | Where-Object Status -EQ 'warning' | Sort-Object DaysUntilRotation )
    $ok      = ,@( $classified | Where-Object Status -EQ 'ok'      | Sort-Object Name )

    [pscustomobject]@{
        ReferenceDate = (ConvertTo-LocalDate -Value $ReferenceDate -Context 'ReferenceDate').ToString('yyyy-MM-dd')
        WarningDays   = $WarningDays
        TotalSecrets  = @($classified).Count
        Expired       = $expired[0]
        Warning       = $warning[0]
        Ok            = $ok[0]
    }
}

function Format-RotationReport {
    # Render a report as Markdown (human-readable, one table per bucket) or
    # JSON (machine-readable, preserves the whole report).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report,
        [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format
    )

    if ($Format -eq 'json') {
        return ($Report | ConvertTo-Json -Depth 6)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Secret Rotation Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("- Reference date: $($Report.ReferenceDate)")
    [void]$sb.AppendLine("- Warning window: $($Report.WarningDays) days")
    [void]$sb.AppendLine("- Total secrets:  $($Report.TotalSecrets)")
    [void]$sb.AppendLine("- Expired:        $(@($Report.Expired).Count)")
    [void]$sb.AppendLine("- Warning:        $(@($Report.Warning).Count)")
    [void]$sb.AppendLine("- Ok:             $(@($Report.Ok).Count)")
    [void]$sb.AppendLine("")

    $sections = @(
        @{ Title = 'Expired'; Items = $Report.Expired }
        @{ Title = 'Warning'; Items = $Report.Warning }
        @{ Title = 'Ok';      Items = $Report.Ok      }
    )
    foreach ($section in $sections) {
        [void]$sb.AppendLine("## $($section.Title) ($(@($section.Items).Count))")
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("| Name | Last Rotated | Policy (days) | Days Until Rotation | Required By |")
        [void]$sb.AppendLine("|------|--------------|---------------|---------------------|-------------|")
        foreach ($item in @($section.Items)) {
            $required = ($item.RequiredBy -join ', ')
            [void]$sb.AppendLine("| $($item.Name) | $($item.LastRotated) | $($item.RotationPolicyDays) | $($item.DaysUntilRotation) | $required |")
        }
        [void]$sb.AppendLine("")
    }
    return $sb.ToString().TrimEnd()
}

function Invoke-SecretRotationValidator {
    # Top-level orchestrator: read secrets from a JSON file, build the report,
    # render it, and return both the rendered text and an exit-code hint.
    # Exit codes: 0 = all ok, 1 = warnings only, 2 = at least one expired.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [Parameter(Mandatory)] $ReferenceDate,
        [Parameter(Mandatory)] [int] $WarningDays,
        [Parameter(Mandatory)] [ValidateSet('markdown','json')] [string] $Format
    )

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON config '$ConfigPath': $($_.Exception.Message)"
    }

    # Accept either a bare array or an object with a 'secrets' property.
    # PowerShell's ConvertFrom-Json returns $null for an empty JSON array ("[]"),
    # so normalize that to an empty collection before dispatching on shape.
    $secrets = if ($null -eq $parsed) { @() }
               elseif ($parsed -is [System.Array]) { $parsed }
               elseif ($parsed.PSObject.Properties.Name -contains 'secrets') { @($parsed.secrets) }
               else { @($parsed) }

    $report = Get-RotationReport -Secrets $secrets -ReferenceDate $ReferenceDate -WarningDays $WarningDays
    $output = Format-RotationReport -Report $report -Format $Format

    $exit = if (@($report.Expired).Count -gt 0) { 2 }
            elseif (@($report.Warning).Count -gt 0) { 1 }
            else { 0 }

    [pscustomobject]@{
        Report   = $report
        Output   = $output
        ExitCode = $exit
    }
}

Export-ModuleMember -Function Get-SecretStatus, Get-RotationReport, Format-RotationReport, Invoke-SecretRotationValidator
