# Thin CLI wrapper around SecretRotationValidator.ps1 so the workflow can call
# it without dot-sourcing logic. Emits the report to stdout.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [ValidateSet('markdown','json')] [string] $Format = 'markdown',
    [int] $WarningDays = 14,
    [string] $ReferenceDate
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/SecretRotationValidator.ps1"

$refDate = if ($ReferenceDate) { [datetime]::Parse($ReferenceDate) } else { Get-Date }
Invoke-RotationReport -ConfigPath $ConfigPath -Format $Format -WarningDays $WarningDays -ReferenceDate $refDate
