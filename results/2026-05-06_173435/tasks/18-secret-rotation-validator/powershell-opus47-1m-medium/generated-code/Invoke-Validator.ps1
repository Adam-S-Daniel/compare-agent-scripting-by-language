# CLI runner for the SecretRotationValidator. Wraps the module and translates
# the PassThru result into a process exit code so CI jobs can fail when a
# secret is overdue for rotation.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [int] $WarningDays = 7,
    [ValidateSet('json','markdown')] [string] $Format = 'markdown',
    [string] $OutputPath,
    [string] $NowOverride,        # ISO date, used to make CI runs deterministic
    [switch] $FailOnExpired
)

. "$PSScriptRoot/SecretRotationValidator.ps1"

$now = if ($NowOverride) { [datetime]::Parse($NowOverride) } else { Get-Date }

$result = Invoke-SecretRotationValidatorCli `
    -ConfigPath $ConfigPath `
    -WarningDays $WarningDays `
    -Format $Format `
    -Now $now `
    -PassThru

if ($OutputPath) {
    $result.Output | Set-Content -Path $OutputPath -Encoding utf8
}
Write-Output $result.Output

if ($FailOnExpired -and $result.HasExpired) {
    Write-Error "One or more secrets are expired and require rotation."
    exit 2
}
exit 0
