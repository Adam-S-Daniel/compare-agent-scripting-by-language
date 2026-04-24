# CLI front end for the ArtifactCleanup module.
#
# Reads artifacts from a JSON file, applies the configured retention policies,
# and writes a human-readable summary to stdout plus a machine-readable plan
# to the path given by -OutputPath (default: cleanup-plan.json).
#
# Shape of the input JSON:
#   [{ "Name": "...", "SizeBytes": 123, "CreatedAt": "2026-03-01T00:00:00Z",
#      "WorkflowRunId": "ci" }, ...]
#
# This script is what the GitHub Actions workflow calls. Keeping it thin
# (parse → delegate → print) means the core logic stays in the module and
# remains covered by Pester.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $InputPath,

    [int]    $MaxAgeDays = 0,
    [long]   $MaxTotalSizeBytes = 0,
    [int]    $KeepLatestPerWorkflow = 0,

    [switch] $DryRun,

    [string] $OutputPath = 'cleanup-plan.json',

    # Injected so workflow test fixtures can freeze age math for reproducible
    # output. If omitted, falls back to UTC now.
    [string] $NowUtc
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input fixture not found at '$InputPath'"
}

$raw = Get-Content -LiteralPath $InputPath -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Input fixture '$InputPath' is empty"
}

$parsed = $raw | ConvertFrom-Json

# ConvertFrom-Json yields $null for an empty array and a bare object for a
# single-element array, so wrap with @(...) before AND after the projection
# to guarantee an array reaches the module.
$artifacts = @(@($parsed) | ForEach-Object {
    [pscustomobject]@{
        Name          = $_.Name
        SizeBytes     = [long]$_.SizeBytes
        CreatedAt     = [datetime]$_.CreatedAt
        WorkflowRunId = [string]$_.WorkflowRunId
    }
})

$now = if ($PSBoundParameters.ContainsKey('NowUtc') -and $NowUtc) {
    [datetime]$NowUtc
} else {
    [datetime]::UtcNow
}

$plan = Invoke-ArtifactCleanup -Artifacts $artifacts `
                               -MaxAgeDays $MaxAgeDays `
                               -MaxTotalSizeBytes $MaxTotalSizeBytes `
                               -KeepLatestPerWorkflow $KeepLatestPerWorkflow `
                               -Now $now `
                               -DryRun:$DryRun

# Persist the full plan as JSON for downstream assertions.
$plan | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

# Human-readable summary on stdout. Workflow tests grep this output, so the
# exact tokens matter — keep them stable.
$mode = if ($plan.DryRun) { 'DRY-RUN' } else { 'EXECUTE' }
Write-Host "=== Artifact Cleanup Plan ($mode) ==="
Write-Host "TotalArtifacts: $($plan.Summary.TotalArtifacts)"
Write-Host "DeletedCount: $($plan.Summary.DeletedCount)"
Write-Host "RetainedCount: $($plan.Summary.RetainedCount)"
Write-Host "BytesReclaimed: $($plan.Summary.BytesReclaimed)"
Write-Host "BytesRetained: $($plan.Summary.BytesRetained)"

if ($plan.ToDelete.Count -gt 0) {
    Write-Host '--- To delete ---'
    foreach ($a in $plan.ToDelete) {
        Write-Host ("DELETE {0} ({1} bytes, workflow={2}) reason={3}" -f `
                    $a.Name, $a.SizeBytes, $a.WorkflowRunId, $a.Reason)
    }
}

if ($plan.Failures.Count -gt 0) {
    Write-Host '--- Failures ---'
    foreach ($f in $plan.Failures) {
        Write-Host ("FAILED {0} workflow={1}: {2}" -f $f.Name, $f.WorkflowRunId, $f.Error)
    }
    exit 2
}

Write-Host "Plan written to $OutputPath"
exit 0
