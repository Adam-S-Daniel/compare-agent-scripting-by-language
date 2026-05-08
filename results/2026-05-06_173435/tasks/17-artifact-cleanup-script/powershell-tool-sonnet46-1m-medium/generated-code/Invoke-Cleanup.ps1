# Invoke-Cleanup.ps1
#
# CLI entry point for the artifact cleanup script.
# Reads a JSON fixture file, applies retention policies, and prints the deletion plan.
# Supports --dry-run to preview without deleting.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $FixturePath,

    [int]    $MaxAgeDays            = 0,
    [long]   $MaxTotalSizeBytes     = 0,
    [int]    $KeepLatestPerWorkflow = 0,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

# ── Load artifacts ─────────────────────────────────────────────────────────────
if (-not (Test-Path $FixturePath)) {
    Write-Error "Fixture file not found: $FixturePath"
    exit 1
}

$raw = Get-Content $FixturePath -Raw | ConvertFrom-Json

# Normalize: ensure CreatedAt is a DateTime object
$artifacts = $raw | ForEach-Object {
    [pscustomobject]@{
        Name          = $_.name
        SizeBytes     = [long] $_.sizeBytes
        CreatedAt     = [datetime] $_.createdAt
        WorkflowRunId = $_.workflowRunId
    }
}

# ── Build policy parameters ────────────────────────────────────────────────────
$policyParams = @{ Artifacts = @($artifacts) }
if ($MaxAgeDays            -gt 0) { $policyParams.MaxAgeDays            = $MaxAgeDays }
if ($MaxTotalSizeBytes     -gt 0) { $policyParams.MaxTotalSizeBytes     = $MaxTotalSizeBytes }
if ($KeepLatestPerWorkflow -gt 0) { $policyParams.KeepLatestPerWorkflow = $KeepLatestPerWorkflow }

# REFERENCE_DATE env var allows pinning "today" for reproducible CI runs.
if ($env:REFERENCE_DATE) {
    $policyParams.ReferenceDate = [datetime] $env:REFERENCE_DATE
}

if ($policyParams.Count -le 1) {
    Write-Error "Specify at least one of -MaxAgeDays, -MaxTotalSizeBytes, or -KeepLatestPerWorkflow."
    exit 1
}

if ($DryRun) { $policyParams.DryRun = $true }

# Deleter: in a real pipeline this would call the GitHub API.
# For this script we just print what would be deleted.
$policyParams.Deleter = {
    param($a)
    Write-Host "  [DELETE] $($a.Name) ($($a.SizeBytes) bytes, created $($a.CreatedAt))"
}

# ── Run cleanup ────────────────────────────────────────────────────────────────
$result = Invoke-ArtifactCleanup @policyParams

# ── Print summary ──────────────────────────────────────────────────────────────
$mode = if ($result.DryRun) { ' (DRY RUN)' } else { '' }
Write-Host ""
Write-Host "=== Artifact Cleanup Summary$mode ==="
Write-Host "  Artifacts to delete : $($result.Summary.DeletedCount)"
Write-Host "  Artifacts retained  : $($result.Summary.RetainedCount)"
Write-Host "  Space reclaimed     : $($result.Summary.SpaceReclaimedBytes) bytes"
Write-Host ""

if ($result.Delete.Count -gt 0) {
    Write-Host "Artifacts marked for deletion:"
    foreach ($a in $result.Delete) {
        Write-Host "  - $($a.Name)  [$($a.SizeBytes) bytes, run=$($a.WorkflowRunId), created=$($a.CreatedAt)]"
    }
    Write-Host ""
}

if ($result.Retain.Count -gt 0) {
    Write-Host "Artifacts retained:"
    foreach ($a in $result.Retain) {
        Write-Host "  + $($a.Name)  [$($a.SizeBytes) bytes, run=$($a.WorkflowRunId), created=$($a.CreatedAt)]"
    }
}
