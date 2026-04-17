#!/usr/bin/env pwsh
# Invoke-Cleanup.ps1
# Thin CLI entry point that reads a fixture JSON file (which may embed its
# own policies + a deterministic reference date + expected results) and runs
# Invoke-ArtifactCleanup against it.
#
# Emits a machine-parseable block the workflow harness asserts on:
#
#   ===CLEANUP-PLAN-BEGIN===
#   DELETED=4
#   RETAINED=1
#   RECLAIMED_BYTES=10000
#   RETAINED_BYTES=5000
#   REASONS_MAXAGE=3
#   REASONS_MAXTOTALSIZE=0
#   REASONS_KEEPLATESTN=3
#   DRY_RUN=true
#   DELETED_IDS=1,2,3,4
#   ===CLEANUP-PLAN-END===
#
# Plus a human-readable summary for the job log.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FixturePath,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Resolve the module relative to *this* script so the workflow doesn't need
# to know where it lives.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path -LiteralPath $FixturePath)) {
    Write-Error "Fixture path does not exist: $FixturePath"
    exit 2
}

# The fixture file bundles the input artifacts with the policy knobs and an
# expected-output section so every test case is self-describing.
$fixture = Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json

$policies = $fixture.policies
$maxAge      = if ($policies.PSObject.Properties.Name -contains 'maxAgeDays')       { [int]$policies.maxAgeDays }       else { 0 }
$maxSize     = if ($policies.PSObject.Properties.Name -contains 'maxTotalSizeBytes') { [long]$policies.maxTotalSizeBytes } else { 0 }
$keepN       = if ($policies.PSObject.Properties.Name -contains 'keepLatestN')       { [int]$policies.keepLatestN }       else { 0 }

$refDate = if ($fixture.PSObject.Properties.Name -contains 'referenceDate') {
    [DateTime]::Parse($fixture.referenceDate, [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
        [System.Globalization.DateTimeStyles]::AdjustToUniversal)
} else {
    [DateTime]::UtcNow
}

try {
    $plan = Invoke-ArtifactCleanup -ArtifactsPath $FixturePath `
        -MaxAgeDays $maxAge `
        -MaxTotalSizeBytes $maxSize `
        -KeepLatestN $keepN `
        -DryRun:$DryRun `
        -ReferenceDate $refDate
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 3
}

# Human-readable summary.
Write-Host ""
Write-Host "==============================================="
Write-Host " Artifact Cleanup Plan"
Write-Host "==============================================="
Write-Host "Fixture:          $FixturePath"
Write-Host "Reference date:   $refDate"
Write-Host "DryRun:           $($plan.DryRun)"
Write-Host "Policies:         MaxAgeDays=$maxAge MaxTotalSizeBytes=$maxSize KeepLatestN=$keepN"
Write-Host "Artifacts total:  $($plan.Summary.DeletedCount + $plan.Summary.RetainedCount)"
Write-Host "Deleting:         $($plan.Summary.DeletedCount) ($($plan.Summary.ReclaimedBytes) bytes)"
Write-Host "Retaining:        $($plan.Summary.RetainedCount) ($($plan.Summary.RetainedBytes) bytes)"
Write-Host "Reason breakdown: MaxAge=$($plan.Summary.Reasons.MaxAgeDays) Size=$($plan.Summary.Reasons.MaxTotalSizeBytes) KeepN=$($plan.Summary.Reasons.KeepLatestN)"
Write-Host ""
if ($plan.Delete.Count -gt 0) {
    Write-Host "Artifacts to delete:"
    foreach ($a in $plan.Delete) {
        $reasons = ($a.DeletionReasons -join ',')
        Write-Host ("  - id={0,-4} name={1,-24} size={2,-8} created={3} reasons={4}" -f `
            $a.Id, $a.Name, $a.SizeBytes, $a.CreatedAt.ToString('o'), $reasons)
    }
}

# Machine-parseable block. Stable anchors so the harness can grep between them.
$deletedIds = ($plan.Delete | ForEach-Object { $_.Id }) -join ','

Write-Host ""
Write-Host "===CLEANUP-PLAN-BEGIN==="
Write-Host "DELETED=$($plan.Summary.DeletedCount)"
Write-Host "RETAINED=$($plan.Summary.RetainedCount)"
Write-Host "RECLAIMED_BYTES=$($plan.Summary.ReclaimedBytes)"
Write-Host "RETAINED_BYTES=$($plan.Summary.RetainedBytes)"
Write-Host "REASONS_MAXAGE=$($plan.Summary.Reasons.MaxAgeDays)"
Write-Host "REASONS_MAXTOTALSIZE=$($plan.Summary.Reasons.MaxTotalSizeBytes)"
Write-Host "REASONS_KEEPLATESTN=$($plan.Summary.Reasons.KeepLatestN)"
Write-Host "DRY_RUN=$($plan.DryRun.ToString().ToLower())"
Write-Host "DELETED_IDS=$deletedIds"
Write-Host "===CLEANUP-PLAN-END==="

exit 0
