# Invoke-SecretRotationValidator.ps1
# Entry-point for the secret rotation validator.
# Functions live in SecretRotationValidator.psm1 (module) to keep this
# script's CmdletBinding param-set separate from the function definitions,
# which prevents Pester parameter-binding conflicts when testing.
#
# Run directly:  pwsh Invoke-SecretRotationValidator.ps1 -ConfigFile fixtures/secrets-mixed.json
# Run tests:     Invoke-Pester -Path ./SecretRotationValidator.Tests.ps1

[CmdletBinding()]
param(
    # Path to a JSON file containing secrets configuration
    [string]$ConfigFile,

    # How many days before expiry to warn (default 30; overrides config file)
    [int]$WarningWindowDays = 30,

    # Output format: 'markdown' or 'json'
    [ValidateSet("markdown", "json")]
    [string]$OutputFormat = "markdown",

    # Optional: treat this date as "today" for deterministic/testing runs
    [DateTime]$AsOf
)

# Load functions from the sibling module
Import-Module -Name "$PSScriptRoot/SecretRotationValidator.psm1" -Force

# ============================================================
# Main execution – only runs when -ConfigFile is supplied.
# When dot-sourced in Pester tests, $ConfigFile is empty.
# ============================================================
if ($ConfigFile) {
    try {
        $config = Read-SecretsConfig -ConfigFile $ConfigFile

        # CLI params take precedence over config-file values
        $effectiveWarning = if ($PSBoundParameters.ContainsKey('WarningWindowDays')) {
            $WarningWindowDays
        } elseif ($null -ne $config.warningWindowDays) {
            [int]$config.warningWindowDays
        } else {
            30
        }

        $effectiveAsOf = if ($PSBoundParameters.ContainsKey('AsOf')) {
            $AsOf
        } elseif ($config.asOf) {
            [DateTime]$config.asOf
        } else {
            Get-Date
        }

        $secrets = ConvertTo-SecretObjects -JsonSecrets $config.secrets

        $report = Get-SecretRotationReport `
            -Secrets $secrets `
            -WarningWindowDays $effectiveWarning `
            -AsOf $effectiveAsOf

        if ($OutputFormat -eq "json") {
            $output = Format-RotationReportJson -Report $report
        } else {
            $output = Format-RotationReportMarkdown -Report $report
        }

        # Machine-parseable summary line for CI verification
        Write-Output "ROTATION_VALIDATOR_SUMMARY: expired=$($report.summary.expired) warning=$($report.summary.warning) ok=$($report.summary.ok)"

        # Per-fixture markers so the test harness can grep for exact counts
        $fixtureName = [System.IO.Path]::GetFileNameWithoutExtension($ConfigFile)
        Write-Output "FIXTURE_${fixtureName}_EXPIRED=$($report.summary.expired)"
        Write-Output "FIXTURE_${fixtureName}_WARNING=$($report.summary.warning)"
        Write-Output "FIXTURE_${fixtureName}_OK=$($report.summary.ok)"

        Write-Output $output
    }
    catch {
        Write-Error "Secret rotation validator failed: $($_.Exception.Message)"
        exit 1
    }
}
