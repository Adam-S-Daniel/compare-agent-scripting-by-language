#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CLI entry point for the artifact cleanup module.

.DESCRIPTION
    Reads a JSON file describing artifacts (mock fixture data), applies the
    requested retention policies, and prints a deletion plan + summary. By
    default operates in dry-run mode -- pass -Apply to actually invoke the
    deleter callback (which in this offline context just logs).

.PARAMETER InputJson
    Path to the JSON fixture. Top-level shape:
      {
        "now": "2026-04-19T12:00:00Z",
        "policies": {
          "maxAgeDays": 30,
          "keepLatestPerWorkflow": 2,
          "maxTotalSizeBytes": 1048576
        },
        "artifacts": [
          { "id": "...", "name": "...", "sizeBytes": 123,
            "createdAt": "2026-...", "workflowRunId": "..." }
        ]
      }
    All policy fields are optional.

.PARAMETER Apply
    Disable dry-run; the (mock) deleter will be invoked for each artifact.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputJson,
    [switch] $Apply
)

$ErrorActionPreference = 'Stop'

$ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $ModuleRoot 'ArtifactCleanup.psm1') -Force

if (-not (Test-Path -LiteralPath $InputJson)) {
    Write-Error "Input file not found: $InputJson"
    exit 2
}

try {
    $raw = Get-Content -LiteralPath $InputJson -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to parse JSON ($InputJson): $($_.Exception.Message)"
    exit 2
}

# Coerce createdAt strings into [datetime] up front so the module sees the
# right type. JSON only knows about strings.
$artifacts = @()
foreach ($a in @($raw.artifacts)) {
    $artifacts += [pscustomobject]@{
        id            = $a.id
        name          = $a.name
        sizeBytes     = [long]$a.sizeBytes
        createdAt     = [datetime]$a.createdAt
        workflowRunId = $a.workflowRunId
    }
}

$now = if ($raw.PSObject.Properties.Name -contains 'now' -and $raw.now) {
    [datetime]$raw.now
} else {
    [datetime]::UtcNow
}

# Build policy splat from whatever was supplied.
$invokeArgs = @{ Artifacts = $artifacts; Now = $now }
$policies   = $raw.policies
if ($policies) {
    if ($policies.PSObject.Properties.Name -contains 'maxAgeDays' -and $null -ne $policies.maxAgeDays) {
        $invokeArgs['MaxAgeDays'] = [int]$policies.maxAgeDays
    }
    if ($policies.PSObject.Properties.Name -contains 'keepLatestPerWorkflow' -and $null -ne $policies.keepLatestPerWorkflow) {
        $invokeArgs['KeepLatestPerWorkflow'] = [int]$policies.keepLatestPerWorkflow
    }
    if ($policies.PSObject.Properties.Name -contains 'maxTotalSizeBytes' -and $null -ne $policies.maxTotalSizeBytes) {
        $invokeArgs['MaxTotalSizeBytes'] = [long]$policies.maxTotalSizeBytes
    }
}
if (-not $Apply) { $invokeArgs['DryRun'] = $true }

# Mock deleter: writes a line so apply-mode runs are observable in CI logs.
$invokeArgs['Deleter'] = {
    param($entry)
    Write-Host ("[delete-mock] removed artifact id={0} name={1}" -f $entry.id, $entry.name)
}

try {
    $result = Invoke-ArtifactCleanup @invokeArgs
}
catch {
    Write-Error "Cleanup failed: $($_.Exception.Message)"
    exit 1
}

Write-Host (Format-DeletionPlanReport -Plan $result.Plan)

if ($result.DeletedFailed.Count -gt 0) {
    Write-Host ("WARNING: {0} deletions failed" -f $result.DeletedFailed.Count)
    foreach ($f in $result.DeletedFailed) {
        Write-Host ("  FAILED {0}: {1}" -f $f.Artifact.name, $f.Error)
    }
    exit 1
}

Write-Host ("MODE: {0}" -f $(if ($result.DryRun) { 'DRY-RUN' } else { 'APPLY' }))
exit 0
