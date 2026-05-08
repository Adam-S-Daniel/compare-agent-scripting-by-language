# CLI entrypoint for the validator. Used directly by the GitHub Actions
# workflow. Exits non-zero only on hard failures (bad config, IO error).
# A non-empty `expired` bucket is reported in the output but does not, by
# itself, fail the pipeline — the caller decides what to do with it via -FailOnExpired.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [int] $WarningDays = 14,
    [string] $AsOfDate,
    [ValidateSet('markdown','json')] [string] $Format = 'markdown',
    [switch] $FailOnExpired
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'SecretRotationValidator.psm1') -Force

$asOf = if ($AsOfDate) { [datetime]::Parse($AsOfDate) } else { Get-Date }

$output = Invoke-SecretRotationValidator -ConfigPath $ConfigPath -WarningDays $WarningDays -AsOfDate $asOf -Format $Format
Write-Output $output

if ($FailOnExpired) {
    $obj = Invoke-SecretRotationValidator -ConfigPath $ConfigPath -WarningDays $WarningDays -AsOfDate $asOf -Format object
    if ($obj.summary.expired -gt 0) {
        Write-Error "Found $($obj.summary.expired) expired secret(s)."
        exit 2
    }
}
