# Test-Workflow.ps1
# End-to-end harness: for each test case it sets up an isolated git repo
# containing the project + that case's fixture, runs `act push --rm`,
# captures the output to act-result.txt, and asserts on EXACT expected
# values parsed from the cleanup script's output.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$resultFile  = Join-Path $projectRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# --------- Workflow structure tests (parse YAML, verify referenced paths) ---
Write-Host "==> Workflow structure tests"

$wfPath = Join-Path $projectRoot '.github/workflows/artifact-cleanup-script.yml'
if (-not (Test-Path $wfPath)) { throw "Workflow file missing: $wfPath" }

# Quick textual structure assertions (avoids needing a YAML module)
$wfText = Get-Content -Raw -LiteralPath $wfPath
foreach ($needle in @(
    'name: artifact-cleanup-script',
    'on:', 'push:', 'pull_request:', 'workflow_dispatch:', 'schedule:',
    'jobs:', 'unit-tests:', 'cleanup-plan:',
    'actions/checkout@v4',
    'Cleanup-Artifacts.Tests.ps1',
    'Cleanup-Artifacts.ps1',
    'shell: pwsh'
)) {
    if ($wfText -notmatch [regex]::Escape($needle)) {
        throw "Workflow missing expected token: $needle"
    }
}

# Referenced script files must exist
foreach ($f in 'Cleanup-Artifacts.ps1','Cleanup-Artifacts.Tests.ps1') {
    if (-not (Test-Path (Join-Path $projectRoot $f))) {
        throw "Referenced script missing: $f"
    }
}

# actionlint must pass
$alOut = & actionlint $wfPath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "actionlint failed:`n$alOut"
}
Write-Host "    actionlint: OK"

# --------- Test cases -------------------------------------------------------
# Each case: a fixture (artifacts JSON), env settings, and expected RESULT_* values.

# Reference "now" used by fixtures. The script defaults to (Get-Date) for $Now,
# so we must use ages relative to today — pick CreatedAt timestamps that are
# unambiguously old/new regardless of when the workflow runs.
$today = (Get-Date).ToUniversalTime()

function New-Fixture {
    param([object[]] $items)
    ($items | ConvertTo-Json -Depth 4 -AsArray)
}

# Note: PS 5.1 doesn't have -AsArray, but pwsh 7+ does, and we run on pwsh 7.
# Each test case object has: Name, Fixture (JSON string), Env (hashtable),
# Expected (hashtable of RESULT_* values).

$cases = @()

# Case 1: age policy deletes the old one
$cases += [pscustomobject]@{
    Name = 'age-policy'
    Fixture = New-Fixture @(
        @{ Name='fresh'; SizeBytes=100; CreatedAt=$today.AddDays(-1).ToString('o'); WorkflowRunId='r1' },
        @{ Name='old';   SizeBytes=500; CreatedAt=$today.AddDays(-90).ToString('o'); WorkflowRunId='r2' }
    )
    Env = @{ MAX_AGE_DAYS='30'; MAX_TOTAL_SIZE_BYTES='0'; KEEP_LATEST_PER_WORKFLOW='0'; DRY_RUN='true' }
    Expected = @{
        RESULT_DELETED_COUNT='1'; RESULT_RETAINED_COUNT='1'; RESULT_RECLAIMED_BYTES='500'
    }
}

# Case 3: keep-latest-1 per workflow with two runs of same workflow
$cases += [pscustomobject]@{
    Name = 'keep-latest-per-workflow'
    Fixture = New-Fixture @(
        @{ Name='r1-newest'; SizeBytes=10; CreatedAt=$today.AddDays(-1).ToString('o'); WorkflowRunId='r1' },
        @{ Name='r1-mid';    SizeBytes=10; CreatedAt=$today.AddDays(-2).ToString('o'); WorkflowRunId='r1' },
        @{ Name='r1-old';    SizeBytes=10; CreatedAt=$today.AddDays(-3).ToString('o'); WorkflowRunId='r1' },
        @{ Name='r2-only';   SizeBytes=10; CreatedAt=$today.AddDays(-4).ToString('o'); WorkflowRunId='r2' }
    )
    Env = @{ MAX_AGE_DAYS='0'; MAX_TOTAL_SIZE_BYTES='0'; KEEP_LATEST_PER_WORKFLOW='1'; DRY_RUN='true' }
    Expected = @{
        RESULT_DELETED_COUNT='2'; RESULT_RETAINED_COUNT='2'; RESULT_RECLAIMED_BYTES='20'
    }
}

# Case 4: total-size budget evicts oldest
$cases += [pscustomobject]@{
    Name = 'size-budget'
    Fixture = New-Fixture @(
        @{ Name='oldest'; SizeBytes=500; CreatedAt=$today.AddDays(-10).ToString('o'); WorkflowRunId='r1' },
        @{ Name='mid';    SizeBytes=500; CreatedAt=$today.AddDays(-5).ToString('o');  WorkflowRunId='r2' },
        @{ Name='newest'; SizeBytes=500; CreatedAt=$today.AddDays(-1).ToString('o');  WorkflowRunId='r3' }
    )
    Env = @{ MAX_AGE_DAYS='0'; MAX_TOTAL_SIZE_BYTES='1000'; KEEP_LATEST_PER_WORKFLOW='0'; DRY_RUN='true' }
    Expected = @{
        RESULT_DELETED_COUNT='1'; RESULT_RETAINED_COUNT='2'; RESULT_RECLAIMED_BYTES='500'
    }
}

# --------- Per-case execution ----------------------------------------------
$workspaceParent = Join-Path ([System.IO.Path]::GetTempPath()) ("act-cleanup-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $workspaceParent | Out-Null

$failures = @()
$caseIndex = 0
foreach ($case in $cases) {
    $caseIndex++
    Write-Host ""
    Write-Host "==> Case $caseIndex/$($cases.Count): $($case.Name)"

    $workdir = Join-Path $workspaceParent $case.Name
    New-Item -ItemType Directory -Path $workdir | Out-Null

    # Copy project files into the temp workspace
    Copy-Item -Recurse -Force `
        (Join-Path $projectRoot '.github') `
        $workdir
    Copy-Item -Force (Join-Path $projectRoot 'Cleanup-Artifacts.ps1')        $workdir
    Copy-Item -Force (Join-Path $projectRoot 'Cleanup-Artifacts.Tests.ps1')  $workdir
    Copy-Item -Force (Join-Path $projectRoot '.actrc')                       $workdir

    # Write fixture
    $fixtureDir = Join-Path $workdir 'fixtures'
    New-Item -ItemType Directory -Path $fixtureDir | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureDir 'artifacts.json') -Value $case.Fixture

    # Build .env file for act (sets the env vars our workflow reads)
    $envPath = Join-Path $workdir '.env'
    $envLines = $case.Env.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    Set-Content -LiteralPath $envPath -Value $envLines

    # init git repo (act needs a real repo)
    Push-Location $workdir
    try {
        & git init -q
        & git -c user.email=test@example.com -c user.name=test add -A
        & git -c user.email=test@example.com -c user.name=test commit -q -m "case $($case.Name)" | Out-Null

        $logFile = Join-Path $workdir 'act.log'
        # Run act push for this case. --env-file injects the case's overrides.
        & act push --rm --pull=false --env-file .env *> $logFile
        $actExit = $LASTEXITCODE

        $output = Get-Content -Raw -LiteralPath $logFile

        # Append delimited output to act-result.txt
        $delim = "`n===== CASE: $($case.Name) (exit=$actExit) =====`n"
        Add-Content -LiteralPath $resultFile -Value $delim
        Add-Content -LiteralPath $resultFile -Value $output

        # Assertions
        if ($actExit -ne 0) {
            $failures += "[$($case.Name)] act exited $actExit"
            continue
        }

        # "Job succeeded" marker for both jobs
        $jobSuccessCount = ([regex]::Matches($output, 'Job succeeded')).Count
        if ($jobSuccessCount -lt 2) {
            $failures += "[$($case.Name)] expected >=2 'Job succeeded', got $jobSuccessCount"
        }

        # Parse RESULT_* lines and assert exact values
        foreach ($key in $case.Expected.Keys) {
            $expected = $case.Expected[$key]
            $rx = "${key}=([^\s|`r`n]+)"
            $m = [regex]::Match($output, $rx)
            if (-not $m.Success) {
                $failures += "[$($case.Name)] missing $key in act output"
                continue
            }
            $actual = $m.Groups[1].Value.Trim()
            if ($actual -ne $expected) {
                $failures += "[$($case.Name)] ${key}: expected '$expected' got '$actual'"
            } else {
                Write-Host "    $key = $actual  (OK)"
            }
        }
    }
    finally { Pop-Location }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "FAILURES:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}
Write-Host "ALL CASES PASSED" -ForegroundColor Green
exit 0
