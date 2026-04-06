#Requires -Modules Pester
Set-StrictMode -Latest
$ErrorActionPreference = 'Stop'

# Import the module under test
$ModulePath = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
Import-Module $ModulePath -Force

Describe 'Parse-JUnitXml' {
    BeforeAll {
        # Fixture path
        $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
    }

    Context 'Given a valid JUnit XML file' {
        It 'Returns a result object with correct totals' {
            $xmlPath = Join-Path $script:FixturesDir 'junit-pass.xml'
            $result = Parse-JUnitXml -Path $xmlPath

            $result | Should -Not -BeNullOrEmpty
            $result.TotalTests  | Should -Be 3
            $result.Passed      | Should -Be 2
            $result.Failed      | Should -Be 0
            $result.Skipped     | Should -Be 1
            $result.Duration    | Should -Be 1.5
        }

        It 'Captures individual test cases' {
            $xmlPath = Join-Path $script:FixturesDir 'junit-pass.xml'
            $result = Parse-JUnitXml -Path $xmlPath

            $result.TestCases | Should -HaveCount 3
            $result.TestCases[0].Name   | Should -Be 'Test_Addition'
            $result.TestCases[0].Status | Should -Be 'Passed'
        }

        It 'Marks failed tests correctly' {
            $xmlPath = Join-Path $script:FixturesDir 'junit-fail.xml'
            $result = Parse-JUnitXml -Path $xmlPath

            $result.Failed | Should -Be 2
            $failedCase = $result.TestCases | Where-Object { $_.Status -eq 'Failed' } | Select-Object -First 1
            $failedCase | Should -Not -BeNullOrEmpty
            $failedCase.Message | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Given an invalid path' {
        It 'Throws a meaningful error' {
            { Parse-JUnitXml -Path 'nonexistent.xml' } | Should -Throw '*not found*'
        }
    }
}

Describe 'Parse-JsonResults' {
    BeforeAll {
        $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
    }

    Context 'Given a valid JSON results file' {
        It 'Returns a result object with correct totals' {
            $jsonPath = Join-Path $script:FixturesDir 'results-pass.json'
            $result = Parse-JsonResults -Path $jsonPath

            $result | Should -Not -BeNullOrEmpty
            $result.TotalTests | Should -Be 4
            $result.Passed     | Should -Be 3
            $result.Failed     | Should -Be 1
            $result.Skipped    | Should -Be 0
            $result.Duration   | Should -Be 2.0
        }

        It 'Captures individual test cases' {
            $jsonPath = Join-Path $script:FixturesDir 'results-pass.json'
            $result = Parse-JsonResults -Path $jsonPath

            $result.TestCases | Should -HaveCount 4
            $result.TestCases[0].Name | Should -Be 'Test_Multiply'
        }
    }

    Context 'Given an invalid path' {
        It 'Throws a meaningful error' {
            { Parse-JsonResults -Path 'nonexistent.json' } | Should -Throw '*not found*'
        }
    }
}

Describe 'Merge-TestResults' {
    BeforeAll {
        $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
    }

    Context 'Given multiple result objects' {
        It 'Aggregates totals correctly' {
            $r1 = [PSCustomObject]@{
                TotalTests = 3; Passed = 2; Failed = 0; Skipped = 1; Duration = 1.5
                TestCases  = @(
                    [PSCustomObject]@{ Name = 'Test_A'; Status = 'Passed'; Duration = 0.5; Message = '' }
                    [PSCustomObject]@{ Name = 'Test_B'; Status = 'Passed'; Duration = 0.5; Message = '' }
                    [PSCustomObject]@{ Name = 'Test_C'; Status = 'Skipped'; Duration = 0.0; Message = '' }
                )
                RunLabel   = 'ubuntu-latest'
            }
            $r2 = [PSCustomObject]@{
                TotalTests = 3; Passed = 1; Failed = 2; Skipped = 0; Duration = 2.0
                TestCases  = @(
                    [PSCustomObject]@{ Name = 'Test_A'; Status = 'Passed'; Duration = 0.5; Message = '' }
                    [PSCustomObject]@{ Name = 'Test_B'; Status = 'Failed'; Duration = 0.7; Message = 'Assertion failed' }
                    [PSCustomObject]@{ Name = 'Test_C'; Status = 'Failed'; Duration = 0.8; Message = 'Null ref' }
                )
                RunLabel   = 'windows-latest'
            }

            $merged = Merge-TestResults -Results @($r1, $r2)

            $merged.TotalTests | Should -Be 6
            $merged.Passed     | Should -Be 3
            $merged.Failed     | Should -Be 2
            $merged.Skipped    | Should -Be 1
            $merged.Duration   | Should -Be 3.5
        }
    }
}

Describe 'Find-FlakyTests' {
    It 'Identifies tests that both pass and fail across runs' {
        $r1 = [PSCustomObject]@{
            RunLabel  = 'run-1'
            TestCases = @(
                [PSCustomObject]@{ Name = 'Test_Alpha'; Status = 'Passed'; Duration = 0.1; Message = '' }
                [PSCustomObject]@{ Name = 'Test_Beta';  Status = 'Failed'; Duration = 0.2; Message = 'err' }
            )
        }
        $r2 = [PSCustomObject]@{
            RunLabel  = 'run-2'
            TestCases = @(
                [PSCustomObject]@{ Name = 'Test_Alpha'; Status = 'Failed'; Duration = 0.1; Message = 'flake' }
                [PSCustomObject]@{ Name = 'Test_Beta';  Status = 'Failed'; Duration = 0.2; Message = 'err' }
            )
        }

        $flaky = Find-FlakyTests -Results @($r1, $r2)

        $flaky | Should -HaveCount 1
        $flaky[0].Name | Should -Be 'Test_Alpha'
    }

    It 'Returns empty when no flaky tests exist' {
        $r1 = [PSCustomObject]@{
            RunLabel  = 'run-1'
            TestCases = @(
                [PSCustomObject]@{ Name = 'Test_Alpha'; Status = 'Passed'; Duration = 0.1; Message = '' }
            )
        }
        $r2 = [PSCustomObject]@{
            RunLabel  = 'run-2'
            TestCases = @(
                [PSCustomObject]@{ Name = 'Test_Alpha'; Status = 'Passed'; Duration = 0.1; Message = '' }
            )
        }

        $flaky = Find-FlakyTests -Results @($r1, $r2)

        $flaky | Should -BeNullOrEmpty
    }
}

Describe 'New-MarkdownSummary' {
    It 'Generates a markdown string with all sections' {
        $merged = [PSCustomObject]@{
            TotalTests = 6; Passed = 4; Failed = 1; Skipped = 1; Duration = 3.5
        }
        $flaky = @(
            [PSCustomObject]@{ Name = 'Test_Alpha'; PassCount = 1; FailCount = 1 }
        )
        $runs = @(
            [PSCustomObject]@{
                RunLabel   = 'ubuntu-latest'
                TotalTests = 3; Passed = 2; Failed = 0; Skipped = 1; Duration = 1.5
            }
            [PSCustomObject]@{
                RunLabel   = 'windows-latest'
                TotalTests = 3; Passed = 2; Failed = 1; Skipped = 0; Duration = 2.0
            }
        )

        $md = New-MarkdownSummary -MergedResults $merged -FlakyTests $flaky -RunResults $runs

        $md | Should -Match '# Test Results Summary'
        $md | Should -Match 'Total.*6'
        $md | Should -Match 'Passed.*4'
        $md | Should -Match 'Failed.*1'
        $md | Should -Match 'Flaky Tests'
        $md | Should -Match 'Test_Alpha'
        $md | Should -Match 'ubuntu-latest'
        $md | Should -Match 'windows-latest'
    }

    It 'Shows a success badge when no failures' {
        $merged = [PSCustomObject]@{
            TotalTests = 3; Passed = 3; Failed = 0; Skipped = 0; Duration = 1.0
        }
        $md = New-MarkdownSummary -MergedResults $merged -FlakyTests @() -RunResults @()

        $md | Should -Match 'PASSED'
    }

    It 'Shows a failure badge when tests fail' {
        $merged = [PSCustomObject]@{
            TotalTests = 3; Passed = 2; Failed = 1; Skipped = 0; Duration = 1.0
        }
        $md = New-MarkdownSummary -MergedResults $merged -FlakyTests @() -RunResults @()

        $md | Should -Match 'FAILED'
    }
}

Describe 'Invoke-TestResultsAggregation (integration)' {
    BeforeAll {
        $script:FixturesDir = Join-Path $PSScriptRoot 'fixtures'
        $script:OutputPath  = Join-Path $PSScriptRoot 'summary.md'
    }

    AfterAll {
        if (Test-Path $script:OutputPath) {
            Remove-Item $script:OutputPath -Force
        }
    }

    It 'Processes fixture files and produces a markdown summary file' {
        $files = @(
            [PSCustomObject]@{ Path = Join-Path $script:FixturesDir 'junit-pass.xml';    Format = 'JUnit'; RunLabel = 'ubuntu-junit' }
            [PSCustomObject]@{ Path = Join-Path $script:FixturesDir 'junit-fail.xml';    Format = 'JUnit'; RunLabel = 'windows-junit' }
            [PSCustomObject]@{ Path = Join-Path $script:FixturesDir 'results-pass.json'; Format = 'Json';  RunLabel = 'ubuntu-json' }
        )

        Invoke-TestResultsAggregation -InputFiles $files -OutputPath $script:OutputPath

        Test-Path $script:OutputPath | Should -BeTrue
        $content = Get-Content $script:OutputPath -Raw
        $content | Should -Match '# Test Results Summary'
        $content | Should -Match 'ubuntu-junit'
        $content | Should -Match 'windows-junit'
        $content | Should -Match 'ubuntu-json'
    }
}
