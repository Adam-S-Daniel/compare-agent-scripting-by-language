# Pester 5 test suite for the TestResultsAggregator module.
#
# This file is the test-side of the red/green TDD cycle: each Describe block was
# authored failing first, then the matching code in src/TestResultsAggregator.psm1
# was added (and only as much as necessary) to turn it green.
#
# Run with:  Invoke-Pester -Path ./tests -Output Detailed

# --- Pester 5 BeforeAll -----------------------------------------------------
# All discovery-time variables (paths, fixture locations) live inside BeforeAll
# blocks so they only resolve when the file is *executed*, not during Pester's
# discovery pass. That keeps the file safe to import from any CWD.

BeforeAll {
    $script:ModulePath  = Join-Path $PSScriptRoot '..' 'src' 'TestResultsAggregator.psm1'
    $script:FixtureRoot = Join-Path $PSScriptRoot '..' 'fixtures'

    # Force a fresh import so re-runs pick up edits without restarting the host.
    Get-Module TestResultsAggregator -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $script:ModulePath -Force
}

Describe 'ConvertFrom-JUnitXml' {

    Context 'When given a JUnit XML file with a single passing test' {

        It 'returns one test result object with Status=Passed' {
            $path = Join-Path $script:FixtureRoot 'junit-single-pass.xml'
            $results = ConvertFrom-JUnitXml -Path $path

            $results | Should -HaveCount 1
            $results[0].Status    | Should -Be 'Passed'
            $results[0].Name      | Should -Be 'test_addition'
            $results[0].ClassName | Should -Be 'MathTests'
        }
    }

    Context 'When given a JUnit XML file with mixed pass/fail/skip' {

        It 'returns the correct status for each case' {
            $path = Join-Path $script:FixtureRoot 'junit-mixed.xml'
            $results = ConvertFrom-JUnitXml -Path $path

            $results | Should -HaveCount 4
            ($results | Where-Object Status -EQ 'Passed').Count  | Should -Be 2
            ($results | Where-Object Status -EQ 'Failed').Count  | Should -Be 1
            ($results | Where-Object Status -EQ 'Skipped').Count | Should -Be 1
        }

        It 'preserves the failure message on the failed case' {
            $path = Join-Path $script:FixtureRoot 'junit-mixed.xml'
            $results = ConvertFrom-JUnitXml -Path $path
            $failed  = $results | Where-Object Status -EQ 'Failed'

            $failed.Message | Should -Match 'expected'
        }

        It 'parses the per-test duration as a positive double' {
            $path = Join-Path $script:FixtureRoot 'junit-mixed.xml'
            $results = ConvertFrom-JUnitXml -Path $path

            ($results | Measure-Object Duration -Sum).Sum | Should -BeGreaterThan 0
        }
    }

    Context 'Error handling' {

        It 'throws a meaningful error when the file does not exist' {
            { ConvertFrom-JUnitXml -Path (Join-Path $TestDrive 'nope.xml') } |
                Should -Throw -ExpectedMessage '*not found*'
        }

        It 'throws a meaningful error when the XML is malformed' {
            $bad = Join-Path $TestDrive 'bad.xml'
            'this is not <xml' | Set-Content -Path $bad
            { ConvertFrom-JUnitXml -Path $bad } |
                Should -Throw -ExpectedMessage '*XML*'
        }
    }
}

Describe 'ConvertFrom-TestJson' {

    Context 'When given a JSON file with mixed results' {

        It 'returns one object per test case with normalized Status values' {
            $path = Join-Path $script:FixtureRoot 'results-run-1.json'
            $results = ConvertFrom-TestJson -Path $path

            $results | Should -HaveCount 3
            $results.Status | Sort-Object -Unique | Should -Be @('Failed', 'Passed')
        }

        It 'computes the total duration across all cases' {
            $path = Join-Path $script:FixtureRoot 'results-run-1.json'
            $results = ConvertFrom-TestJson -Path $path
            ($results | Measure-Object Duration -Sum).Sum | Should -BeGreaterThan 0
        }
    }

    Context 'Error handling' {

        It 'throws when the file does not exist' {
            { ConvertFrom-TestJson -Path (Join-Path $TestDrive 'nope.json') } |
                Should -Throw -ExpectedMessage '*not found*'
        }

        It 'throws when the JSON is invalid' {
            $bad = Join-Path $TestDrive 'bad.json'
            '{ this is not valid json' | Set-Content -Path $bad
            { ConvertFrom-TestJson -Path $bad } |
                Should -Throw -ExpectedMessage '*JSON*'
        }
    }
}

Describe 'Get-TestResults (dispatcher)' {

    It 'routes .xml files through the JUnit parser' {
        $path = Join-Path $script:FixtureRoot 'junit-single-pass.xml'
        $results = Get-TestResults -Path $path
        $results[0].Status | Should -Be 'Passed'
        $results[0].Run    | Should -Be 'junit-single-pass.xml'
    }

    It 'routes .json files through the JSON parser' {
        $path = Join-Path $script:FixtureRoot 'results-run-1.json'
        $results = Get-TestResults -Path $path
        $results | Should -Not -BeNullOrEmpty
        $results[0].Run | Should -Be 'results-run-1.json'
    }

    It 'rejects unknown extensions with a useful error' {
        $bogus = Join-Path $TestDrive 'foo.txt'
        'whatever' | Set-Content -Path $bogus
        { Get-TestResults -Path $bogus } |
            Should -Throw -ExpectedMessage '*Unsupported*'
    }
}

Describe 'Merge-TestResults' {

    BeforeAll {
        $script:Run1 = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed';  Duration=0.1; Run='r1.json' }
            [pscustomobject]@{ Name='b'; ClassName='S'; Status='Failed';  Duration=0.2; Run='r1.json' }
            [pscustomobject]@{ Name='c'; ClassName='S'; Status='Skipped'; Duration=0.0; Run='r1.json' }
        )
        $script:Run2 = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r2.json' }
            [pscustomobject]@{ Name='b'; ClassName='S'; Status='Passed'; Duration=0.3; Run='r2.json' }
            [pscustomobject]@{ Name='c'; ClassName='S'; Status='Skipped';Duration=0.0; Run='r2.json' }
        )
    }

    It 'returns Total = sum of test cases across runs' {
        $merged = Merge-TestResults -Results ($script:Run1 + $script:Run2)
        $merged.Total | Should -Be 6
    }

    It 'categorises totals correctly' {
        $merged = Merge-TestResults -Results ($script:Run1 + $script:Run2)
        # Run1: 1P/1F/1S, Run2: 2P/0F/1S -> 3P/1F/2S total
        $merged.Passed  | Should -Be 3
        $merged.Failed  | Should -Be 1
        $merged.Skipped | Should -Be 2
    }

    It 'sums Duration across all cases' {
        $merged = Merge-TestResults -Results ($script:Run1 + $script:Run2)
        # 0.1+0.2+0+0.1+0.3+0 = 0.7
        [math]::Round($merged.Duration, 1) | Should -Be 0.7
    }

    It 'tracks the number of distinct runs' {
        $merged = Merge-TestResults -Results ($script:Run1 + $script:Run2)
        $merged.RunCount | Should -Be 2
    }
}

Describe 'Find-FlakyTest' {

    It 'identifies tests that pass in some runs and fail in others' {
        $results = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r1' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Failed'; Duration=0.1; Run='r2' }
            [pscustomobject]@{ Name='b'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r1' }
            [pscustomobject]@{ Name='b'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r2' }
        )
        $flaky = Find-FlakyTest -Results $results
        $flaky | Should -HaveCount 1
        $flaky[0].Name | Should -Be 'a'
    }

    It 'does NOT classify tests that always fail as flaky' {
        $results = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Failed'; Duration=0.1; Run='r1' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Failed'; Duration=0.1; Run='r2' }
        )
        Find-FlakyTest -Results $results | Should -BeNullOrEmpty
    }

    It 'ignores Skipped runs when deciding flakiness' {
        # If a test is Skipped in run1 and Passed in run2, that is NOT flaky.
        $results = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Skipped'; Duration=0.0; Run='r1' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed';  Duration=0.1; Run='r2' }
        )
        Find-FlakyTest -Results $results | Should -BeNullOrEmpty
    }

    It 'reports the runs in which the test passed and failed' {
        $results = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r1' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Failed'; Duration=0.1; Run='r2' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r3' }
        )
        $flaky = Find-FlakyTest -Results $results
        $flaky[0].PassedRuns | Should -Be @('r1', 'r3')
        $flaky[0].FailedRuns | Should -Be @('r2')
    }
}

Describe 'New-MarkdownSummary' {

    BeforeAll {
        $script:Sample = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.10; Run='r1.json' }
            [pscustomobject]@{ Name='b'; ClassName='S'; Status='Failed'; Duration=0.20; Run='r1.json'; Message='boom' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.10; Run='r2.json' }
            [pscustomobject]@{ Name='b'; ClassName='S'; Status='Passed'; Duration=0.15; Run='r2.json' }
        )
    }

    It 'includes the summary header' {
        $md = New-MarkdownSummary -Results $script:Sample
        $md | Should -Match '# Test Results Summary'
    }

    It 'shows totals (passed/failed/skipped/duration/runs)' {
        $md = New-MarkdownSummary -Results $script:Sample
        $md | Should -Match 'Total.*4'
        $md | Should -Match 'Passed.*3'
        $md | Should -Match 'Failed.*1'
        $md | Should -Match 'Runs.*2'
    }

    It 'reports the pass-rate as a percentage' {
        $md = New-MarkdownSummary -Results $script:Sample
        $md | Should -Match '75\.0%'
    }

    It 'includes a Flaky Tests section listing the offender' {
        $md = New-MarkdownSummary -Results $script:Sample
        $md | Should -Match '## Flaky Tests'
        $md | Should -Match '\bb\b'
    }

    It 'includes a Failures section with the failure message' {
        $md = New-MarkdownSummary -Results $script:Sample
        $md | Should -Match '## Failures'
        $md | Should -Match 'boom'
    }

    It 'omits the Flaky section when there are no flaky tests' {
        $stable = @(
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r1' }
            [pscustomobject]@{ Name='a'; ClassName='S'; Status='Passed'; Duration=0.1; Run='r2' }
        )
        $md = New-MarkdownSummary -Results $stable
        $md | Should -Not -Match '## Flaky Tests'
    }
}

Describe 'Invoke-TestResultsAggregator (top-level integration)' {

    It 'aggregates a directory of fixtures and writes a markdown summary' {
        $out = Join-Path $TestDrive 'summary.md'
        $md = Invoke-TestResultsAggregator -InputPath $script:FixtureRoot -OutputPath $out

        Test-Path $out | Should -BeTrue
        $content = Get-Content $out -Raw
        $content | Should -Match '# Test Results Summary'
        # Returned string should match what was written.
        $md      | Should -Be $content
    }

    It 'returns a non-zero exit indicator when failures are present' {
        $out = Join-Path $TestDrive 'summary2.md'
        $result = Invoke-TestResultsAggregator -InputPath $script:FixtureRoot -OutputPath $out -PassThru
        $result.HasFailures | Should -BeTrue
        $result.Totals.Failed | Should -BeGreaterThan 0
    }
}
