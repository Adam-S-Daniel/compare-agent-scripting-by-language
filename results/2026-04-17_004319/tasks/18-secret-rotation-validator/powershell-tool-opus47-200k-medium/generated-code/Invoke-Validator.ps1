# CLI entrypoint for the secret rotation validator.
# Loads the module functions and invokes the validator with CLI args.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [int]$WarningDays = 7,
    [ValidateSet('markdown','json')][string]$Format = 'markdown',
    [string]$Now,
    [string]$OutputPath
)

. $PSScriptRoot/SecretRotationValidator.ps1

$nowDt = if ($Now) { [datetime]$Now } else { Get-Date }

$report = Invoke-SecretRotationValidator -ConfigPath $ConfigPath -WarningDays $WarningDays -Format $Format -Now $nowDt

if ($OutputPath) {
    $report | Set-Content -Path $OutputPath
}
$report
