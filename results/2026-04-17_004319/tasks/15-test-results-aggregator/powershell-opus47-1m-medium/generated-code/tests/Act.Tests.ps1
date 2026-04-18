# Integration test harness: sets up temp git repos per test case, runs `act
# push --rm`, captures output to act-result.txt, and asserts on exact values.

BeforeAll {
    $script:RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ActResult  = Join-Path $script:RepoRoot 'act-result.txt'
    # Start fresh each run so the file contains only this run's output.
    Set-Content -LiteralPath $script:ActResult -Value "# act results log`n" -Encoding utf8

    function script:Invoke-ActCase {
        param(
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][hashtable]$Fixtures  # filename -> content
        )
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("act-$Name-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        # Copy project files
        Copy-Item -Recurse (Join-Path $script:RepoRoot '.github')   $tmp
        Copy-Item -Recurse (Join-Path $script:RepoRoot 'src')       $tmp
        Copy-Item -Recurse (Join-Path $script:RepoRoot 'tests')     $tmp
        Copy-Item          (Join-Path $script:RepoRoot 'aggregate.ps1') $tmp
        Copy-Item          (Join-Path $script:RepoRoot '.actrc')       $tmp

        # Write per-case fixtures
        $fxDir = Join-Path $tmp 'fixtures'
        New-Item -ItemType Directory -Path $fxDir | Out-Null
        foreach ($k in $Fixtures.Keys) {
            Set-Content -LiteralPath (Join-Path $fxDir $k) -Value $Fixtures[$k] -Encoding utf8
        }

        Push-Location $tmp
        try {
            git init -q
            git -c user.email=t@t -c user.name=t add -A
            git -c user.email=t@t -c user.name=t commit -qm 'test'
            $out = act push --rm --workflows .github/workflows/test-results-aggregator.yml 2>&1 | Out-String
            $exit = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append to global act-result.txt with a clear delimiter
        $delim = "`n===== CASE: $Name (exit=$exit) =====`n"
        Add-Content -LiteralPath $script:ActResult -Value ($delim + $out) -Encoding utf8
        Remove-Item -Recurse -Force $tmp

        [pscustomobject]@{ Name = $Name; ExitCode = $exit; Output = $out }
    }

    # Fixtures reused by cases
    $script:Junit1 = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="r1" tests="4" failures="1" skipped="1" time="1.44">
  <testsuite name="core" tests="4" failures="1" skipped="1" time="1.44">
    <testcase classname="core" name="test_add" time="0.050"/>
    <testcase classname="core" name="test_subtract" time="0.030"/>
    <testcase classname="core" name="test_network_timeout" time="1.200">
      <failure message="Timed out" type="TimeoutError">stack</failure>
    </testcase>
    <testcase classname="core" name="test_deprecated" time="0.160">
      <skipped message="retired"/>
    </testcase>
  </testsuite>
</testsuites>
'@

    $script:Json2 = @'
{
  "run": "r2",
  "tests": [
    { "suite": "core", "name": "test_add",             "status": "passed",  "duration": 0.04 },
    { "suite": "core", "name": "test_network_timeout", "status": "passed",  "duration": 0.90 },
    { "suite": "core", "name": "test_divide",          "status": "failed",  "duration": 0.12 },
    { "suite": "core", "name": "test_legacy",          "status": "skipped", "duration": 0.00 }
  ]
}
'@
}

Describe 'Workflow structure' {
    It 'actionlint passes' {
        $null = & actionlint (Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml')
        $LASTEXITCODE | Should -Be 0
    }
    It 'workflow references script paths that exist' {
        $wf = Get-Content (Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml') -Raw
        $wf | Should -Match 'aggregate\.ps1'
        $wf | Should -Match 'src/TestResultsAggregator\.psm1'
        Test-Path (Join-Path $script:RepoRoot 'aggregate.ps1')                       | Should -BeTrue
        Test-Path (Join-Path $script:RepoRoot 'src/TestResultsAggregator.psm1')      | Should -BeTrue
    }
    It 'declares expected triggers and jobs' {
        $wf = Get-Content (Join-Path $script:RepoRoot '.github/workflows/test-results-aggregator.yml') -Raw
        $wf | Should -Match '(?m)^on:'
        $wf | Should -Match 'push:'
        $wf | Should -Match 'pull_request:'
        $wf | Should -Match 'workflow_dispatch:'
        $wf | Should -Match 'schedule:'
        $wf | Should -Match 'aggregate:'
    }
}

Describe 'Act integration' -Tag Integration {
    It 'Case A: mixed JUnit + JSON, 1 flaky, 1 consistent failure' {
        $r = Invoke-ActCase -Name 'A-mixed' -Fixtures @{
            'run1-junit.xml'   = $script:Junit1
            'run2-results.json'= $script:Json2
        }
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'AGGREGATE_VALUES total=8 passed=4 failed=2 skipped=2 flaky=1 flaky_name=core\.test_network_timeout'
        $r.Output   | Should -Match 'Total: 8 Passed: 4 Failed: 2 Skipped: 2'
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 1
    }

    It 'Case B: all passing, no flaky' {
        $p1 = @'
{ "tests": [
  { "suite": "s", "name": "t1", "status": "passed", "duration": 0.01 },
  { "suite": "s", "name": "t2", "status": "passed", "duration": 0.02 }
] }
'@
        $p2 = @'
{ "tests": [
  { "suite": "s", "name": "t1", "status": "passed", "duration": 0.01 },
  { "suite": "s", "name": "t2", "status": "passed", "duration": 0.02 }
] }
'@
        $r = Invoke-ActCase -Name 'B-allpass' -Fixtures @{ 'r1.json' = $p1; 'r2.json' = $p2 }
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'AGGREGATE_VALUES total=4 passed=4 failed=0 skipped=0 flaky=0 flaky_name=none'
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 1
    }

    It 'Case C: two flaky tests across three runs' {
        $j = @'
<?xml version="1.0"?>
<testsuites><testsuite name="s">
  <testcase classname="s" name="alpha" time="0.1"/>
  <testcase classname="s" name="beta"  time="0.1"><failure message="x"/></testcase>
</testsuite></testsuites>
'@
        $k = @'
{ "tests": [
  { "suite": "s", "name": "alpha", "status": "failed", "duration": 0.1 },
  { "suite": "s", "name": "beta",  "status": "passed", "duration": 0.1 }
] }
'@
        $l = @'
{ "tests": [
  { "suite": "s", "name": "alpha", "status": "passed", "duration": 0.1 },
  { "suite": "s", "name": "beta",  "status": "passed", "duration": 0.1 }
] }
'@
        $r = Invoke-ActCase -Name 'C-twoflaky' -Fixtures @{ 'r1.xml' = $j; 'r2.json' = $k; 'r3.json' = $l }
        $r.ExitCode | Should -Be 0
        $r.Output   | Should -Match 'AGGREGATE_VALUES total=6 passed=4 failed=2 skipped=0 flaky=2'
        ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 1
    }
}
