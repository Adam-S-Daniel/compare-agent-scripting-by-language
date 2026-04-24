# Thin CLI wrapper around Invoke-SecretRotationValidator.
# Kept separate so SecretRotationValidator.ps1 can be safely dot-sourced by Pester.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ConfigPath,
    [ValidateSet('json','markdown')] [string] $Format = 'markdown',
    [int] $WarningDays = 14,
    [string] $ReferenceDate
)

. "$PSScriptRoot/SecretRotationValidator.ps1"

$refDate = if ($ReferenceDate) {
    [datetime]::Parse($ReferenceDate, [System.Globalization.CultureInfo]::InvariantCulture)
} else {
    [datetime]::UtcNow.Date
}

try {
    Invoke-SecretRotationValidator -ConfigPath $ConfigPath -Format $Format -WarningDays $WarningDays -ReferenceDate $refDate
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
