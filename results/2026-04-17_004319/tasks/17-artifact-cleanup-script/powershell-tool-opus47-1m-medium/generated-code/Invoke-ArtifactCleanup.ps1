#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ArtifactsJsonPath,
    [int]      $MaxAgeDays              = 0,
    [int]      $KeepLatestNPerWorkflow  = 0,
    [long]     $MaxTotalSizeBytes       = 0,
    [string]   $Now,
    [switch]   $DryRun,
    [string]   $PlanOutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path -LiteralPath $ArtifactsJsonPath)) {
    throw "Artifacts JSON not found: $ArtifactsJsonPath"
}

$nowDt = if ($Now) { [datetime]::Parse($Now).ToUniversalTime() } else { (Get-Date).ToUniversalTime() }
$raw = Get-Content -LiteralPath $ArtifactsJsonPath -Raw | ConvertFrom-Json
if ($null -eq $raw) { $raw = @() }
# ConvertFrom-Json yields a single object for 1-element arrays; normalise.
$artifacts = @($raw)

$plan = Get-ArtifactCleanupPlan `
    -Artifacts $artifacts `
    -MaxAgeDays $MaxAgeDays `
    -KeepLatestNPerWorkflow $KeepLatestNPerWorkflow `
    -MaxTotalSizeBytes $MaxTotalSizeBytes `
    -Now $nowDt `
    -DryRun:$DryRun

$mode = if ($DryRun) { 'DRY-RUN' } else { 'APPLY' }
Write-Host "=== Artifact Cleanup Plan ($mode) ==="
Write-Host ("Retained:  {0}" -f $plan.TotalRetained)
Write-Host ("Deleted:   {0}" -f $plan.TotalDeleted)
Write-Host ("Reclaimed: {0} bytes" -f $plan.SpaceReclaimedBytes)

if ($plan.Deleted.Count -gt 0) {
    Write-Host '--- Candidates for deletion ---'
    foreach ($d in $plan.Deleted) {
        Write-Host ("  DELETE {0} ({1} bytes, wf={2})" -f $d.Name, $d.SizeBytes, $d.WorkflowRunId)
    }
}

if ($PlanOutPath) {
    $plan | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $PlanOutPath
}

if (-not $DryRun) {
    # Placeholder for real deletion. In CI this would call the GitHub API;
    # here we simply report that the plan would be executed.
    Write-Host 'APPLY mode: deletion calls would be issued here.'
}
