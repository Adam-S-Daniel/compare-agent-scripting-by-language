#!/usr/bin/env pwsh
# CLI entry point: load a JSON artifact list, apply retention policies, print the deletion plan.
# The RESULT line at the end is machine-readable and is grepped by the test harness.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $FixturePath,
    [int]    $MaxAgeDays = 0,
    [long]   $MaxTotalSizeBytes = 0,
    [int]    $KeepLatestPerWorkflow = 0,
    [string] $Now,       # ISO-8601 date override for deterministic tests
    [switch] $DryRun
)

Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path $FixturePath)) {
    Write-Error "Fixture file not found: $FixturePath"
    exit 2
}

$raw = Get-Content -Raw $FixturePath | ConvertFrom-Json
$artifacts = @($raw | ForEach-Object {
    [pscustomobject]@{
        Name          = [string]$_.Name
        Size          = [long]$_.Size
        CreationDate  = [datetime]$_.CreationDate
        WorkflowRunId = [string]$_.WorkflowRunId
    }
})

$nowValue = if ($Now) { [datetime]$Now } else { Get-Date }

try {
    $plan = Invoke-ArtifactCleanup `
        -Artifacts $artifacts `
        -MaxAgeDays $MaxAgeDays `
        -MaxTotalSizeBytes $MaxTotalSizeBytes `
        -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
        -Now $nowValue `
        -DryRun:$DryRun
} catch {
    Write-Error "Cleanup failed: $($_.Exception.Message)"
    exit 1
}

# Machine-readable summary line — test harness asserts on exact token values
Write-Host "RESULT deleted=$($plan.Summary.DeletedCount) retained=$($plan.Summary.RetainedCount) reclaimed=$($plan.Summary.SpaceReclaimed) dryrun=$($plan.Summary.DryRun)"
