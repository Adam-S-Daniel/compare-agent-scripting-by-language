#!/usr/bin/env pwsh
<#
.SYNOPSIS
  CLI entry point: load artifact JSON, apply retention policies, print plan summary.
.DESCRIPTION
  Loads a JSON file of mock artifacts and runs the cleanup planner.
  By default runs in dry-run mode; pass -Apply to actually invoke deletion.
  Since this is mock data, the deletion action just emits a log line.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$FixturePath,
    [int]$MaxAgeDays = -1,
    [long]$MaxTotalSizeBytes = -1,
    [int]$KeepLatestPerWorkflow = -1,
    [datetime]$Now = (Get-Date).ToUniversalTime(),
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path $FixturePath)) {
    throw "Fixture not found: $FixturePath"
}

$artifacts = Get-Content $FixturePath -Raw | ConvertFrom-Json | ForEach-Object {
    New-Artifact -Name $_.name -SizeBytes $_.size -CreatedAt $_.created_at -WorkflowRunId $_.workflow_run_id
}

$splat = @{ Artifacts = $artifacts; Now = $Now }
if ($MaxAgeDays -ge 0)             { $splat.MaxAgeDays = $MaxAgeDays }
if ($MaxTotalSizeBytes -ge 0)      { $splat.MaxTotalSizeBytes = $MaxTotalSizeBytes }
if ($KeepLatestPerWorkflow -ge 0)  { $splat.KeepLatestPerWorkflow = $KeepLatestPerWorkflow }
if (-not $Apply)                   { $splat.DryRun = $true }
$splat.DeleteAction = { param($a) Write-Host "DELETED: $($a.Name)" }

$plan = Invoke-ArtifactCleanup @splat
Write-Host (Format-CleanupPlan -Plan $plan)
Write-Host "PLAN_DELETED_COUNT=$($plan.Summary.DeletedCount)"
Write-Host "PLAN_RETAINED_COUNT=$($plan.Summary.RetainedCount)"
Write-Host "PLAN_BYTES_RECLAIMED=$($plan.Summary.BytesReclaimed)"
foreach ($a in $plan.Delete) { Write-Host "DELETE: $($a.Name)" }
foreach ($a in $plan.Retain) { Write-Host "RETAIN: $($a.Name)" }
