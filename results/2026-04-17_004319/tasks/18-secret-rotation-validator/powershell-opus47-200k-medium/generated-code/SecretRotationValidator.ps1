# Secret rotation validator.
#
# Reads a JSON config of secrets, classifies each by urgency (expired / warning / ok)
# based on how close it is to its rotation deadline, and emits a report in either
# JSON or markdown. Designed for CI use: non-zero exit on missing/malformed input,
# exit 0 otherwise (callers can decide to fail the build based on report contents).

Set-StrictMode -Version 3.0

function Get-SecretStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Secret,
        [Parameter(Mandatory)] [datetime] $ReferenceDate,
        [Parameter(Mandatory)] [int] $WarningDays
    )

    # Parse lastRotated strictly; let DateTime.Parse throw on invalid input.
    $last = [datetime]::Parse($Secret.lastRotated, [System.Globalization.CultureInfo]::InvariantCulture)
    $policy = [int] $Secret.rotationPolicyDays
    $daysSince = [int]($ReferenceDate - $last).TotalDays
    $daysUntilExpiry = $policy - $daysSince

    $status = if ($daysUntilExpiry -le 0) { 'expired' }
              elseif ($daysUntilExpiry -le $WarningDays) { 'warning' }
              else { 'ok' }

    [pscustomobject]@{
        name            = $Secret.name
        lastRotated     = $Secret.lastRotated
        rotationPolicyDays = $policy
        daysUntilExpiry = $daysUntilExpiry
        requiredBy      = @($Secret.requiredBy)
        status          = $status
    }
}

function ConvertTo-MarkdownReport {
    param([hashtable] $Groups)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Secret Rotation Report')
    [void]$sb.AppendLine('')
    foreach ($group in 'expired','warning','ok') {
        $title = (Get-Culture).TextInfo.ToTitleCase($group)
        if ($group -eq 'ok') { $title = 'OK' }
        [void]$sb.AppendLine("## $title")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('| Name | Last Rotated | Policy (days) | Days Until Expiry | Required By |')
        [void]$sb.AppendLine('|------|--------------|---------------|-------------------|-------------|')
        foreach ($s in $Groups[$group]) {
            $req = ($s.requiredBy -join ', ')
            [void]$sb.AppendLine("| $($s.name) | $($s.lastRotated) | $($s.rotationPolicyDays) | $($s.daysUntilExpiry) | $req |")
        }
        [void]$sb.AppendLine('')
    }
    $sb.ToString()
}

function Invoke-SecretRotationValidator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $ConfigPath,
        [ValidateSet('json','markdown')] [string] $Format = 'markdown',
        [int] $WarningDays = 14,
        [datetime] $ReferenceDate = [datetime]::UtcNow.Date
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

    if (-not $config.PSObject.Properties['secrets']) {
        throw "Config missing required 'secrets' array: $ConfigPath"
    }

    $groups = @{ expired = @(); warning = @(); ok = @() }
    foreach ($s in $config.secrets) {
        $result = Get-SecretStatus -Secret $s -ReferenceDate $ReferenceDate -WarningDays $WarningDays
        $groups[$result.status] += $result
    }

    $summary = [ordered]@{
        total   = $config.secrets.Count
        expired = $groups['expired'].Count
        warning = $groups['warning'].Count
        ok      = $groups['ok'].Count
    }

    switch ($Format) {
        'json' {
            [ordered]@{
                summary = $summary
                expired = $groups['expired']
                warning = $groups['warning']
                ok      = $groups['ok']
            } | ConvertTo-Json -Depth 6
        }
        'markdown' {
            ConvertTo-MarkdownReport -Groups $groups
        }
        default { throw "Unsupported format: $Format" }
    }
}

# When executed as a script (not dot-sourced), run the validator from CLI args.
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.\s') {
    if ($args.Count -gt 0 -or $PSBoundParameters.Count -gt 0) {
        # Intentionally empty: CLI entrypoint is handled by a separate runner script
        # to keep this file dot-sourceable without side effects.
    }
}
