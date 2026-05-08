<#
.SYNOPSIS
    Validates secret rotation freshness against per-secret rotation policies.

.DESCRIPTION
    Reads a JSON configuration of secrets (each with name, lastRotated date,
    rotationPolicyDays, and requiredBy services), classifies each secret by
    urgency relative to a reference date (`today`) and a configurable
    `warningDays` window, then emits a rotation report grouped by urgency:

      - expired : daysUntilExpiry <= 0
      - warning : 0 < daysUntilExpiry <= warningDays
      - ok      : daysUntilExpiry > warningDays

    Emits sentinel markers (::ROTATION_REPORT_BEGIN::/::ROTATION_REPORT_END::)
    so downstream tooling can extract just the report lines from a noisy log.

.PARAMETER ConfigPath
    Path to the secrets JSON config. The config may itself carry `today`,
    `warningDays`, and `format` fields (defaults below) plus a `secrets` array.

.PARAMETER Format
    'markdown' (default) or 'json'. Overrides the value in the config file.

.PARAMETER Today
    ISO date 'yyyy-MM-dd' used as the reference "today". Defaults to system
    date. Set explicitly so the report is reproducible (and tests deterministic).

.PARAMETER WarningDays
    Days-to-expiry threshold for the WARNING bucket. -1 means "use config".

.PARAMETER FailOnExpired
    If set, exits with code 2 when any secret is expired. Useful in CI gates.
    Default off so the workflow can produce a report without failing.

.EXAMPLE
    pwsh ./Invoke-SecretRotationValidator.ps1 -ConfigPath secrets.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [ValidateSet('markdown', 'json', '')]
    [string]$Format = '',

    [string]$Today = '',

    [int]$WarningDays = -1,

    [switch]$FailOnExpired
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-Config {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        return $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Failed to parse JSON from '$Path': $($_.Exception.Message)"
    }
}

function ConvertTo-IsoDate {
    # Parse a 'yyyy-MM-dd' string strictly, throwing a helpful error on failure.
    param([string]$Value, [string]$FieldName)
    try {
        return [DateTime]::ParseExact($Value, 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    } catch {
        throw "Invalid date for ${FieldName}: '$Value' (expected yyyy-MM-dd)"
    }
}

function Get-SecretClassification {
    # Compute urgency for a single secret entry.
    param(
        [Parameter(Mandatory = $true)] $Secret,
        [Parameter(Mandatory = $true)] [DateTime]$TodayDate,
        [Parameter(Mandatory = $true)] [int]$WarningDays
    )
    foreach ($field in @('name', 'lastRotated', 'rotationPolicyDays')) {
        if (-not $Secret.PSObject.Properties[$field]) {
            throw "Secret entry missing required field '$field'"
        }
    }

    $lastRotated = ConvertTo-IsoDate -Value $Secret.lastRotated -FieldName "secret '$($Secret.name)' lastRotated"
    $policy = [int]$Secret.rotationPolicyDays
    if ($policy -le 0) {
        throw "Secret '$($Secret.name)' has invalid rotationPolicyDays: $policy (must be > 0)"
    }

    $daysSinceRotated = [int][Math]::Floor(($TodayDate - $lastRotated).TotalDays)
    $daysUntilExpiry = $policy - $daysSinceRotated

    $urgency = if ($daysUntilExpiry -le 0) { 'expired' }
               elseif ($daysUntilExpiry -le $WarningDays) { 'warning' }
               else { 'ok' }

    # Strongly type as string[] so ConvertTo-Json doesn't unwrap a single-element
    # array to a scalar string (a common PowerShell-to-JSON gotcha).
    $required = [string[]]@()
    if ($Secret.PSObject.Properties['requiredBy'] -and $null -ne $Secret.requiredBy) {
        $required = [string[]]@($Secret.requiredBy)
    }

    # Use PSCustomObject so Sort-Object/Where-Object can address fields by name
    # and ConvertTo-Json preserves insertion order on output.
    return [PSCustomObject]@{
        name               = [string]$Secret.name
        lastRotated        = [string]$Secret.lastRotated
        rotationPolicyDays = $policy
        requiredBy         = $required
        daysSinceRotated   = $daysSinceRotated
        daysUntilExpiry    = $daysUntilExpiry
        urgency            = $urgency
    }
}

function Format-MarkdownReport {
    param(
        [Parameter(Mandatory = $true)] [string]$TodayStr,
        [Parameter(Mandatory = $true)] [int]$WarningDays,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$Expired,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$Warning,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$Ok
    )
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Secret Rotation Report')
    $lines.Add('')
    $lines.Add("Generated for: $TodayStr")
    $lines.Add("Warning window: $WarningDays days")
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add("- Expired: $($Expired.Count)")
    $lines.Add("- Warning: $($Warning.Count)")
    $lines.Add("- OK: $($Ok.Count)")
    $lines.Add('')

    $emitGroup = {
        param($title, $list, $useOverdue)
        $lines.Add("## $title ($($list.Count))")
        $lines.Add('')
        if ($list.Count -eq 0) {
            $lines.Add('_None_')
            $lines.Add('')
            return
        }
        if ($useOverdue) {
            $lines.Add('| Name | Last Rotated | Policy | Days Overdue | Required By |')
        } else {
            $lines.Add('| Name | Last Rotated | Policy | Days Until Expiry | Required By |')
        }
        $lines.Add('| --- | --- | --- | --- | --- |')
        foreach ($s in $list) {
            $reqBy = ($s.requiredBy -join ', ')
            $valueCol = if ($useOverdue) { -1 * $s.daysUntilExpiry } else { $s.daysUntilExpiry }
            $lines.Add("| $($s.name) | $($s.lastRotated) | $($s.rotationPolicyDays) | $valueCol | $reqBy |")
        }
        $lines.Add('')
    }

    & $emitGroup 'Expired' $Expired $true
    & $emitGroup 'Warning' $Warning $false
    & $emitGroup 'OK' $Ok $false

    # Drop trailing blank line for cleaner exact-match.
    while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
        $lines.RemoveAt($lines.Count - 1)
    }
    return ($lines -join "`n")
}

function Format-JsonReport {
    param(
        [Parameter(Mandatory = $true)] [string]$TodayStr,
        [Parameter(Mandatory = $true)] [int]$WarningDays,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$Expired,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$Warning,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$Ok
    )
    # Compress to one line so exact-match assertions are stable across PS versions.
    $payload = [ordered]@{
        today       = $TodayStr
        warningDays = $WarningDays
        summary     = [ordered]@{
            expired = $Expired.Count
            warning = $Warning.Count
            ok      = $Ok.Count
        }
        expired     = $Expired
        warning     = $Warning
        ok          = $Ok
    }
    return ($payload | ConvertTo-Json -Depth 6 -Compress)
}

# --- Main -----------------------------------------------------------------

try {
    $config = Read-Config -Path $ConfigPath

    # Resolve effective parameters: CLI overrides config, config overrides defaults.
    $effectiveToday = if ($Today) { $Today }
                      elseif ($config.PSObject.Properties['today'] -and $config.today) { [string]$config.today }
                      else { (Get-Date).ToString('yyyy-MM-dd') }

    $effectiveWarning = if ($WarningDays -ge 0) { $WarningDays }
                        elseif ($config.PSObject.Properties['warningDays'] -and $null -ne $config.warningDays) { [int]$config.warningDays }
                        else { 7 }

    $effectiveFormat = if ($Format) { $Format }
                       elseif ($config.PSObject.Properties['format'] -and $config.format) { [string]$config.format }
                       else { 'markdown' }

    if ($effectiveFormat -ne 'markdown' -and $effectiveFormat -ne 'json') {
        throw "Unsupported format: '$effectiveFormat'. Use 'markdown' or 'json'."
    }

    $todayDate = ConvertTo-IsoDate -Value $effectiveToday -FieldName 'today'

    if (-not $config.PSObject.Properties['secrets']) {
        throw "Config is missing required 'secrets' array"
    }
    $secretList = @($config.secrets)

    $classified = @($secretList | ForEach-Object {
        Get-SecretClassification -Secret $_ -TodayDate $todayDate -WarningDays $effectiveWarning
    })

    # Sort by daysUntilExpiry asc within each group (most urgent first).
    $expired = @($classified | Where-Object { $_.urgency -eq 'expired' } | Sort-Object daysUntilExpiry)
    $warning = @($classified | Where-Object { $_.urgency -eq 'warning' } | Sort-Object daysUntilExpiry)
    $ok      = @($classified | Where-Object { $_.urgency -eq 'ok' }      | Sort-Object daysUntilExpiry)

    $report = if ($effectiveFormat -eq 'json') {
        Format-JsonReport -TodayStr $effectiveToday -WarningDays $effectiveWarning -Expired $expired -Warning $warning -Ok $ok
    } else {
        Format-MarkdownReport -TodayStr $effectiveToday -WarningDays $effectiveWarning -Expired $expired -Warning $warning -Ok $ok
    }

    # Sentinels let the test harness pull just the report lines out of CI logs.
    Write-Output '::ROTATION_REPORT_BEGIN::'
    Write-Output $report
    Write-Output '::ROTATION_REPORT_END::'

    if ($FailOnExpired -and $expired.Count -gt 0) {
        Write-Error "Found $($expired.Count) expired secret(s). Failing per -FailOnExpired."
        exit 2
    }
    exit 0
} catch {
    Write-Error "Secret rotation validation failed: $($_.Exception.Message)"
    exit 1
}
