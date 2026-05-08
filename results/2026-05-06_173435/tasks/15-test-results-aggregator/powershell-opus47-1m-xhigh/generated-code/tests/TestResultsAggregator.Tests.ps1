# Pester tests for the TestResultsAggregator module.
#
# We follow strict red/green TDD: each Describe block represents a behaviour
# slice, and we wrote the tests before any production code existed. The shape
# of the data returned by every parser is normalised into a hashtable that
# downstream stages (aggregation, flaky detection, markdown rendering) can
# consume without caring about the source format.

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force

    $script:FixtureRoot = Join-Path $PSScriptRoot 'fixtures'
}

Describe 'Read-JUnitXmlResults' {
    It 'parses passed, failed, and skipped tests from a JUnit XML document' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="suite-A" tests="3" failures="1" skipped="1" time="0.45">
    <testcase classname="suite-A" name="passes" time="0.10"/>
    <testcase classname="suite-A" name="fails" time="0.20">
      <failure message="boom">stack trace</failure>
    </testcase>
    <testcase classname="suite-A" name="skipped" time="0.15">
      <skipped/>
    </testcase>
  </testsuite>
</testsuites>
'@
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value $xml -Encoding utf8
            $result = Read-JUnitXmlResults -Path $tmp.FullName -RunId 'run-1'

            $result.Tests.Count | Should -Be 3

            $passed = $result.Tests | Where-Object { $_.Name -eq 'passes' }
            $passed.Status | Should -Be 'passed'
            $passed.Suite | Should -Be 'suite-A'
            $passed.Duration | Should -Be 0.10
            $passed.RunId | Should -Be 'run-1'

            $failed = $result.Tests | Where-Object { $_.Name -eq 'fails' }
            $failed.Status | Should -Be 'failed'
            $failed.FailureMessage | Should -Be 'boom'

            $skipped = $result.Tests | Where-Object { $_.Name -eq 'skipped' }
            $skipped.Status | Should -Be 'skipped'
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'handles a single <testsuite> document (no <testsuites> wrapper)' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="single" tests="1" failures="0" time="0.01">
  <testcase classname="single" name="ok" time="0.01"/>
</testsuite>
'@
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value $xml -Encoding utf8
            $result = Read-JUnitXmlResults -Path $tmp.FullName -RunId 'run-2'
            $result.Tests.Count | Should -Be 1
            $result.Tests[0].Status | Should -Be 'passed'
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws a meaningful error when the file is not valid XML' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value 'not xml at all' -Encoding utf8
            { Read-JUnitXmlResults -Path $tmp.FullName -RunId 'run-x' } |
                Should -Throw -ExpectedMessage '*not valid JUnit XML*'
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when the file does not exist' {
        { Read-JUnitXmlResults -Path '/no/such/file.xml' -RunId 'run-x' } |
            Should -Throw -ExpectedMessage '*not found*'
    }
}

Describe 'Read-JsonResults' {
    It 'parses a flat JSON test result document' {
        $json = @'
{
  "tests": [
    { "name": "alpha", "suite": "json-suite", "status": "passed", "duration": 0.05 },
    { "name": "beta", "suite": "json-suite", "status": "failed", "duration": 0.10, "failureMessage": "nope" },
    { "name": "gamma", "suite": "json-suite", "status": "skipped", "duration": 0 }
  ]
}
'@
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value $json -Encoding utf8
            $result = Read-JsonResults -Path $tmp.FullName -RunId 'run-j'

            $result.Tests.Count | Should -Be 3
            $beta = $result.Tests | Where-Object { $_.Name -eq 'beta' }
            $beta.Status | Should -Be 'failed'
            $beta.FailureMessage | Should -Be 'nope'
            $beta.RunId | Should -Be 'run-j'
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws a meaningful error when JSON is malformed' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value '{ this is not json' -Encoding utf8
            { Read-JsonResults -Path $tmp.FullName -RunId 'run-j' } |
                Should -Throw -ExpectedMessage '*not valid JSON*'
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when the document is missing the tests array' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value '{"results": []}' -Encoding utf8
            { Read-JsonResults -Path $tmp.FullName -RunId 'run-j' } |
                Should -Throw -ExpectedMessage '*tests*'
        }
        finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Read-TestResultsFile (dispatch)' {
    It 'dispatches .xml to the JUnit parser' {
        $junit = Join-Path $script:FixtureRoot 'sample-junit.xml'
        $result = Read-TestResultsFile -Path $junit -RunId 'r1'
        $result.Tests.Count | Should -BeGreaterThan 0
    }

    It 'dispatches .json to the JSON parser' {
        $json = Join-Path $script:FixtureRoot 'sample.json'
        $result = Read-TestResultsFile -Path $json -RunId 'r2'
        $result.Tests.Count | Should -BeGreaterThan 0
    }

    It 'rejects unknown file extensions' {
        $tmp = New-TemporaryFile
        try {
            Set-Content -LiteralPath $tmp -Value 'unused' -Encoding utf8
            $renamed = "$($tmp.FullName).weird"
            Rename-Item -LiteralPath $tmp.FullName -NewName $renamed
            { Read-TestResultsFile -Path $renamed -RunId 'rx' } |
                Should -Throw -ExpectedMessage '*Unsupported*'
            Remove-Item -LiteralPath $renamed -Force -ErrorAction SilentlyContinue
        }
        catch {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            throw
        }
    }
}

Describe 'Get-AggregateTotals' {
    It 'computes passed, failed, skipped, and duration across runs' {
        $tests = @(
            @{ Name='a'; Suite='s'; Status='passed';  Duration=0.10; RunId='r1' },
            @{ Name='b'; Suite='s'; Status='passed';  Duration=0.20; RunId='r1' },
            @{ Name='c'; Suite='s'; Status='failed';  Duration=0.30; RunId='r2' },
            @{ Name='d'; Suite='s'; Status='skipped'; Duration=0.05; RunId='r2' }
        )
        $totals = Get-AggregateTotals -Tests $tests
        $totals.Total    | Should -Be 4
        $totals.Passed   | Should -Be 2
        $totals.Failed   | Should -Be 1
        $totals.Skipped  | Should -Be 1
        $totals.Duration | Should -Be 0.65
    }

    It 'returns zeros for an empty input' {
        $totals = Get-AggregateTotals -Tests @()
        $totals.Total | Should -Be 0
        $totals.Passed | Should -Be 0
        $totals.Failed | Should -Be 0
        $totals.Skipped | Should -Be 0
        $totals.Duration | Should -Be 0
    }
}

Describe 'Find-FlakyTests' {
    It 'identifies tests that both passed and failed across runs' {
        $tests = @(
            @{ Name='shaky'; Suite='s'; Status='passed';  Duration=0.1; RunId='r1' },
            @{ Name='shaky'; Suite='s'; Status='failed';  Duration=0.2; RunId='r2' },
            @{ Name='solid'; Suite='s'; Status='passed';  Duration=0.1; RunId='r1' },
            @{ Name='solid'; Suite='s'; Status='passed';  Duration=0.1; RunId='r2' }
        )
        $flaky = Find-FlakyTests -Tests $tests
        $flaky.Count | Should -Be 1
        $flaky[0].Name | Should -Be 'shaky'
        $flaky[0].PassCount | Should -Be 1
        $flaky[0].FailCount | Should -Be 1
    }

    It 'does not treat consistent failures as flaky' {
        $tests = @(
            @{ Name='broken'; Suite='s'; Status='failed'; Duration=0.1; RunId='r1' },
            @{ Name='broken'; Suite='s'; Status='failed'; Duration=0.1; RunId='r2' }
        )
        Find-FlakyTests -Tests $tests | Should -BeNullOrEmpty
    }

    It 'treats skips as neither pass nor fail (so skip+pass is not flaky)' {
        $tests = @(
            @{ Name='maybe'; Suite='s'; Status='passed';  Duration=0.1; RunId='r1' },
            @{ Name='maybe'; Suite='s'; Status='skipped'; Duration=0.0; RunId='r2' }
        )
        Find-FlakyTests -Tests $tests | Should -BeNullOrEmpty
    }
}

Describe 'Format-MarkdownSummary' {
    It 'renders an h2 header, totals table, and flaky section' {
        $tests = @(
            @{ Name='a';     Suite='s'; Status='passed';  Duration=0.10; RunId='r1'; FailureMessage=$null },
            @{ Name='b';     Suite='s'; Status='failed';  Duration=0.20; RunId='r1'; FailureMessage='nope' },
            @{ Name='shaky'; Suite='s'; Status='passed';  Duration=0.10; RunId='r1'; FailureMessage=$null },
            @{ Name='shaky'; Suite='s'; Status='failed';  Duration=0.20; RunId='r2'; FailureMessage='boom' }
        )
        $md = Format-MarkdownSummary -Tests $tests

        $md | Should -Match '## Test Results'
        $md | Should -Match '\| Passed \| Failed \| Skipped \| Total \| Duration \|'
        # totals row: 2 passed, 2 failed, 0 skipped, 4 total, 0.60s
        $md | Should -Match '\| 2 \| 2 \| 0 \| 4 \| 0.60s \|'
        $md | Should -Match '### Flaky tests'
        $md | Should -Match 'shaky'
        $md | Should -Match '### Failures'
        $md | Should -Match 'nope'
    }

    It 'reports an all-green summary with no failures or flaky sections' {
        $tests = @(
            @{ Name='a'; Suite='s'; Status='passed'; Duration=0.10; RunId='r1'; FailureMessage=$null }
        )
        $md = Format-MarkdownSummary -Tests $tests
        $md | Should -Match 'All tests passed'
        $md | Should -Not -Match '### Failures'
        $md | Should -Not -Match '### Flaky tests'
    }
}

Describe 'Invoke-AggregateTestResults (end-to-end)' {
    It 'aggregates all fixture files in a directory and produces markdown plus an exit signal' {
        $result = Invoke-AggregateTestResults -InputDirectory $script:FixtureRoot
        $result.Totals.Total    | Should -BeGreaterThan 0
        $result.Markdown        | Should -Match '## Test Results'
        # FailureExit is 1 if there are any failures, 0 otherwise.
        ($result.FailureExit -in 0,1) | Should -BeTrue
    }

    It 'errors if the directory has no recognised result files' {
        $empty = Join-Path ([System.IO.Path]::GetTempPath()) ("empty-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        try {
            { Invoke-AggregateTestResults -InputDirectory $empty } |
                Should -Throw -ExpectedMessage '*No test result files*'
        }
        finally {
            Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
