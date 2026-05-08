# Invoke-Validator.ps1
#
# CLI entry point. Loads a JSON config of secrets, runs the validator, and
# prints the report to stdout in the requested format. Exit codes are designed
# to be useful in CI:
#   0 - all secrets ok
#   1 - at least one warning, but nothing expired
#   2 - one or more secrets expired
#   3 - configuration / runtime error

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [int]    $WarningDays = 14,
    [ValidateSet('markdown','json')] [string] $Format = 'markdown',
    # Today is injected so tests and CI runs are deterministic. Defaults to now.
    [string] $Today = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'

try {
    Import-Module (Join-Path $PSScriptRoot 'SecretRotationValidator.psm1') -Force

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Error "Config file not found: $ConfigPath"
        exit 3
    }

    $raw = Get-Content -LiteralPath $ConfigPath -Raw
    $secrets = @()
    try {
        $parsed = $raw | ConvertFrom-Json
        # Accept either a top-level array or { secrets: [...] }.
        if ($parsed -is [System.Array]) { $secrets = $parsed }
        elseif ($parsed.PSObject.Properties['secrets']) { $secrets = @($parsed.secrets) }
        else { $secrets = @($parsed) }
    } catch {
        Write-Error "Failed to parse JSON config '$ConfigPath': $($_.Exception.Message)"
        exit 3
    }

    $todayDt = [datetime]::Parse($Today, [System.Globalization.CultureInfo]::InvariantCulture)
    $report  = Get-SecretRotationReport -Secrets $secrets -Today $todayDt -WarningDays $WarningDays
    $output  = Format-SecretRotationReport -Report $report -Format $Format
    Write-Output $output

    if     ($report.summary.expired -gt 0) { exit 2 }
    elseif ($report.summary.warning -gt 0) { exit 1 }
    else                                   { exit 0 }
}
catch {
    Write-Error $_.Exception.Message
    exit 3
}
