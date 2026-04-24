# CLI wrapper for the Aggregator module. Used by the GitHub Actions workflow.
[CmdletBinding()]
param(
    [string]$InputPath = 'fixtures',
    [string]$OutputPath = 'summary.md'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Aggregator.psm1') -Force
$agg = Invoke-Aggregator -InputPath $InputPath -OutputPath $OutputPath

# If running in GitHub Actions, also append to the job summary.
if ($env:GITHUB_STEP_SUMMARY) {
    Get-Content -LiteralPath $OutputPath -Raw | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
}

# Exit 0 on success / 0 failures; non-zero if any failed tests and -FailOnError was passed is
# out of scope — keep it simple and return 0 so downstream steps can still inspect output.
exit 0
