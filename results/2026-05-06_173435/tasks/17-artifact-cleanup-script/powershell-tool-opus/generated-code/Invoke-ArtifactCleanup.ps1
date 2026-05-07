[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactsPath,

    [int]$MaxAgeDays = 0,
    [int]$MaxTotalSizeMB = 0,
    [int]$KeepLatestN = 0,
    [string]$ReferenceDate,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/ArtifactCleanup.psm1" -Force

if ($MaxAgeDays -lt 0) {
    Write-Error "MaxAgeDays must be non-negative, got: $MaxAgeDays"
    exit 1
}
if ($MaxTotalSizeMB -lt 0) {
    Write-Error "MaxTotalSizeMB must be non-negative, got: $MaxTotalSizeMB"
    exit 1
}
if ($KeepLatestN -lt 0) {
    Write-Error "KeepLatestN must be non-negative, got: $KeepLatestN"
    exit 1
}

try {
    $json = Get-Content -Path $ArtifactsPath -Raw -ErrorAction Stop
}
catch {
    Write-Error "Failed to read artifacts file '$ArtifactsPath': $($_.Exception.Message)"
    exit 1
}

$artifacts = @(ConvertTo-ArtifactList -Json $json)
$policy = New-RetentionPolicy -MaxAgeDays $MaxAgeDays -MaxTotalSizeBytes ([int64]$MaxTotalSizeMB * 1MB) -KeepLatestNPerWorkflow $KeepLatestN

$refDate = if ($ReferenceDate) { [datetime]::Parse($ReferenceDate) } else { Get-Date }

$planParams = @{
    Artifacts     = $artifacts
    Policy        = $policy
    ReferenceDate = $refDate
}
if ($DryRun) { $planParams['DryRun'] = $true }

$plan = Get-DeletionPlan @planParams
$summary = Format-CleanupSummary -Plan $plan
Write-Output $summary
