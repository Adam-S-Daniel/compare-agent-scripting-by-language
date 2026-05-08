# Pester tests for TestResultsAggregator module.
# These drive the implementation via TDD: each describe block targets a single
# function and was written *before* the implementation it exercises.

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src'
    Import-Module (Join-Path $script:ModuleRoot 'TestResultsAggregator.psm1') -Force
    $script:FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Read-JUnitTestResults' {
    It 'parses a single JUnit XML file into normalized test cases' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="suite-A" tests="3" failures="1" skipped="1" time="1.234">
  <testcase classname="A" name="passes" time="0.5"/>
  <testcase classname="A" name="fails" time="0.6">
    <failure message="boom">stack</failure>
  </testcase>
  <testcase classname="A" name="skipped" time="0.134">
    <skipped/>
  </testcase>
</testsuite>
'@
        $path = Join-Path $TestDrive 'a.xml'
        Set-Content -Path $path -Value $xml -Encoding UTF8

        $result = Read-JUnitTestResults -Path $path

        $result.Suite       | Should -Be 'suite-A'
        $result.Tests.Count | Should -Be 3
        ($result.Tests | Where-Object Status -EQ 'passed').Count  | Should -Be 1
        ($result.Tests | Where-Object Status -EQ 'failed').Count  | Should -Be 1
        ($result.Tests | Where-Object Status -EQ 'skipped').Count | Should -Be 1
        $result.Duration    | Should -Be 1.234
        $result.Source      | Should -Be (Resolve-Path $path).Path
    }

    It 'throws a meaningful error when the file is missing' {
        { Read-JUnitTestResults -Path (Join-Path $TestDrive 'nope.xml') } |
            Should -Throw -ExpectedMessage '*not found*'
    }

    It 'throws a meaningful error when the XML is malformed' {
        $path = Join-Path $TestDrive 'bad.xml'
        Set-Content -Path $path -Value '<not-xml' -Encoding UTF8
        { Read-JUnitTestResults -Path $path } |
            Should -Throw -ExpectedMessage '*Failed to parse*'
    }
}

Describe 'Read-JsonTestResults' {
    It 'parses a JSON test result file' {
        $json = @'
{
  "suite": "suite-B",
  "duration": 2.5,
  "tests": [
    { "classname": "B", "name": "ok",   "status": "passed",  "duration": 1.0 },
    { "classname": "B", "name": "boom", "status": "failed",  "duration": 1.5, "message": "kaboom" }
  ]
}
'@
        $path = Join-Path $TestDrive 'b.json'
        Set-Content -Path $path -Value $json -Encoding UTF8

        $result = Read-JsonTestResults -Path $path
        $result.Suite       | Should -Be 'suite-B'
        $result.Tests.Count | Should -Be 2
        $result.Duration    | Should -Be 2.5
        ($result.Tests | Where-Object Name -EQ 'boom').Status | Should -Be 'failed'
    }
}

Describe 'Get-TestResults (dispatch)' {
    It 'dispatches based on file extension' {
        $xmlPath  = Join-Path $TestDrive 'r.xml'
        $jsonPath = Join-Path $TestDrive 'r.json'
        Set-Content -Path $xmlPath -Encoding UTF8 -Value @'
<?xml version="1.0"?><testsuite name="x" tests="1" failures="0" time="0.1"><testcase classname="x" name="t" time="0.1"/></testsuite>
'@
        Set-Content -Path $jsonPath -Encoding UTF8 -Value '{"suite":"j","duration":0.1,"tests":[{"classname":"j","name":"t","status":"passed","duration":0.1}]}'

        (Get-TestResults -Path $xmlPath).Suite  | Should -Be 'x'
        (Get-TestResults -Path $jsonPath).Suite | Should -Be 'j'
    }

    It 'throws on unsupported file extension' {
        $path = Join-Path $TestDrive 'x.txt'
        Set-Content -Path $path -Value 'hi'
        { Get-TestResults -Path $path } | Should -Throw -ExpectedMessage '*Unsupported*'
    }
}

Describe 'Merge-TestResults' {
    It 'aggregates totals across multiple runs' {
        $r1 = @{ Suite='s'; Source='r1'; Duration=1.0; Tests=@(
            @{ ClassName='c'; Name='a'; Status='passed'; Duration=0.5 },
            @{ ClassName='c'; Name='b'; Status='failed'; Duration=0.5; Message='m' }
        )}
        $r2 = @{ Suite='s'; Source='r2'; Duration=2.0; Tests=@(
            @{ ClassName='c'; Name='a'; Status='passed';  Duration=0.5 },
            @{ ClassName='c'; Name='b'; Status='passed';  Duration=0.5 },
            @{ ClassName='c'; Name='d'; Status='skipped'; Duration=1.0 }
        )}
        $merged = Merge-TestResults -Results @($r1,$r2)

        $merged.Totals.Passed   | Should -Be 3
        $merged.Totals.Failed   | Should -Be 1
        $merged.Totals.Skipped  | Should -Be 1
        $merged.Totals.Total    | Should -Be 5
        $merged.Totals.Duration | Should -Be 3.0
        $merged.RunCount        | Should -Be 2
    }

    It 'identifies flaky tests (passed in some runs, failed in others)' {
        $r1 = @{ Suite='s'; Source='r1'; Duration=1; Tests=@(
            @{ ClassName='c'; Name='flaky';  Status='failed'; Duration=0.1; Message='boom' },
            @{ ClassName='c'; Name='stable'; Status='passed'; Duration=0.1 }
        )}
        $r2 = @{ Suite='s'; Source='r2'; Duration=1; Tests=@(
            @{ ClassName='c'; Name='flaky';  Status='passed'; Duration=0.1 },
            @{ ClassName='c'; Name='stable'; Status='passed'; Duration=0.1 }
        )}
        $merged = Merge-TestResults -Results @($r1,$r2)

        $merged.Flaky.Count       | Should -Be 1
        $merged.Flaky[0].FullName | Should -Be 'c.flaky'
        $merged.Flaky[0].Passed   | Should -Be 1
        $merged.Flaky[0].Failed   | Should -Be 1
    }

    It 'does not classify always-failing tests as flaky' {
        $r1 = @{ Suite='s'; Source='r1'; Duration=1; Tests=@(
            @{ ClassName='c'; Name='broken'; Status='failed'; Duration=0.1; Message='x' }) }
        $r2 = @{ Suite='s'; Source='r2'; Duration=1; Tests=@(
            @{ ClassName='c'; Name='broken'; Status='failed'; Duration=0.1; Message='x' }) }
        (Merge-TestResults -Results @($r1,$r2)).Flaky.Count | Should -Be 0
    }
}

Describe 'New-MarkdownSummary' {
    BeforeAll {
        $script:Sample = @{
            RunCount = 2
            Totals   = @{ Passed=3; Failed=1; Skipped=1; Total=5; Duration=3.0 }
            Flaky    = @(@{ FullName='c.flaky'; Passed=1; Failed=1; Runs=2 })
            Failures = @(@{ FullName='c.b'; Message='boom'; Source='r1' })
        }
    }

    It 'produces a markdown summary with all required sections' {
        $md = New-MarkdownSummary -Aggregate $script:Sample
        $md | Should -Match '# Test Results Summary'
        $md | Should -Match 'Passed.*3'
        $md | Should -Match 'Failed.*1'
        $md | Should -Match 'Skipped.*1'
        $md | Should -Match 'Duration'
        $md | Should -Match 'Flaky Tests'
        $md | Should -Match 'c\.flaky'
        $md | Should -Match 'Failures'
        $md | Should -Match 'boom'
    }

    It 'reports an all-green banner when there are no failures or flaky tests' {
        $clean = @{
            RunCount = 1
            Totals   = @{ Passed=2; Failed=0; Skipped=0; Total=2; Duration=0.5 }
            Flaky    = @()
            Failures = @()
        }
        $md = New-MarkdownSummary -Aggregate $clean
        $md | Should -Match 'All tests passed'
    }
}

Describe 'Invoke-TestResultsAggregator (end-to-end)' {
    It 'reads files from a directory, aggregates, and writes a summary' {
        $inDir  = Join-Path $TestDrive 'in'
        $outDir = Join-Path $TestDrive 'out'
        New-Item -ItemType Directory -Path $inDir, $outDir | Out-Null

        # Two runs: one passes "flaky", the other fails it.
        Set-Content (Join-Path $inDir 'run1.xml') -Encoding UTF8 -Value @'
<?xml version="1.0"?>
<testsuite name="s" tests="2" failures="1" time="0.2">
  <testcase classname="c" name="stable" time="0.1"/>
  <testcase classname="c" name="flaky"  time="0.1"><failure message="boom"/></testcase>
</testsuite>
'@
        Set-Content (Join-Path $inDir 'run2.json') -Encoding UTF8 -Value '{"suite":"s","duration":0.2,"tests":[{"classname":"c","name":"stable","status":"passed","duration":0.1},{"classname":"c","name":"flaky","status":"passed","duration":0.1}]}'

        $summaryPath = Join-Path $outDir 'summary.md'
        $result = Invoke-TestResultsAggregator -InputPath $inDir -OutputPath $summaryPath

        Test-Path $summaryPath | Should -BeTrue
        $result.Totals.Total  | Should -Be 4
        $result.Totals.Passed | Should -Be 3
        $result.Totals.Failed | Should -Be 1
        $result.Flaky.Count   | Should -Be 1
        (Get-Content $summaryPath -Raw) | Should -Match 'Flaky'
    }
}
