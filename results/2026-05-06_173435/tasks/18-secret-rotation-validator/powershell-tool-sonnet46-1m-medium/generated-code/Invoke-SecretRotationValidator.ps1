# Invoke-SecretRotationValidator.ps1
# Entry-point for the Secret Rotation Validator.
# Usage:
#   ./Invoke-SecretRotationValidator.ps1 -ConfigPath secrets.json
#   ./Invoke-SecretRotationValidator.ps1 -ConfigPath secrets.json -OutputFormat json
#   ./Invoke-SecretRotationValidator.ps1 -ConfigPath secrets.json -ReferenceDate "2026-05-08"

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [ValidateSet("markdown", "json")]
    [string]$OutputFormat = "markdown",

    [int]$WarningWindowDays = 14,

    # Optional fixed reference date (yyyy-MM-dd) for reproducible CI/test output.
    # Defaults to today when omitted.
    [string]$ReferenceDate = ""
)

. "$PSScriptRoot/SecretRotationFunctions.ps1"

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"
    exit 1
}

try {
    $secrets = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config file '$ConfigPath': $_"
    exit 1
}

if ($null -eq $secrets -or $secrets.Count -eq 0) {
    Write-Error "Config file contains no secrets: $ConfigPath"
    exit 1
}

$report = Get-RotationReport -Secrets $secrets -WarningDays $WarningWindowDays -ReferenceDate $ReferenceDate

switch ($OutputFormat) {
    "markdown" { Format-ReportAsMarkdown -Report $report }
    "json"     { Format-ReportAsJson     -Report $report }
}
