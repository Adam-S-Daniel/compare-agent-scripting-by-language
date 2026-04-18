#!/usr/bin/env pwsh
# CLI wrapper: load a JSON fixture of artifacts, apply retention policies,
# print a deterministic summary. Used by the GitHub Actions workflow.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $FixturePath,
    [int]    $MaxAgeDays = 0,
    [long]   $MaxTotalSizeBytes = 0,
    [int]    $KeepLatestPerWorkflow = 0,
    [string] $Now,                 # ISO-8601 override for deterministic tests
    [switch] $DryRun
)

Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path $FixturePath)) {
    Write-Error "Fixture not found: $FixturePath"
    exit 2
}

$raw = Get-Content -Raw $FixturePath | ConvertFrom-Json
$artifacts = @($raw | ForEach-Object {
    [pscustomobject]@{
        Name          = $_.Name
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
    Write-Error $_.Exception.Message
    exit 1
}

# Machine-readable summary — test harness greps for these exact tokens.
Write-Host "RESULT deleted=$($plan.Summary.DeletedCount) retained=$($plan.Summary.RetainedCount) reclaimed=$($plan.Summary.SpaceReclaimed) dryrun=$($plan.Summary.DryRun)"
