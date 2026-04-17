# Pester 5 tests for TestResultsAggregator. Written TDD-style: each Describe
# block corresponds to one unit of functionality that was developed red-green.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force

    # Unit tests build their own fixtures in $TestDrive rather than relying
    # on the checked-in fixtures/ directory — that way the tests stay valid
    # even when the repo's fixtures are swapped out (as the act harness does).
    $script:FixtureDir = Join-Path $TestDrive 'fixtures'
    New-Item -ItemType Directory -Path $script:FixtureDir | Out-Null

    @'
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
'@ | Set-Content -LiteralPath (Join-Path $script:FixtureDir 'run1-junit.xml') -Encoding utf8

    @'
{
  "run": "r2",
  "tests": [
    { "suite": "core", "name": "test_add",             "status": "passed",  "duration": 0.04 },
    { "suite": "core", "name": "test_network_timeout", "status": "passed",  "duration": 0.90 },
    { "suite": "core", "name": "test_divide",          "status": "failed",  "duration": 0.12 },
    { "suite": "core", "name": "test_legacy",          "status": "skipped", "duration": 0.00 }
  ]
}
'@ | Set-Content -LiteralPath (Join-Path $script:FixtureDir 'run2-results.json') -Encoding utf8
}

Describe 'Import-JUnitXml' {
    It 'parses passed, failed, and skipped testcases from a JUnit XML file' {
        $run = Import-JUnitXml -Path (Join-Path $script:FixtureDir 'run1-junit.xml')
        $run.Format  | Should -Be 'junit'
        $run.Results.Count | Should -Be 4
        ($run.Results | Where-Object Status -eq 'passed').Count  | Should -Be 2
        ($run.Results | Where-Object Status -eq 'failed').Count  | Should -Be 1
        ($run.Results | Where-Object Status -eq 'skipped').Count | Should -Be 1
    }

    It 'throws a clear error when the file is missing' {
        { Import-JUnitXml -Path (Join-Path $script:FixtureDir 'nope.xml') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'captures test duration as a double' {
        $run = Import-JUnitXml -Path (Join-Path $script:FixtureDir 'run1-junit.xml')
        $run.Results[0].Duration | Should -BeOfType [double]
    }
}

Describe 'Import-TestResultJson' {
    It 'parses a JSON file containing a tests array' {
        $run = Import-TestResultJson -Path (Join-Path $script:FixtureDir 'run2-results.json')
        $run.Format  | Should -Be 'json'
        $run.Results.Count | Should -Be 4
    }

    It 'rejects unknown status values' {
        $bad = Join-Path $TestDrive 'bad.json'
        '{"tests":[{"name":"x","status":"weird","duration":0}]}' | Set-Content $bad
        { Import-TestResultJson -Path $bad } | Should -Throw -ExpectedMessage "*Unknown test status*"
    }
}

Describe 'Merge-TestResults' {
    It 'aggregates totals across multiple runs' {
        $r1 = Import-JUnitXml       -Path (Join-Path $script:FixtureDir 'run1-junit.xml')
        $r2 = Import-TestResultJson -Path (Join-Path $script:FixtureDir 'run2-results.json')
        $agg = Merge-TestResults -Runs @($r1, $r2)

        $agg.FileCount | Should -Be 2
        $agg.Total     | Should -Be 8
        $agg.Passed    | Should -BeGreaterOrEqual 1
        $agg.Failed    | Should -BeGreaterOrEqual 1
    }

    It 'identifies flaky tests (same name, different outcomes across runs)' {
        $r1 = Import-JUnitXml       -Path (Join-Path $script:FixtureDir 'run1-junit.xml')
        $r2 = Import-TestResultJson -Path (Join-Path $script:FixtureDir 'run2-results.json')
        $agg = Merge-TestResults -Runs @($r1, $r2)

        $agg.Flaky.Count | Should -BeGreaterThan 0
        $agg.Flaky[0].Name | Should -Match 'test_network_timeout'
    }
}

Describe 'ConvertTo-MarkdownSummary' {
    It 'produces a markdown summary with totals table and flaky section' {
        $r1 = Import-JUnitXml       -Path (Join-Path $script:FixtureDir 'run1-junit.xml')
        $r2 = Import-TestResultJson -Path (Join-Path $script:FixtureDir 'run2-results.json')
        $agg = Merge-TestResults -Runs @($r1, $r2)

        $md = ConvertTo-MarkdownSummary -Aggregate $agg
        $md | Should -Match '# Test Results Summary'
        $md | Should -Match '\| Total Tests \| 8 \|'
        $md | Should -Match 'Flaky Tests'
        $md | Should -Match 'test_network_timeout'
    }

    It 'marks overall status as PASSED when there are no failures' {
        $r = [pscustomobject]@{
            FileCount = 1; Total = 2; Passed = 2; Failed = 0; Skipped = 0
            Duration  = 0.1; Flaky = @(); Runs = @([pscustomobject]@{Results=@()})
        }
        (ConvertTo-MarkdownSummary -Aggregate $r) | Should -Match 'Overall Status:\*\* PASSED'
    }
}

Describe 'Invoke-TestResultsAggregation' {
    It 'discovers files in a directory and writes markdown to OutputPath' {
        $out = Join-Path $TestDrive 'summary.md'
        $agg = Invoke-TestResultsAggregation -InputPath $script:FixtureDir -OutputPath $out
        Test-Path $out | Should -BeTrue
        (Get-Content $out -Raw) | Should -Match '# Test Results Summary'
        $agg.FileCount | Should -Be 2
    }

    It 'throws a clear error if input path does not exist' {
        { Invoke-TestResultsAggregation -InputPath (Join-Path $TestDrive 'does-not-exist') } |
            Should -Throw -ExpectedMessage '*does not exist*'
    }
}
