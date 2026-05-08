# Test harness: runs the workflow under act for several fixture variants and
# asserts on EXACT expected output values.
#
# Each case is run in an isolated temp git repo containing a copy of the
# project + that case's fixtures/artifacts.json. Output from every case is
# appended to act-result.txt in the repo root.
#
# Hard cap: 3 act invocations total (per task instructions).

[CmdletBinding()]
param(
    [string]$ProjectRoot = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resultPath = Join-Path $ProjectRoot 'act-result.txt'
if (Test-Path $resultPath) { Remove-Item $resultPath }

# ----- Test cases ----------------------------------------------------------
# Defaults baked into the workflow: MAX_AGE_DAYS=30, KEEP_LATEST_N=2,
# MAX_TOTAL_SIZE=0, DRY_RUN=true, REFERENCE_NOW=2026-05-07T12:00:00Z.
# Expected counts are pre-computed by hand from those policies.

$cases = @(
    @{
        Name = 'mixed-ages-three-wf'
        # 5 artifacts: 2 are >30d old (deleted by age); 3 survive; per-wf keep-2
        # spares them all; size cap unset -> nothing further dropped.
        Fixture = @(
            @{ Name='build-old';    Size=1000; CreatedAt='2026-01-01T00:00:00Z'; WorkflowRunId='wf1' },
            @{ Name='build-mid';    Size=2000; CreatedAt='2026-04-15T00:00:00Z'; WorkflowRunId='wf1' },
            @{ Name='build-new';    Size=3000; CreatedAt='2026-05-05T00:00:00Z'; WorkflowRunId='wf1' },
            @{ Name='deploy-old';   Size=1500; CreatedAt='2026-02-01T00:00:00Z'; WorkflowRunId='wf2' },
            @{ Name='deploy-newer'; Size=2500; CreatedAt='2026-05-01T00:00:00Z'; WorkflowRunId='wf2' }
        )
        ExpectedDeleted   = 2
        ExpectedRetained  = 3
        ExpectedReclaimed = 2500   # 1000 + 1500
    },
    @{
        Name = 'all-recent-keep-n-trims'
        # All within age window, 4 in same workflow -> keep-2 deletes the 2 oldest.
        Fixture = @(
            @{ Name='a-newest';     Size=100; CreatedAt='2026-05-06T00:00:00Z'; WorkflowRunId='wfX' },
            @{ Name='b-2ndnewest';  Size=200; CreatedAt='2026-05-04T00:00:00Z'; WorkflowRunId='wfX' },
            @{ Name='c-3rdnewest';  Size=400; CreatedAt='2026-05-02T00:00:00Z'; WorkflowRunId='wfX' },
            @{ Name='d-oldest';     Size=800; CreatedAt='2026-04-25T00:00:00Z'; WorkflowRunId='wfX' }
        )
        ExpectedDeleted   = 2
        ExpectedRetained  = 2
        ExpectedReclaimed = 1200   # 400 + 800
    },
    @{
        Name = 'all-old-age-purge'
        # Everything past the 30-day cutoff -> all deleted.
        Fixture = @(
            @{ Name='ancient1'; Size=500;  CreatedAt='2025-09-01T00:00:00Z'; WorkflowRunId='wfA' },
            @{ Name='ancient2'; Size=1500; CreatedAt='2025-12-01T00:00:00Z'; WorkflowRunId='wfB' }
        )
        ExpectedDeleted   = 2
        ExpectedRetained  = 0
        ExpectedReclaimed = 2000
    }
)

# Files to copy into each act sandbox.
$projectFiles = @(
    'Invoke-ArtifactCleanup.ps1',
    'Invoke-ArtifactCleanup.Tests.ps1',
    'Run-Cleanup.ps1',
    '.actrc'
)

function Copy-ProjectInto {
    param([string]$Dest)
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    foreach ($f in $projectFiles) {
        Copy-Item -Path (Join-Path $ProjectRoot $f) -Destination (Join-Path $Dest $f) -Force
    }
    $wfDir = Join-Path $Dest '.github/workflows'
    New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
    Copy-Item -Path (Join-Path $ProjectRoot '.github/workflows/artifact-cleanup-script.yml') `
              -Destination (Join-Path $wfDir 'artifact-cleanup-script.yml') -Force
    New-Item -ItemType Directory -Path (Join-Path $Dest 'fixtures') -Force | Out-Null
}

function Append-Result {
    param([string]$Text)
    Add-Content -Path $resultPath -Value $Text
}

$failures = New-Object System.Collections.Generic.List[string]

foreach ($case in $cases) {
    $caseName = $case.Name
    Write-Host "--- Running case: $caseName ---" -ForegroundColor Cyan

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "act-harness-$caseName-$([guid]::NewGuid())"
    Copy-ProjectInto -Dest $tmp

    # Write the case-specific fixture.
    ($case.Fixture | ConvertTo-Json -Depth 5) |
        Set-Content -Path (Join-Path $tmp 'fixtures/artifacts.json') -Encoding utf8

    Push-Location $tmp
    try {
        git init -q
        git -c user.email=t@t -c user.name=t add -A
        git -c user.email=t@t -c user.name=t commit -q -m "case $caseName"

        # Run act. Capture stdout+stderr, exit code.
        $logPath = Join-Path $tmp 'act.log'
        & act push --rm *>&1 | Tee-Object -FilePath $logPath | Out-Null
        $exit = $LASTEXITCODE
        $log = Get-Content -Raw -Path $logPath

        Append-Result "=========================================="
        Append-Result "CASE: $caseName  (act exit code: $exit)"
        Append-Result "=========================================="
        Append-Result $log
        Append-Result ""

        # ----- Assertions -----
        if ($exit -ne 0) {
            $failures.Add("[$caseName] act exited with $exit")
            continue
        }
        # "Job succeeded" must appear for both jobs (test + cleanup).
        $succeeded = ([regex]::Matches($log, 'Job succeeded')).Count
        if ($succeeded -lt 2) {
            $failures.Add("[$caseName] expected >= 2 'Job succeeded', got $succeeded")
        }

        # Match the RESULT_* lines emitted by Run-Cleanup.ps1, ignoring act's
        # log prefix.
        function Pluck($pattern) {
            $m = [regex]::Match($log, $pattern)
            if (-not $m.Success) { return $null }
            $m.Groups[1].Value
        }
        $delCount  = Pluck 'RESULT_DELETED_COUNT=(\d+)'
        $retCount  = Pluck 'RESULT_RETAINED_COUNT=(\d+)'
        $reclaimed = Pluck 'RESULT_SPACE_RECLAIMED=(\d+)'
        $dryrun    = Pluck 'RESULT_DRYRUN=(\w+)'

        if ([int]$delCount  -ne $case.ExpectedDeleted)   { $failures.Add("[$caseName] DeletedCount: want $($case.ExpectedDeleted), got $delCount") }
        if ([int]$retCount  -ne $case.ExpectedRetained)  { $failures.Add("[$caseName] RetainedCount: want $($case.ExpectedRetained), got $retCount") }
        if ([int]$reclaimed -ne $case.ExpectedReclaimed) { $failures.Add("[$caseName] SpaceReclaimed: want $($case.ExpectedReclaimed), got $reclaimed") }
        if ($dryrun -ne 'True')                          { $failures.Add("[$caseName] DryRun: want True, got $dryrun") }
    }
    finally {
        Pop-Location
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    Append-Result "FAILURES:"
    $failures | ForEach-Object { Append-Result "  - $_" }
    Write-Host "FAILED:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
} else {
    Append-Result "ALL CASES PASSED"
    Write-Host "ALL CASES PASSED" -ForegroundColor Green
}
