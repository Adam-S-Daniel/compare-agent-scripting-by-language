#!/usr/bin/env pwsh
# run-act-tests.ps1
#
# End-to-end harness: for each test case, build an isolated temp git repo
# containing the project + the case's fixtures, run `act push --rm`, append
# the output to act-result.txt, and assert exact expected values.
#
# Constraint: at most 3 `act push` runs (per benchmark rules). Accordingly we
# define exactly three cases: all-green, a failure case, and a flaky case.

[CmdletBinding()]
param(
    # Skip actually running act (useful for debugging the harness itself).
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$RepoRoot     = Resolve-Path (Join-Path $PSScriptRoot '..')
$ActResultLog = Join-Path $RepoRoot 'act-result.txt'

# Start with a fresh append log so each full run produces one artifact.
Set-Content -LiteralPath $ActResultLog -Value "" -Encoding UTF8

function Write-Delim([string]$msg) {
    $line = '=' * 72
    Add-Content -LiteralPath $ActResultLog -Value $line
    Add-Content -LiteralPath $ActResultLog -Value $msg
    Add-Content -LiteralPath $ActResultLog -Value $line
    Write-Host "`n$line`n$msg`n$line"
}

# ---------- define test cases --------------------------------------------
#
# Each case produces a distinct set of fixture files and a set of expected
# RECAP numbers printed by Aggregate-TestResults.ps1 (format: "RECAP::TOTALS
# total=X passed=X failed=X skipped=X duration=Xs flaky=X status=X").

$cases = @(
    @{
        Name = 'all-green'
        Fixtures = @{
            'pass-a.xml' = @'
<?xml version="1.0"?>
<testsuite name="s" tests="2" failures="0" skipped="0" time="0.20">
  <testcase classname="s" name="one" time="0.10"/>
  <testcase classname="s" name="two" time="0.10"/>
</testsuite>
'@
            'pass-b.json' = @'
{
  "durationSeconds": 0.30,
  "tests": [
    { "suite": "s", "name": "one", "outcome": "passed", "durationSeconds": 0.10 },
    { "suite": "s", "name": "two", "outcome": "passed", "durationSeconds": 0.20 }
  ]
}
'@
        }
        Expected = @{
            total   = 4
            passed  = 4
            failed  = 0
            skipped = 0
            flaky   = 0
            status  = 'passed'
        }
    },
    @{
        Name = 'hard-failure'
        Fixtures = @{
            'fail-a.xml' = @'
<?xml version="1.0"?>
<testsuite name="s" tests="3" failures="1" skipped="1" time="0.30">
  <testcase classname="s" name="good" time="0.10"/>
  <testcase classname="s" name="bad" time="0.10"><failure message="nope">boom</failure></testcase>
  <testcase classname="s" name="todo" time="0.00"><skipped/></testcase>
</testsuite>
'@
            'fail-b.json' = @'
{
  "durationSeconds": 0.30,
  "tests": [
    { "suite": "s", "name": "good", "outcome": "passed",  "durationSeconds": 0.10 },
    { "suite": "s", "name": "bad",  "outcome": "failed",  "durationSeconds": 0.10, "message": "still bad" },
    { "suite": "s", "name": "todo", "outcome": "skipped", "durationSeconds": 0.0  }
  ]
}
'@
        }
        Expected = @{
            total   = 6
            passed  = 2
            failed  = 2
            skipped = 2
            flaky   = 0       # 'bad' fails in BOTH runs -> stable failure, not flaky
            status  = 'failed'
        }
    },
    @{
        Name = 'flaky'
        Fixtures = @{
            'flaky-a.xml' = @'
<?xml version="1.0"?>
<testsuite name="s" tests="3" failures="0" skipped="0" time="0.30">
  <testcase classname="s" name="stable" time="0.10"/>
  <testcase classname="s" name="wobbly" time="0.10"/>
  <testcase classname="s" name="also_stable" time="0.10"/>
</testsuite>
'@
            'flaky-b.json' = @'
{
  "durationSeconds": 0.30,
  "tests": [
    { "suite": "s", "name": "stable",      "outcome": "passed", "durationSeconds": 0.10 },
    { "suite": "s", "name": "wobbly",      "outcome": "failed", "durationSeconds": 0.10, "message": "flaked" },
    { "suite": "s", "name": "also_stable", "outcome": "passed", "durationSeconds": 0.10 }
  ]
}
'@
        }
        Expected = @{
            total   = 6
            passed  = 5
            failed  = 1
            skipped = 0
            flaky   = 1     # 'wobbly' passed in run A, failed in run B
            status  = 'failed'
        }
    }
)

# ---------- set up isolated repo per case --------------------------------

function New-IsolatedRepo {
    param([string]$CaseName, [hashtable]$Fixtures)

    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("act-run-" + $CaseName + "-" + [System.Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $workDir | Out-Null

    # Copy project files we need for the workflow to work. Use a curated list
    # (rather than cp -r .) so stray build artifacts don't leak in.
    $copy = @(
        'Aggregate-TestResults.ps1',
        'src',
        'tests',
        '.github',
        '.actrc'
    )
    foreach ($item in $copy) {
        $src = Join-Path $RepoRoot $item
        if (-not (Test-Path -LiteralPath $src)) { continue }
        Copy-Item -LiteralPath $src -Destination $workDir -Recurse
    }

    # Replace fixtures with case-specific ones.
    $fixDir = Join-Path $workDir 'fixtures'
    if (Test-Path $fixDir) { Remove-Item -Recurse -Force $fixDir }
    New-Item -ItemType Directory -Path $fixDir | Out-Null
    foreach ($name in $Fixtures.Keys) {
        Set-Content -LiteralPath (Join-Path $fixDir $name) -Value $Fixtures[$name] -Encoding UTF8
    }

    # Turn it into a git repo — act requires one to determine the ref.
    Push-Location $workDir
    try {
        & git init -q -b main
        & git -c user.email=a@b -c user.name=a config commit.gpgsign false | Out-Null
        & git add -A
        & git -c user.email=a@b -c user.name=a commit -q -m "case: $CaseName" | Out-Null
    } finally {
        Pop-Location
    }

    $workDir
}

function Assert-Recap {
    param([string]$Output, [hashtable]$Expected, [string]$CaseName)

    # Match "RECAP::TOTALS total=X passed=X failed=X skipped=X duration=Xs flaky=X status=X".
    $line = $null
    foreach ($l in ($Output -split "`r?`n")) {
        if ($l -match 'RECAP::TOTALS\s+total=') { $line = $l; break }
    }
    if (-not $line) { throw "[$CaseName] RECAP line not found in output" }

    $pattern = 'RECAP::TOTALS\s+total=(?<total>\d+)\s+passed=(?<passed>\d+)\s+failed=(?<failed>\d+)\s+skipped=(?<skipped>\d+)\s+duration=(?<duration>[\d.]+)s\s+flaky=(?<flaky>\d+)\s+status=(?<status>\w+)'
    if ($line -notmatch $pattern) { throw "[$CaseName] RECAP line did not match expected format: $line" }

    $actual = @{
        total   = [int]$Matches['total']
        passed  = [int]$Matches['passed']
        failed  = [int]$Matches['failed']
        skipped = [int]$Matches['skipped']
        flaky   = [int]$Matches['flaky']
        status  = $Matches['status']
    }

    foreach ($k in $Expected.Keys) {
        if ($actual[$k] -ne $Expected[$k]) {
            throw "[$CaseName] Expected $k=$($Expected[$k]) but got $($actual[$k])"
        }
    }
    Write-Host "[$CaseName] RECAP assertion passed: $line"
}

function Assert-JobSucceeded {
    param([string]$Output, [string[]]$ExpectedJobs, [string]$CaseName)

    # act prefixes lines with [<workflow-name>/<job-display-name>] and emits
    # a "Job succeeded" line when the job finishes cleanly. We match on the
    # job display names (the `name:` field of each job in the workflow).
    foreach ($job in $ExpectedJobs) {
        $pattern = [regex]::Escape($job) + '\].*Job succeeded'
        if ($Output -notmatch $pattern) {
            throw "[$CaseName] Job '$job' did not show 'Job succeeded'"
        }
    }
    # And there must be NO "Job failed" line.
    if ($Output -match 'Job failed') {
        throw "[$CaseName] Found 'Job failed' in act output"
    }
    Write-Host "[$CaseName] All expected jobs reported 'Job succeeded'"
}

# ---------- run each case ------------------------------------------------

$failed = $false

foreach ($case in $cases) {
    $name = $case.Name
    Write-Delim "CASE: $name"

    $work = New-IsolatedRepo -CaseName $name -Fixtures $case.Fixtures

    if ($DryRun) {
        Write-Host "[$name] DryRun - skipping act run. Workspace: $work"
        continue
    }

    Push-Location $work
    try {
        $outFile = [System.IO.Path]::GetTempFileName()
        # --pull=false: use the locally-built act-ubuntu-pwsh:latest image
        # rather than trying to fetch it from a registry.
        & act push --rm --pull=false 2>&1 | Tee-Object -FilePath $outFile
        $exit = $LASTEXITCODE
        $actOutput = Get-Content -LiteralPath $outFile -Raw
        Remove-Item -Force $outFile

        Add-Content -LiteralPath $ActResultLog -Value "`n----- act stdout for case '$name' (exit=$exit) -----`n"
        Add-Content -LiteralPath $ActResultLog -Value $actOutput

        try {
            if ($exit -ne 0) { throw "[$name] act exited with $exit (expected 0)" }
            # Display names come from the `name:` field of each job.
            Assert-JobSucceeded -Output $actOutput -ExpectedJobs @('Pester unit tests','Aggregate test results') -CaseName $name
            # The "aggregate" job emits the RECAP line.
            Assert-Recap -Output $actOutput -Expected $case.Expected -CaseName $name

            # Spot check additional known markers in the rendered summary.
            $case.Expected | Out-Null
            Add-Content -LiteralPath $ActResultLog -Value "[$name] PASSED"
            Write-Host "[$name] PASSED"
        } catch {
            Add-Content -LiteralPath $ActResultLog -Value "[$name] ASSERTION FAILED: $($_.Exception.Message)"
            Write-Host "[$name] ASSERTION FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $failed = $true
        }
    } finally {
        Pop-Location
        # Leave the work dir for post-mortem on failure; otherwise clean up.
        if (-not $failed) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
    }
}

Write-Delim "All cases complete."
if ($failed) {
    Write-Host 'One or more cases FAILED. See act-result.txt.' -ForegroundColor Red
    exit 1
}
Write-Host 'All cases PASSED.' -ForegroundColor Green
exit 0
