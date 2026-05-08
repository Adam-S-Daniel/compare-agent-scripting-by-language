#!/usr/bin/env pwsh
#requires -Version 7.0
<#
.SYNOPSIS
    Runs the test-results-aggregator workflow under nektos/act for several
    fixture cases, asserts exact expected values, and writes act-result.txt.
.DESCRIPTION
    For each test case:
      1. Stage a temp directory containing the project files plus the case's
         fixture data (the fixture directory is wired up as the workflow's
         default input).
      2. Initialise it as a fresh git repo.
      3. Run `act push --rm` and capture combined output.
      4. Append the captured output to act-result.txt with a clear delimiter.
      5. Assert exit code 0 and that exact expected token strings appear in
         the output (e.g. AGGREGATE_PASSED=13).
      6. Assert each expected job's "Job succeeded" line appears.

    Limited to one act invocation per case (3 cases total = 3 act runs max).
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string] $ResultFile  = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'act-result.txt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Reset the cumulative result log so each invocation produces a fresh artifact.
Set-Content -LiteralPath $ResultFile -Value '' -Encoding utf8

# Define the cases. Each case has:
#   Name         - human label
#   FixtureDir   - directory under fixtures/ to use as the workflow input
#   ExpectTokens - list of substrings that must appear in act stdout/stderr
function New-Case([string]$Name, [string]$FixtureDir, [string[]]$ExpectTokens) {
    return @{ Name = $Name; FixtureDir = $FixtureDir; ExpectTokens = $ExpectTokens }
}

# matrix-mixed: 17 tests across 3 runs, 2 failed, 2 skipped, 2 flaky.
# matrix-green: 4 tests across 2 runs, all passed.
# matrix-mixed-flaky-only-pretty: same as matrix-mixed but used to also verify
#   the per-flaky-test row appears verbatim.
$cases = @(
    (New-Case 'matrix-mixed' 'fixtures/matrix-mixed' @(
        'AGGREGATE_TOTAL=17'
        'AGGREGATE_PASSED=13'
        'AGGREGATE_FAILED=2'
        'AGGREGATE_SKIPPED=2'
        'AGGREGATE_DURATION=3.13'
        'AGGREGATE_FLAKY=2'
        '| 13 | 2 | 2 | 17 | 3.13s |'
        '| auth.LoginSpec | locks after 5 attempts | 2 | 1 |'
        '| db.MigrationSpec | applies migrations cleanly | 1 | 1 |'
        'Could not connect to local Postgres'
    )),
    (New-Case 'matrix-green' 'fixtures/matrix-green' @(
        'AGGREGATE_TOTAL=4'
        'AGGREGATE_PASSED=4'
        'AGGREGATE_FAILED=0'
        'AGGREGATE_SKIPPED=0'
        'AGGREGATE_DURATION=0.10'
        'AGGREGATE_FLAKY=0'
        '| 4 | 0 | 0 | 4 | 0.10s |'
        'All tests passed.'
    ))
)

$expectedJobs = @('Pester unit tests', 'Aggregate test results')

function Write-Section([string]$header) {
    Add-Content -LiteralPath $ResultFile -Value ''
    Add-Content -LiteralPath $ResultFile -Value ('=' * 78)
    Add-Content -LiteralPath $ResultFile -Value $header
    Add-Content -LiteralPath $ResultFile -Value ('=' * 78)
}

# Stage a copy of the project into a sibling temp directory and run act there.
# We don't run act from the live project root because act picks up an existing
# .git/HEAD; using a fresh temp git repo per case prevents state leakage.
function Invoke-ActCase {
    param(
        [hashtable] $Case
    )
    $stage = Join-Path ([System.IO.Path]::GetTempPath()) ("act-stage-{0}-{1}" -f $Case.Name, [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null

    # rsync-style copy: include source, fixtures, .github, .actrc, tests; skip act-result.txt and .git itself.
    Copy-Item -Recurse -Path (Join-Path $ProjectRoot 'src')      -Destination $stage
    Copy-Item -Recurse -Path (Join-Path $ProjectRoot 'tests')    -Destination $stage
    Copy-Item -Recurse -Path (Join-Path $ProjectRoot 'fixtures') -Destination $stage
    Copy-Item -Recurse -Path (Join-Path $ProjectRoot '.github')  -Destination $stage
    Copy-Item          -Path (Join-Path $ProjectRoot '.actrc')   -Destination $stage

    # Patch the workflow to point at this case's fixture directory by default.
    $wfPath = Join-Path $stage '.github/workflows/test-results-aggregator.yml'
    $wf = Get-Content -LiteralPath $wfPath -Raw
    $wf = $wf -replace 'DEFAULT_FIXTURE_DIR:\s+\S+', ("DEFAULT_FIXTURE_DIR: " + $Case.FixtureDir)
    Set-Content -LiteralPath $wfPath -Value $wf -Encoding utf8

    # Initialise a throwaway git repo so act has a HEAD to push from.
    Push-Location $stage
    try {
        git init -q -b main 2>&1 | Out-Null
        git config user.email 'act@example.com'
        git config user.name  'act'
        git add -A
        git commit -q -m 'staged for act run' | Out-Null

        Write-Host "[case=$($Case.Name)] running act push --rm"
        # Capture combined stdout + stderr.
        $logFile = Join-Path $stage 'act.log'
        $proc = Start-Process -FilePath act -ArgumentList @('push','--rm') `
            -WorkingDirectory $stage -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"
        $stdout = if (Test-Path $logFile)      { Get-Content -LiteralPath $logFile      -Raw } else { '' }
        $stderr = if (Test-Path "$logFile.err"){ Get-Content -LiteralPath "$logFile.err" -Raw } else { '' }
        $combined = @($stdout, $stderr) -join "`n"

        # Persist the output to the cumulative artifact.
        Write-Section ("CASE: {0}  (exit={1}, fixture_dir={2})" -f $Case.Name, $proc.ExitCode, $Case.FixtureDir)
        Add-Content -LiteralPath $ResultFile -Value $combined

        return @{ ExitCode = $proc.ExitCode; Output = $combined; StagePath = $stage }
    }
    finally {
        Pop-Location
    }
}

$failures = @()

foreach ($case in $cases) {
    Write-Host "=== Running case: $($case.Name) ==="
    $run = Invoke-ActCase -Case $case

    if ($run.ExitCode -ne 0) {
        $failures += "[$($case.Name)] act exited with code $($run.ExitCode)"
        continue
    }

    foreach ($token in $case.ExpectTokens) {
        if ($run.Output -notlike "*$token*") {
            $failures += "[$($case.Name)] missing expected token: $token"
        }
    }
    foreach ($job in $expectedJobs) {
        # act prints `Job succeeded` after each successful job; we also confirm
        # the job's friendly name appeared so we know the workflow actually ran.
        if ($run.Output -notlike "*$job*") {
            $failures += "[$($case.Name)] missing job name in output: $job"
        }
    }
    # act prints e.g. "[Test Results Aggregator/Pester unit tests] 🏁  Job succeeded"
    # for each successful job. Count those occurrences directly.
    $jobSuccessLines = ([regex]::Matches($run.Output, 'Job succeeded')).Count
    if ($jobSuccessLines -lt $expectedJobs.Count) {
        $failures += "[$($case.Name)] expected $($expectedJobs.Count) 'Job succeeded' lines, found $jobSuccessLines"
    }

    # Lightweight cleanup of the staging dir; ignore failures.
    Remove-Item -Recurse -Force -LiteralPath $run.StagePath -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    Write-Host '---- ACT TEST FAILURES ----'
    $failures | ForEach-Object { Write-Host $_ }
    throw "Act test harness failed: $($failures.Count) assertion(s) did not pass"
}
Write-Host '---- ACT TESTS PASSED ----'
Write-Host "Result log: $ResultFile"
