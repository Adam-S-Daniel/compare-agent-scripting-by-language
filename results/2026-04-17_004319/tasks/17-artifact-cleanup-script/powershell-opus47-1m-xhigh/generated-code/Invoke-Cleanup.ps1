# Invoke-Cleanup.ps1
#
# CLI entry-point for CI/CD. Reads artifact metadata from a JSON file,
# applies retention policies, and emits a deletion plan.
#
# Prints a machine-parseable summary line:
#   RESULT: deleted=<n> retained=<n> reclaimed=<bytes> total=<bytes>
# and, when -EmitJson is set, a JSON plan block delimited by PLAN_JSON_BEGIN
# / PLAN_JSON_END for robust parsing in the act harness.
#
# Always runs in dry-run mode by default so CI invocations cannot delete
# real artifacts unless the caller explicitly opts in with -Execute.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArtifactsPath,

    [Parameter(Mandatory)]
    [int]$MaxAgeDays,

    [long]$MaxTotalSizeBytes = 0,
    [int]$KeepLatestNPerWorkflow = 0,

    # Fixed reference time for deterministic CI runs.
    [datetime]$Now,

    # Default: dry-run. CI pipelines should only execute with an explicit flag.
    [switch]$Execute,

    # If set, print a PLAN_JSON block for machine consumption.
    [switch]$EmitJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Import the planner module.
$modulePath = Join-Path $PSScriptRoot 'ArtifactCleanup.psm1'
Import-Module $modulePath -Force

# Load and validate artifact metadata.
$artifacts = Read-ArtifactsFromJson -Path $ArtifactsPath

# If no fixed -Now was supplied, default to the current UTC time.
if (-not $PSBoundParameters.ContainsKey('Now')) {
    $Now = (Get-Date).ToUniversalTime()
}

$dryRun = -not $Execute

$plan = Invoke-ArtifactCleanup `
    -Artifacts $artifacts `
    -MaxAgeDays $MaxAgeDays `
    -MaxTotalSizeBytes $MaxTotalSizeBytes `
    -KeepLatestNPerWorkflow $KeepLatestNPerWorkflow `
    -Now $Now `
    -DryRun:$dryRun

# Human-friendly preamble.
Write-Host ''
Write-Host "Artifact cleanup plan (dry-run=$dryRun)"
Write-Host "  Input file:                 $ArtifactsPath"
Write-Host "  MaxAgeDays:                 $MaxAgeDays"
Write-Host "  MaxTotalSizeBytes:          $MaxTotalSizeBytes"
Write-Host "  KeepLatestNPerWorkflow:     $KeepLatestNPerWorkflow"
Write-Host "  Now (UTC):                  $($Now.ToString('o'))"
Write-Host ''
Write-Host "Deleted artifacts ($($plan.Summary.DeletedCount)):"
foreach ($a in $plan.Deleted) {
    Write-Host ("  - id={0} name={1} size={2} created={3} workflow={4}" -f $a.Id, $a.Name, $a.SizeBytes, $a.CreatedAt.ToString('o'), $a.WorkflowId)
}
Write-Host "Retained artifacts ($($plan.Summary.RetainedCount)):"
foreach ($a in $plan.Retained) {
    Write-Host ("  - id={0} name={1} size={2} created={3} workflow={4}" -f $a.Id, $a.Name, $a.SizeBytes, $a.CreatedAt.ToString('o'), $a.WorkflowId)
}
Write-Host ''

# Machine-parseable summary line. The act harness asserts exact values against
# these fields per test case.
$summaryLine = "RESULT: deleted={0} retained={1} reclaimed={2} total={3}" -f `
    $plan.Summary.DeletedCount, `
    $plan.Summary.RetainedCount, `
    $plan.Summary.SpaceReclaimedBytes, `
    $plan.Summary.TotalSizeBytes
Write-Host $summaryLine

if ($EmitJson) {
    # Emit a JSON block so the harness can consume the full plan if needed.
    # Use -Depth 5 so nested Summary/Retained/Deleted objects serialize.
    Write-Host 'PLAN_JSON_BEGIN'
    $plan | ConvertTo-Json -Depth 5 -Compress | Write-Host
    Write-Host 'PLAN_JSON_END'
}

if ($plan.Errors.Count -gt 0) {
    Write-Host "Encountered $($plan.Errors.Count) deletion error(s)."
    # Non-zero exit so CI fails loudly if live deletion partially fails.
    exit 2
}

exit 0
