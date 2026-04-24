#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Runs the artifact-cleanup-script workflow under `act` for several test cases
  and asserts EXACT expected values from the workflow's output.
.DESCRIPTION
  For each test case:
    1. Writes a per-case env file consumed by act.
    2. Invokes `act push --rm` and captures combined output.
    3. Appends the output to act-result.txt with a clear delimiter.
    4. Asserts exit code 0, "Job succeeded" for both jobs, and the exact
       PLAN_DELETED_COUNT / PLAN_RETAINED_COUNT / PLAN_BYTES_RECLAIMED line.
  Limited to <=3 act invocations as per task constraints.
#>
[CmdletBinding()]
param(
    [string]$ResultPath = (Join-Path $PSScriptRoot 'act-result.txt')
)

$ErrorActionPreference = 'Stop'
if (Test-Path $ResultPath) { Remove-Item $ResultPath -Force }

# Pre-computed expectations per test case (verified by hand against fixtures).
$cases = @(
    [pscustomobject]@{
        Name              = 'basic-age-and-keep'
        Env               = @{
            FIXTURE      = 'artifacts-basic.json'
            MAX_AGE_DAYS = '30'
            KEEP_LATEST  = '2'
            NOW_UTC      = '2026-04-20T00:00:00Z'
        }
        ExpectedDeleted   = 4
        ExpectedRetained  = 4
        ExpectedReclaimed = 108527616
    },
    [pscustomobject]@{
        Name              = 'small-no-deletions'
        Env               = @{
            FIXTURE      = 'artifacts-small.json'
            MAX_AGE_DAYS = '30'
            KEEP_LATEST  = '-1'
            NOW_UTC      = '2026-04-20T00:00:00Z'
        }
        ExpectedDeleted   = 0
        ExpectedRetained  = 2
        ExpectedReclaimed = 0
    },
    [pscustomobject]@{
        Name              = 'keep-latest-only'
        Env               = @{
            FIXTURE      = 'artifacts-keep.json'
            MAX_AGE_DAYS = '-1'
            KEEP_LATEST  = '2'
            NOW_UTC      = '2026-04-20T00:00:00Z'
        }
        ExpectedDeleted   = 3
        ExpectedRetained  = 2
        ExpectedReclaimed = 300
    }
)

$failures = @()

foreach ($case in $cases) {
    Write-Host "=== Running case: $($case.Name) ===" -ForegroundColor Cyan
    $envFile = Join-Path $PSScriptRoot ".act-env-$($case.Name)"
    ($case.Env.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) | Set-Content $envFile

    $output = & act push --rm --pull=false --env-file $envFile 2>&1 | Out-String
    $exit = $LASTEXITCODE

    Add-Content -Path $ResultPath -Value "===== CASE: $($case.Name) (exit=$exit) ====="
    Add-Content -Path $ResultPath -Value $output
    Add-Content -Path $ResultPath -Value ''

    Remove-Item $envFile -Force -ErrorAction SilentlyContinue

    # Assertions
    if ($exit -ne 0) {
        $failures += "[$($case.Name)] act exited with $exit"
        continue
    }
    $jobSuccessCount = ([regex]::Matches($output, 'Job succeeded')).Count
    if ($jobSuccessCount -lt 2) {
        $failures += "[$($case.Name)] expected 2+ 'Job succeeded' lines, found $jobSuccessCount"
    }
    if ($output -notmatch "PLAN_DELETED_COUNT=$($case.ExpectedDeleted)\b") {
        $failures += "[$($case.Name)] missing PLAN_DELETED_COUNT=$($case.ExpectedDeleted)"
    }
    if ($output -notmatch "PLAN_RETAINED_COUNT=$($case.ExpectedRetained)\b") {
        $failures += "[$($case.Name)] missing PLAN_RETAINED_COUNT=$($case.ExpectedRetained)"
    }
    if ($output -notmatch "PLAN_BYTES_RECLAIMED=$($case.ExpectedReclaimed)\b") {
        $failures += "[$($case.Name)] missing PLAN_BYTES_RECLAIMED=$($case.ExpectedReclaimed)"
    }
}

# Workflow structure tests (cheap, no act involvement)
Write-Host "=== Workflow structure tests ===" -ForegroundColor Cyan
$wfPath = Join-Path $PSScriptRoot '.github/workflows/artifact-cleanup-script.yml'
if (-not (Test-Path $wfPath)) { $failures += 'workflow file missing' }
$wfText = Get-Content $wfPath -Raw
foreach ($needle in @('actions/checkout@v4', 'shell: pwsh', 'on:', 'jobs:', 'Invoke-Cleanup.ps1', 'ArtifactCleanup.Tests.ps1')) {
    if ($wfText -notmatch [regex]::Escape($needle)) { $failures += "workflow missing token: $needle" }
}
& actionlint $wfPath
if ($LASTEXITCODE -ne 0) { $failures += "actionlint exited $LASTEXITCODE" }
foreach ($f in @('Invoke-Cleanup.ps1', 'ArtifactCleanup.psm1', 'ArtifactCleanup.Tests.ps1', 'fixtures/artifacts-basic.json')) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $f))) { $failures += "referenced path missing: $f" }
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "All $($cases.Count) act cases + structure checks passed." -ForegroundColor Green
Write-Host "Output saved to: $ResultPath"
