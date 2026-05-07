#!/usr/bin/env pwsh
# CLI wrapper around the ArtifactCleanup module. Reads a JSON fixture of
# artifacts, applies the given retention policies, and prints a deterministic
# plan summary to stdout. Used both locally and from the GitHub Actions workflow.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$FixturePath,
    [int]$MaxAgeDays = 0,
    [long]$MaxTotalSizeBytes = 0,
    [int]$KeepLatestPerWorkflow = 0,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path $FixturePath)) {
    throw "Fixture not found: $FixturePath"
}

# Fixtures store CreatedAt as ISO-8601 strings so they're stable on disk.
$raw = Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json
$artifacts = foreach ($a in $raw) {
    [pscustomobject]@{
        Name          = $a.Name
        SizeBytes     = [long]$a.SizeBytes
        CreatedAt     = [datetime]::Parse($a.CreatedAt, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal)
        WorkflowRunId = $a.WorkflowRunId
    }
}

# Policy parameters are optional; only forward the ones the caller actually set.
$policy = @{}
if ($MaxAgeDays            -gt 0) { $policy.MaxAgeDays            = $MaxAgeDays }
if ($MaxTotalSizeBytes     -gt 0) { $policy.MaxTotalSizeBytes     = $MaxTotalSizeBytes }
if ($KeepLatestPerWorkflow -gt 0) { $policy.KeepLatestPerWorkflow = $KeepLatestPerWorkflow }

$deleted = [System.Collections.ArrayList]::new()
$result = Invoke-ArtifactCleanup -Artifacts @($artifacts) -DryRun:$DryRun `
    -Deleter { param($a) [void]$deleted.Add($a.Name) } @policy

# Stable, line-oriented output that the harness greps against.
Write-Output "DRY_RUN=$($result.DryRun)"
Write-Output "DELETED_COUNT=$($result.Summary.DeletedCount)"
Write-Output "RETAINED_COUNT=$($result.Summary.RetainedCount)"
Write-Output "SPACE_RECLAIMED=$($result.Summary.SpaceReclaimedBytes)"
Write-Output "RETAINED_SIZE=$($result.Summary.RetainedSizeBytes)"
Write-Output "DELETE_NAMES=$((($result.Delete | ForEach-Object Name) | Sort-Object) -join ',')"
Write-Output "RETAIN_NAMES=$((($result.Retain | ForEach-Object Name) | Sort-Object) -join ',')"
Write-Output "ACTUALLY_DELETED=$(($deleted | Sort-Object) -join ',')"
