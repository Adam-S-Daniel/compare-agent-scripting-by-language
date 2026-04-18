# Pester tests for TestResultsAggregator module
# Uses red/green TDD - each Describe block was written to fail first, then code
# was added to make it pass.

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $modulePath -Force
    $script:FixturesDir = Join-Path $PSScriptRoot '..' 'fixtures'
}

Describe 'Import-JUnitXmlResult' {
    It 'parses a JUnit XML file into a normalized result object' {
        $path = Join-Path $TestDrive 'junit-basic.xml'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="root" tests="3" failures="1" skipped="1" time="0.250">
  <testsuite name="suiteA" tests="3" failures="1" skipped="1" time="0.250">
    <testcase classname="suiteA" name="passes" time="0.100" />
    <testcase classname="suiteA" name="fails" time="0.050">
      <failure message="boom">Assertion failed</failure>
    </testcase>
    <testcase classname="suiteA" name="skipped" time="0.000">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
'@ | Set-Content -Path $path -Encoding UTF8

        $result = Import-JUnitXmlResult -Path $path

        $result.Format   | Should -Be 'junit'
        $result.Source   | Should -Be $path
        $result.Totals.Total   | Should -Be 3
        $result.Totals.Passed  | Should -Be 1
        $result.Totals.Failed  | Should -Be 1
        $result.Totals.Skipped | Should -Be 1
        # duration is a double in seconds
        [math]::Round($result.Totals.DurationSeconds, 3) | Should -Be 0.250
        $result.Tests.Count | Should -Be 3

        $passed = $result.Tests | Where-Object { $_.Name -eq 'passes' }
        $passed.Outcome | Should -Be 'passed'
        $passed.Suite   | Should -Be 'suiteA'

        $failed = $result.Tests | Where-Object { $_.Name -eq 'fails' }
        $failed.Outcome | Should -Be 'failed'
        $failed.Message | Should -Match 'boom'

        $skipped = $result.Tests | Where-Object { $_.Name -eq 'skipped' }
        $skipped.Outcome | Should -Be 'skipped'
    }

    It 'handles a JUnit file with no <testsuites> wrapper' {
        $path = Join-Path $TestDrive 'junit-no-wrapper.xml'
        @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="solo" tests="2" failures="0" skipped="0" time="0.010">
  <testcase classname="solo" name="t1" time="0.005" />
  <testcase classname="solo" name="t2" time="0.005" />
</testsuite>
'@ | Set-Content -Path $path -Encoding UTF8

        $result = Import-JUnitXmlResult -Path $path
        $result.Totals.Total  | Should -Be 2
        $result.Totals.Passed | Should -Be 2
    }

    It 'throws a helpful error when the file does not exist' {
        { Import-JUnitXmlResult -Path (Join-Path $TestDrive 'missing.xml') } |
            Should -Throw -ErrorId 'FileNotFound,Import-JUnitXmlResult'
    }

    It 'throws a helpful error when the XML is not a JUnit document' {
        $path = Join-Path $TestDrive 'junit-bogus.xml'
        '<root><hello/></root>' | Set-Content -Path $path -Encoding UTF8
        { Import-JUnitXmlResult -Path $path } |
            Should -Throw -ErrorId 'InvalidJUnit,Import-JUnitXmlResult'
    }
}

Describe 'Import-JsonTestResult' {
    It 'parses a JSON file using the documented shape' {
        $path = Join-Path $TestDrive 'results.json'
        @'
{
  "durationSeconds": 1.5,
  "tests": [
    { "suite": "core", "name": "alpha", "outcome": "passed",  "durationSeconds": 0.5 },
    { "suite": "core", "name": "beta",  "outcome": "failed",  "durationSeconds": 0.7, "message": "bad value" },
    { "suite": "core", "name": "gamma", "outcome": "skipped", "durationSeconds": 0.0 }
  ]
}
'@ | Set-Content -Path $path -Encoding UTF8

        $r = Import-JsonTestResult -Path $path
        $r.Format | Should -Be 'json'
        $r.Totals.Total   | Should -Be 3
        $r.Totals.Passed  | Should -Be 1
        $r.Totals.Failed  | Should -Be 1
        $r.Totals.Skipped | Should -Be 1
        $r.Totals.DurationSeconds | Should -Be 1.5
        ($r.Tests | Where-Object Name -eq 'beta').Message | Should -Be 'bad value'
    }

    It 'throws when outcome is invalid' {
        $path = Join-Path $TestDrive 'results-bad.json'
        '{"tests":[{"suite":"s","name":"n","outcome":"weird"}]}' | Set-Content -Path $path
        { Import-JsonTestResult -Path $path } | Should -Throw -ErrorId 'InvalidOutcome,Import-JsonTestResult'
    }

    It 'throws when the JSON is malformed' {
        $path = Join-Path $TestDrive 'malformed.json'
        '{ this is not json' | Set-Content -Path $path
        { Import-JsonTestResult -Path $path } | Should -Throw -ErrorId 'InvalidJson,Import-JsonTestResult'
    }
}

Describe 'Import-TestResultFile (format dispatcher)' {
    It 'dispatches .xml files to the JUnit parser' {
        $path = Join-Path $TestDrive 'dispatch.xml'
        '<testsuite name="s" tests="1" failures="0" skipped="0" time="0.1"><testcase classname="s" name="t" time="0.1" /></testsuite>' |
            Set-Content -Path $path
        (Import-TestResultFile -Path $path).Format | Should -Be 'junit'
    }

    It 'dispatches .json files to the JSON parser' {
        $path = Join-Path $TestDrive 'dispatch.json'
        '{"tests":[{"suite":"s","name":"t","outcome":"passed"}]}' | Set-Content -Path $path
        (Import-TestResultFile -Path $path).Format | Should -Be 'json'
    }

    It 'throws on an unknown extension' {
        $path = Join-Path $TestDrive 'dispatch.txt'
        'hello' | Set-Content -Path $path
        { Import-TestResultFile -Path $path } | Should -Throw -ErrorId 'UnknownFormat,Import-TestResultFile'
    }
}

Describe 'Merge-TestRun' {
    It 'sums totals across multiple runs and preserves per-run lineage' {
        $runA = [pscustomobject]@{
            Format = 'junit'; Source = 'a.xml'
            Totals = [pscustomobject]@{ Total = 2; Passed = 2; Failed = 0; Skipped = 0; DurationSeconds = 1.0 }
            Tests  = @(
                [pscustomobject]@{ Suite = 's'; Name = 't1'; Outcome = 'passed'; DurationSeconds = 0.5; Message = $null },
                [pscustomobject]@{ Suite = 's'; Name = 't2'; Outcome = 'passed'; DurationSeconds = 0.5; Message = $null }
            )
        }
        $runB = [pscustomobject]@{
            Format = 'json'; Source = 'b.json'
            Totals = [pscustomobject]@{ Total = 2; Passed = 1; Failed = 1; Skipped = 0; DurationSeconds = 0.5 }
            Tests  = @(
                [pscustomobject]@{ Suite = 's'; Name = 't1'; Outcome = 'failed'; DurationSeconds = 0.3; Message = 'x' },
                [pscustomobject]@{ Suite = 's'; Name = 't3'; Outcome = 'passed'; DurationSeconds = 0.2; Message = $null }
            )
        }

        $agg = Merge-TestRun -Runs @($runA, $runB)
        $agg.Totals.Total   | Should -Be 4
        $agg.Totals.Passed  | Should -Be 3
        $agg.Totals.Failed  | Should -Be 1
        $agg.Totals.Skipped | Should -Be 0
        [math]::Round($agg.Totals.DurationSeconds, 3) | Should -Be 1.5
        $agg.Runs.Count     | Should -Be 2
    }
}

Describe 'Find-FlakyTest' {
    It 'returns tests that passed at least once AND failed at least once' {
        $runA = [pscustomobject]@{
            Format='junit'; Source='a'; Totals=$null;
            Tests = @(
                [pscustomobject]@{ Suite='s'; Name='stable_pass'; Outcome='passed'; DurationSeconds=0.1; Message=$null },
                [pscustomobject]@{ Suite='s'; Name='flaky';       Outcome='passed'; DurationSeconds=0.1; Message=$null },
                [pscustomobject]@{ Suite='s'; Name='stable_fail'; Outcome='failed'; DurationSeconds=0.1; Message='x' }
            )
        }
        $runB = [pscustomobject]@{
            Format='junit'; Source='b'; Totals=$null;
            Tests = @(
                [pscustomobject]@{ Suite='s'; Name='stable_pass'; Outcome='passed'; DurationSeconds=0.1; Message=$null },
                [pscustomobject]@{ Suite='s'; Name='flaky';       Outcome='failed'; DurationSeconds=0.1; Message='flap' },
                [pscustomobject]@{ Suite='s'; Name='stable_fail'; Outcome='failed'; DurationSeconds=0.1; Message='y' }
            )
        }
        $flaky = Find-FlakyTest -Runs @($runA, $runB)
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be 'flaky'
        $flaky[0].PassCount | Should -Be 1
        $flaky[0].FailCount | Should -Be 1
    }

    It 'returns no flaky tests when nothing flips' {
        $run = [pscustomobject]@{
            Format='junit'; Source='a'; Totals=$null;
            Tests = @(
                [pscustomobject]@{ Suite='s'; Name='a'; Outcome='passed'; DurationSeconds=0.1; Message=$null }
            )
        }
        (Find-FlakyTest -Runs @($run, $run)).Count | Should -Be 0
    }

    It 'does not mistake skipped+passed for flaky' {
        $runA = [pscustomobject]@{
            Format='junit'; Source='a'; Totals=$null;
            Tests = @([pscustomobject]@{ Suite='s'; Name='t'; Outcome='passed'; DurationSeconds=0.1; Message=$null })
        }
        $runB = [pscustomobject]@{
            Format='junit'; Source='b'; Totals=$null;
            Tests = @([pscustomobject]@{ Suite='s'; Name='t'; Outcome='skipped'; DurationSeconds=0.0; Message=$null })
        }
        (Find-FlakyTest -Runs @($runA, $runB)).Count | Should -Be 0
    }
}

Describe 'New-MarkdownSummary' {
    It 'produces a markdown summary with totals, per-run breakdown, and flaky section' {
        $runA = [pscustomobject]@{
            Format='junit'; Source='run-a.xml';
            Totals=[pscustomobject]@{ Total=2; Passed=1; Failed=1; Skipped=0; DurationSeconds=0.4 }
            Tests=@(
                [pscustomobject]@{ Suite='s'; Name='good'; Outcome='passed'; DurationSeconds=0.2; Message=$null },
                [pscustomobject]@{ Suite='s'; Name='flap'; Outcome='failed'; DurationSeconds=0.2; Message='nope' }
            )
        }
        $runB = [pscustomobject]@{
            Format='json'; Source='run-b.json';
            Totals=[pscustomobject]@{ Total=2; Passed=2; Failed=0; Skipped=0; DurationSeconds=0.3 }
            Tests=@(
                [pscustomobject]@{ Suite='s'; Name='good'; Outcome='passed'; DurationSeconds=0.1; Message=$null },
                [pscustomobject]@{ Suite='s'; Name='flap'; Outcome='passed'; DurationSeconds=0.2; Message=$null }
            )
        }
        $agg   = Merge-TestRun -Runs @($runA, $runB)
        $flaky = Find-FlakyTest -Runs @($runA, $runB)
        $md    = New-MarkdownSummary -Aggregate $agg -Flaky $flaky

        $md | Should -Match '# Test Results Summary'
        $md | Should -Match '\| Total +\| 4 \|'
        $md | Should -Match '\| Passed +\| 3 \|'
        $md | Should -Match '\| Failed +\| 1 \|'
        $md | Should -Match 'Flaky tests \(1\)'
        $md | Should -Match 'flap'
        $md | Should -Match 'run-a\.xml'
        $md | Should -Match 'run-b\.json'
    }

    It 'shows "no flaky tests" when the flaky list is empty' {
        $run = [pscustomobject]@{
            Format='junit'; Source='r.xml';
            Totals=[pscustomobject]@{ Total=1; Passed=1; Failed=0; Skipped=0; DurationSeconds=0.1 }
            Tests=@([pscustomobject]@{ Suite='s'; Name='t'; Outcome='passed'; DurationSeconds=0.1; Message=$null })
        }
        $agg = Merge-TestRun -Runs @($run)
        $md  = New-MarkdownSummary -Aggregate $agg -Flaky @()
        $md  | Should -Match 'No flaky tests detected'
    }
}

Describe 'Invoke-TestResultsAggregator (end-to-end)' {
    It 'reads fixtures, writes markdown, and exits with the correct overall status' {
        $outDir = Join-Path $TestDrive 'e2e'
        New-Item -ItemType Directory -Path $outDir | Out-Null
        $summary = Join-Path $outDir 'summary.md'

        $fixtures = Get-ChildItem -Path $script:FixturesDir -File | ForEach-Object { $_.FullName }

        $res = Invoke-TestResultsAggregator -Paths $fixtures -SummaryPath $summary

        Test-Path $summary | Should -BeTrue
        (Get-Content $summary -Raw) | Should -Match 'Test Results Summary'

        $res.Aggregate.Totals.Total | Should -BeGreaterThan 0
        $res.OverallStatus          | Should -BeIn @('passed', 'failed')
    }
}
