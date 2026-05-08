#!/usr/bin/env pwsh
<#
.SYNOPSIS
CLI front end for the ArtifactCleanup module. Reads a JSON fixture
describing a list of artifacts plus a retention policy, computes a
deletion plan, prints a human summary plus the plan as JSON, and exits
with code 0 on success.

The fixture format is intentionally tolerant about timestamps:
each artifact may specify EITHER an absolute `createdAt` ISO-8601 string,
OR a relative `daysAgo` integer. When `daysAgo` is supplied the runner
converts it to an absolute UTC timestamp at execution time, which keeps
fixtures stable across test runs.

.PARAMETER FixturePath
Path to the fixture JSON. Defaults to the FIXTURE_PATH env var if not given.

.PARAMETER OutDir
Directory where machine-readable plan JSON is written. Defaults to ./out.
#>
[CmdletBinding()]
param(
    [string]$FixturePath = $env:FIXTURE_PATH,
    [string]$OutDir = './out'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $FixturePath) {
    Write-Error 'FixturePath was not provided (pass -FixturePath or set FIXTURE_PATH).'
    exit 2
}
if (-not (Test-Path -LiteralPath $FixturePath)) {
    Write-Error "Fixture file not found: $FixturePath"
    exit 2
}

# Resolve the module path relative to this script so the runner is
# location-independent (works inside the act container without env).
$moduleRoot = Join-Path $PSScriptRoot 'src' 'ArtifactCleanup.psm1'
Import-Module $moduleRoot -Force

$fixture = Get-Content -Raw -LiteralPath $FixturePath | ConvertFrom-Json

# Normalize artifact list: support either createdAt (ISO 8601) or daysAgo
# (integer). daysAgo wins when both are present because that's what tests
# typically rely on.
$nowUtc = (Get-Date).ToUniversalTime()
$artifacts = foreach ($a in $fixture.artifacts) {
    $hasDaysAgo = $a.PSObject.Properties.Match('daysAgo').Count -gt 0
    if ($hasDaysAgo) {
        $created = $nowUtc.AddDays(-[double]$a.daysAgo)
    } elseif ($a.PSObject.Properties.Match('createdAt').Count -gt 0) {
        $created = [datetime]::Parse($a.createdAt).ToUniversalTime()
    } else {
        throw "Artifact '$($a.name)' has neither daysAgo nor createdAt."
    }
    [pscustomobject]@{
        name          = $a.name
        size          = [long]$a.size
        createdAt     = $created.ToString('o')
        workflowRunId = $a.workflowRunId
    }
}

# Coerce policy from the fixture's PSCustomObject into a plain hashtable
# (the module's parameter is typed [hashtable]).
$policy = @{}
if ($fixture.PSObject.Properties.Match('policy').Count) {
    foreach ($p in $fixture.policy.PSObject.Properties) {
        $policy[$p.Name] = $p.Value
    }
}

$dryRun = $true
if ($fixture.PSObject.Properties.Match('dryRun').Count) {
    $dryRun = [bool]$fixture.dryRun
}

$plan = Get-CleanupPlan -Artifacts $artifacts -Policy $policy -DryRun $dryRun

# Apply the plan against a mock delete action (we never have a real backend
# in the benchmark) — this exercises Invoke-CleanupPlan including the
# dry-run gate. The action just appends to an in-memory log we then print.
$mockDeleted = New-Object System.Collections.Generic.List[string]
$result = Invoke-CleanupPlan -Plan $plan -DeleteAction { param($a) [void]$mockDeleted.Add($a.name) }

# ---- Output ---------------------------------------------------------------
# Human-friendly one-liner so reviewers reading the workflow log see the
# headline numbers immediately.
Write-Host "FIXTURE: $($fixture.name)"
Write-Host (Format-CleanupSummary -Plan $plan)
Write-Host "MOCK_DELETED_COUNT: $($result.deletedActuallyCount)"

# Stable, parseable key=value lines so the act-output assertion harness
# can grep for exact numbers without depending on JSON parsing.
Write-Host "ASSERT deletedCount=$($plan.deletedCount)"
Write-Host "ASSERT retainedCount=$($plan.retainedCount)"
Write-Host "ASSERT totalReclaimedBytes=$($plan.totalReclaimedBytes)"
Write-Host "ASSERT totalRetainedBytes=$($plan.totalRetainedBytes)"
Write-Host "ASSERT dryRun=$($plan.dryRun)"
Write-Host "ASSERT mockDeletedActually=$($result.deletedActuallyCount)"

# Persist the plan JSON for downstream tools / archival.
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
$jsonPath = Join-Path $OutDir 'plan.json'
$plan | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding utf8
Write-Host "PLAN_JSON: $jsonPath"

exit 0
