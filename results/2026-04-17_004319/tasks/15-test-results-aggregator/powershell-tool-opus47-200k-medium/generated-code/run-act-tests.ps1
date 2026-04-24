#!/usr/bin/env pwsh
# Test harness: runs the workflow via `act push --rm` for each test case,
# appending all output to act-result.txt and asserting exact expected values.
#
# Each case stages the project in a temp git repo, overwrites the fixtures
# directory with that case's inputs, runs act, and parses the summary output.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$resultFile  = Join-Path $projectRoot 'act-result.txt'
if (Test-Path $resultFile) { Remove-Item $resultFile -Force }

# Test cases. Each case has fixture files and expected metrics extracted from
# the "RESULT passed=... failed=... skipped=... total=... duration=... flaky=..."
# line emitted by aggregate.ps1.
$cases = @(
    @{
        Name = 'baseline-fixtures (xml+json, 1 flaky)'
        Fixtures = @{
            'run1.xml'  = (Get-Content (Join-Path $projectRoot 'fixtures/run1.xml') -Raw)
            'run2.json' = (Get-Content (Join-Path $projectRoot 'fixtures/run2.json') -Raw)
        }
        ExpectedPassed  = 5
        ExpectedFailed  = 1
        ExpectedSkipped = 2
        ExpectedTotal   = 8
        ExpectedFlaky   = 1
        ExpectedFlakyNames = @('test_flaky')
    },
    @{
        Name = 'all-pass (no flaky, no failures)'
        Fixtures = @{
            'run1.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="api" tests="2" failures="0" skipped="0" time="0.50">
    <testcase classname="api" name="test_get" time="0.25"/>
    <testcase classname="api" name="test_post" time="0.25"/>
  </testsuite>
</testsuites>
'@
            'run2.json' = @'
{"suite":"api","tests":[
  {"name":"test_get","status":"passed","duration":0.2},
  {"name":"test_post","status":"passed","duration":0.3}
]}
'@
        }
        ExpectedPassed  = 4
        ExpectedFailed  = 0
        ExpectedSkipped = 0
        ExpectedTotal   = 4
        ExpectedFlaky   = 0
        ExpectedFlakyNames = @()
    },
    @{
        Name = 'two-flaky (two tests flap across runs)'
        Fixtures = @{
            'run1.xml' = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="svc" tests="3" failures="2" skipped="0" time="1.00">
    <testcase classname="svc" name="test_a" time="0.3"/>
    <testcase classname="svc" name="test_b" time="0.3"><failure message="x">x</failure></testcase>
    <testcase classname="svc" name="test_c" time="0.4"><failure message="y">y</failure></testcase>
  </testsuite>
</testsuites>
'@
            'run2.json' = @'
{"suite":"svc","tests":[
  {"name":"test_a","status":"passed","duration":0.3},
  {"name":"test_b","status":"passed","duration":0.3},
  {"name":"test_c","status":"passed","duration":0.4}
]}
'@
        }
        ExpectedPassed  = 4
        ExpectedFailed  = 2
        ExpectedSkipped = 0
        ExpectedTotal   = 6
        ExpectedFlaky   = 2
        ExpectedFlakyNames = @('test_b', 'test_c')
    }
)

# Files to stage into the temp repo for every run.
$projectFiles = @(
    'TestResultsAggregator.psm1',
    'TestResultsAggregator.Tests.ps1',
    'aggregate.ps1',
    '.github/workflows/test-results-aggregator.yml'
)

function Invoke-ActCase {
    param([hashtable]$Case)

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("act-case-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        foreach ($rel in $projectFiles) {
            $src = Join-Path $projectRoot $rel
            $dst = Join-Path $tmp $rel
            $dstDir = Split-Path -Parent $dst
            if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
            Copy-Item $src $dst
        }
        # Copy .actrc so act picks the pwsh-enabled image.
        Copy-Item (Join-Path $projectRoot '.actrc') (Join-Path $tmp '.actrc')

        # Copy the committed fixtures/ directory as-is so Pester tests pass.
        Copy-Item (Join-Path $projectRoot 'fixtures') (Join-Path $tmp 'fixtures') -Recurse

        # Write this case's data into input/ so the workflow aggregates it.
        $inDir = Join-Path $tmp 'input'
        New-Item -ItemType Directory -Path $inDir | Out-Null
        foreach ($k in $Case.Fixtures.Keys) {
            Set-Content -LiteralPath (Join-Path $inDir $k) -Value $Case.Fixtures[$k] -Encoding utf8
        }

        git -C $tmp init -q
        git -C $tmp -c user.email=t@t -c user.name=t add -A
        git -C $tmp -c user.email=t@t -c user.name=t commit -q -m init

        Push-Location $tmp
        try {
            $out = & act push --rm --pull=false 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        [pscustomobject]@{
            Output   = $out
            ExitCode = $exit
        }
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Case {
    param([hashtable]$Case, [string]$Output, [int]$ExitCode)

    $errors = [System.Collections.Generic.List[string]]::new()

    if ($ExitCode -ne 0) { $errors.Add("act exit code was $ExitCode (expected 0)") }

    # Assert every job succeeded. act prints 'Job succeeded' per job.
    if ($Output -notmatch 'Job succeeded') {
        $errors.Add("'Job succeeded' not found in act output")
    }

    # Match the LAST RESULT line — the Pester step (which reads baseline
    # fixtures) emits one too; we want the aggregate step's line.
    $matches2 = [regex]::Matches($Output,
        'RESULT passed=(?<p>\d+) failed=(?<f>\d+) skipped=(?<s>\d+) total=(?<t>\d+) duration=(?<d>[\d.]+) flaky=(?<fl>\d+)')
    if ($matches2.Count -eq 0) {
        $errors.Add("RESULT line not found in output")
    } else {
        $m = $matches2[$matches2.Count - 1]
        $p  = [int]$m.Groups['p'].Value
        $f  = [int]$m.Groups['f'].Value
        $s  = [int]$m.Groups['s'].Value
        $tt = [int]$m.Groups['t'].Value
        $fl = [int]$m.Groups['fl'].Value
        if ($p  -ne $Case.ExpectedPassed)  { $errors.Add("passed=$p expected $($Case.ExpectedPassed)") }
        if ($f  -ne $Case.ExpectedFailed)  { $errors.Add("failed=$f expected $($Case.ExpectedFailed)") }
        if ($s  -ne $Case.ExpectedSkipped) { $errors.Add("skipped=$s expected $($Case.ExpectedSkipped)") }
        if ($tt -ne $Case.ExpectedTotal)   { $errors.Add("total=$tt expected $($Case.ExpectedTotal)") }
        if ($fl -ne $Case.ExpectedFlaky)   { $errors.Add("flaky=$fl expected $($Case.ExpectedFlaky)") }
    }

    foreach ($name in $Case.ExpectedFlakyNames) {
        if ($Output -notmatch [regex]::Escape("FLAKY $name")) {
            $errors.Add("expected FLAKY $name not present")
        }
    }

    # Assert the markdown summary content landed in the log.
    if ($Output -notmatch '# Test Results Summary') {
        $errors.Add("markdown header not found in output")
    }

    $errors
}

$failedCases = [System.Collections.Generic.List[string]]::new()

foreach ($case in $cases) {
    Write-Host "===== Running case: $($case.Name) =====" -ForegroundColor Cyan
    $r = Invoke-ActCase -Case $case

    Add-Content -LiteralPath $resultFile -Value ""
    Add-Content -LiteralPath $resultFile -Value "===== CASE: $($case.Name) (exit=$($r.ExitCode)) ====="
    Add-Content -LiteralPath $resultFile -Value $r.Output
    Add-Content -LiteralPath $resultFile -Value "===== END CASE: $($case.Name) ====="

    $errs = @(Assert-Case -Case $case -Output $r.Output -ExitCode $r.ExitCode)
    if ($errs.Count -gt 0) {
        $failedCases.Add($case.Name)
        Write-Host "FAIL: $($case.Name)" -ForegroundColor Red
        foreach ($e in $errs) { Write-Host "   - $e" -ForegroundColor Red }
    } else {
        Write-Host "PASS: $($case.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Result file: $resultFile"
if ($failedCases.Count -gt 0) {
    Write-Host "FAILED cases: $($failedCases -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "All cases passed." -ForegroundColor Green
exit 0
