# TestResultsAggregator.Tests.ps1
# Pester tests using red/green TDD methodology.
# Each Describe block targets one function; tests were written before implementation.

BeforeAll {
    # Strict mode inside BeforeAll to avoid Pester discovery conflicts
    Set-StrictMode -Version 3.0
    $ErrorActionPreference = 'Stop'

    # Import the module under test
    Import-Module "$PSScriptRoot/TestResultsAggregator.psm1" -Force
    # Resolve fixture directory once
    $script:FixtureDir = Join-Path $PSScriptRoot 'fixtures'
}

# ===========================================================================
# RED/GREEN cycle 1: ConvertFrom-JUnitXml
# ===========================================================================
Describe 'ConvertFrom-JUnitXml' {

    It 'Should parse all test cases from a JUnit XML file' {
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        $results.Count | Should -Be 5
    }

    It 'Should correctly identify passed tests' {
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [int]$passed = ($results | Where-Object { $_.Status -eq 'passed' }).Count
        $passed | Should -Be 3
    }

    It 'Should correctly identify failed tests' {
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [int]$failed = @($results | Where-Object { $_.Status -eq 'failed' }).Count
        $failed | Should -Be 1
    }

    It 'Should correctly identify skipped tests' {
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [int]$skipped = @($results | Where-Object { $_.Status -eq 'skipped' }).Count
        $skipped | Should -Be 1
    }

    It 'Should capture test duration as double' {
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable]$addition = $results | Where-Object { $_.Name -eq 'test_addition' } | Select-Object -First 1
        $addition.Duration | Should -BeOfType [double]
        $addition.Duration | Should -Be 1.1
    }

    It 'Should capture failure error messages' {
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable]$sub = $results | Where-Object { $_.Name -eq 'test_subtraction' } | Select-Object -First 1
        $sub.ErrorMessage | Should -Be 'Expected 5 but got 4'
    }

    It 'Should record RunSource as the file path' {
        [string]$path = Join-Path $script:FixtureDir 'junit-run1.xml'
        [hashtable[]]$results = ConvertFrom-JUnitXml -Path $path
        $results[0].RunSource | Should -Be $path
    }

    It 'Should throw on non-existent file' {
        { ConvertFrom-JUnitXml -Path '/no/such/file.xml' } | Should -Throw '*not found*'
    }
}

# ===========================================================================
# RED/GREEN cycle 2: ConvertFrom-JsonTestResult
# ===========================================================================
Describe 'ConvertFrom-JsonTestResult' {

    It 'Should parse all test cases from a JSON file' {
        [hashtable[]]$results = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run1.json')
        $results.Count | Should -Be 5
    }

    It 'Should correctly identify statuses' {
        [hashtable[]]$results = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run1.json')
        @($results | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 3
        @($results | Where-Object { $_.Status -eq 'failed' }).Count | Should -Be 1
        @($results | Where-Object { $_.Status -eq 'skipped' }).Count | Should -Be 1
    }

    It 'Should capture error messages from failed tests' {
        [hashtable[]]$results = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run1.json')
        [hashtable]$postUser = $results | Where-Object { $_.Name -eq 'test_post_user' } | Select-Object -First 1
        $postUser.ErrorMessage | Should -Be 'HTTP 500 Internal Server Error'
    }

    It 'Should capture skip reasons' {
        [hashtable[]]$results = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run1.json')
        [hashtable]$deleteUser = $results | Where-Object { $_.Name -eq 'test_delete_user' } | Select-Object -First 1
        $deleteUser.ErrorMessage | Should -Be 'Requires admin permissions'
    }

    It 'Should throw on non-existent file' {
        { ConvertFrom-JsonTestResult -Path '/no/such/file.json' } | Should -Throw '*not found*'
    }
}

# ===========================================================================
# RED/GREEN cycle 3: Import-TestResults (format dispatch)
# ===========================================================================
Describe 'Import-TestResults' {

    It 'Should dispatch .xml files to JUnit parser' {
        [hashtable[]]$results = Import-TestResults -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        $results.Count | Should -Be 5
    }

    It 'Should dispatch .json files to JSON parser' {
        [hashtable[]]$results = Import-TestResults -Path (Join-Path $script:FixtureDir 'json-run1.json')
        $results.Count | Should -Be 5
    }

    It 'Should throw on unsupported file extension' {
        # Create a temp file with unsupported extension
        [string]$tmp = Join-Path $TestDrive 'results.csv'
        Set-Content -Path $tmp -Value 'a,b,c'
        { Import-TestResults -Path $tmp } | Should -Throw '*Unsupported*'
    }

    It 'Should throw on non-existent file' {
        { Import-TestResults -Path '/no/such/file.xml' } | Should -Throw '*not found*'
    }
}

# ===========================================================================
# RED/GREEN cycle 4: Merge-TestResults
# ===========================================================================
Describe 'Merge-TestResults' {

    It 'Should aggregate counts across multiple result sets' {
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable]$merged = Merge-TestResults -ResultSets @($run1, $run2)

        $merged.Total | Should -Be 10
    }

    It 'Should compute correct pass/fail/skip totals' {
        # junit-run1: 3 passed, 1 failed, 1 skipped
        # junit-run2: 3 passed, 1 failed, 1 skipped
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable]$merged = Merge-TestResults -ResultSets @($run1, $run2)

        $merged.Passed  | Should -Be 6
        $merged.Failed  | Should -Be 2
        $merged.Skipped | Should -Be 2
    }

    It 'Should compute total duration' {
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable]$merged = Merge-TestResults -ResultSets @($run1, $run2)

        # Sum of all individual test durations from both files
        $merged.TotalDuration | Should -BeGreaterThan 0
    }

    It 'Should work with mixed formats (XML + JSON)' {
        [hashtable[]]$xmlRun  = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$jsonRun = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run1.json')
        [hashtable]$merged = Merge-TestResults -ResultSets @($xmlRun, $jsonRun)

        $merged.Total | Should -Be 10
    }
}

# ===========================================================================
# RED/GREEN cycle 5: Find-FlakyTests
# ===========================================================================
Describe 'Find-FlakyTests' {

    It 'Should identify tests that passed in one run and failed in another' {
        # test_subtraction: failed in run1, passed in run2 => flaky
        # test_concat: passed in run1, failed in run2 => flaky
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable[]]$all = $run1 + $run2
        [hashtable[]]$flaky = Find-FlakyTests -TestCases $all

        $flaky.Count | Should -Be 2
        [string[]]$flakyNames = $flaky | ForEach-Object { $_.Name }
        $flakyNames | Should -Contain 'test_subtraction'
        $flakyNames | Should -Contain 'test_concat'
    }

    It 'Should not flag tests that are always skipped' {
        # test_split is skipped in both runs — not flaky
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable[]]$all = $run1 + $run2
        [hashtable[]]$flaky = Find-FlakyTests -TestCases $all

        [string[]]$flakyNames = $flaky | ForEach-Object { $_.Name }
        $flakyNames | Should -Not -Contain 'test_split'
    }

    It 'Should not flag tests that consistently pass' {
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable[]]$all = $run1 + $run2
        [hashtable[]]$flaky = Find-FlakyTests -TestCases $all

        [string[]]$flakyNames = $flaky | ForEach-Object { $_.Name }
        $flakyNames | Should -Not -Contain 'test_addition'
        $flakyNames | Should -Not -Contain 'test_multiplication'
    }

    It 'Should include per-run details in flaky test results' {
        [hashtable[]]$run1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$run2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable[]]$all = $run1 + $run2
        [hashtable[]]$flaky = Find-FlakyTests -TestCases $all

        [hashtable]$subFlaky = $flaky | Where-Object { $_.Name -eq 'test_subtraction' } | Select-Object -First 1
        $subFlaky.Runs.Count | Should -Be 2
    }

    It 'Should detect flaky tests in JSON results too' {
        # test_post_user: failed run1, passed run2 => flaky
        # test_logout: passed run1, failed run2 => flaky
        [hashtable[]]$run1 = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run1.json')
        [hashtable[]]$run2 = ConvertFrom-JsonTestResult -Path (Join-Path $script:FixtureDir 'json-run2.json')
        [hashtable[]]$all = $run1 + $run2
        [hashtable[]]$flaky = Find-FlakyTests -TestCases $all

        $flaky.Count | Should -Be 2
        [string[]]$flakyNames = $flaky | ForEach-Object { $_.Name }
        $flakyNames | Should -Contain 'test_post_user'
        $flakyNames | Should -Contain 'test_logout'
    }
}

# ===========================================================================
# RED/GREEN cycle 6: New-MarkdownSummary
# ===========================================================================
Describe 'New-MarkdownSummary' {

    BeforeAll {
        # Build aggregated data for summary tests
        [hashtable[]]$jrun1 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run1.xml')
        [hashtable[]]$jrun2 = ConvertFrom-JUnitXml -Path (Join-Path $script:FixtureDir 'junit-run2.xml')
        [hashtable]$script:agg = Merge-TestResults -ResultSets @($jrun1, $jrun2)
        [hashtable[]]$script:flaky = Find-FlakyTests -TestCases $script:agg.TestCases
    }

    It 'Should produce a non-empty markdown string' {
        [string]$md = New-MarkdownSummary -AggregatedResults $script:agg -FlakyTests $script:flaky
        $md | Should -Not -BeNullOrEmpty
    }

    It 'Should include the header with failure icon when there are failures' {
        [string]$md = New-MarkdownSummary -AggregatedResults $script:agg -FlakyTests $script:flaky
        $md | Should -Match '❌'
        $md | Should -Match 'Test Results Summary'
    }

    It 'Should include totals table' {
        [string]$md = New-MarkdownSummary -AggregatedResults $script:agg -FlakyTests $script:flaky
        $md | Should -Match 'Total'
        $md | Should -Match 'Passed'
        $md | Should -Match 'Failed'
        $md | Should -Match 'Skipped'
        $md | Should -Match 'Duration'
    }

    It 'Should include the actual counts in the summary' {
        [string]$md = New-MarkdownSummary -AggregatedResults $script:agg -FlakyTests $script:flaky
        $md | Should -Match '\b10\b'   # Total
        $md | Should -Match '\b6\b'    # Passed
        $md | Should -Match '\b2\b'    # Failed (and Skipped)
    }

    It 'Should list failed tests with error messages' {
        [string]$md = New-MarkdownSummary -AggregatedResults $script:agg -FlakyTests $script:flaky
        $md | Should -Match 'Failed Tests'
        $md | Should -Match 'test_subtraction'
        $md | Should -Match 'test_concat'
    }

    It 'Should include a flaky tests section' {
        [string]$md = New-MarkdownSummary -AggregatedResults $script:agg -FlakyTests $script:flaky
        $md | Should -Match 'Flaky Tests'
        $md | Should -Match 'test_subtraction'
        $md | Should -Match 'test_concat'
    }

    It 'Should show success icon when no failures exist' {
        [hashtable]$allPass = @{
            Passed = 5; Failed = 0; Skipped = 0; Total = 5;
            TotalDuration = 3.0; TestCases = @()
        }
        [string]$md = New-MarkdownSummary -AggregatedResults $allPass
        $md | Should -Match '✅'
    }

    It 'Should omit flaky section when no flaky tests' {
        [hashtable]$allPass = @{
            Passed = 5; Failed = 0; Skipped = 0; Total = 5;
            TotalDuration = 3.0; TestCases = @()
        }
        [string]$md = New-MarkdownSummary -AggregatedResults $allPass -FlakyTests @()
        $md | Should -Not -Match 'Flaky Tests'
    }
}

# ===========================================================================
# RED/GREEN cycle 7: End-to-end integration
# ===========================================================================
Describe 'End-to-End Integration' {

    It 'Should process all fixture files and produce a complete summary' {
        # Simulate a matrix build: 2 JUnit runs + 2 JSON runs
        [string[]]$files = @(
            (Join-Path $script:FixtureDir 'junit-run1.xml'),
            (Join-Path $script:FixtureDir 'junit-run2.xml'),
            (Join-Path $script:FixtureDir 'json-run1.json'),
            (Join-Path $script:FixtureDir 'json-run2.json')
        )

        [hashtable[][]]$allSets = @()
        foreach ($f in $files) {
            [hashtable[]]$set = Import-TestResults -Path $f
            $allSets += , $set
        }

        [hashtable]$merged = Merge-TestResults -ResultSets $allSets
        $merged.Total | Should -Be 20  # 5+5+5+5

        [hashtable[]]$flaky = Find-FlakyTests -TestCases $merged.TestCases
        # Flaky: test_subtraction, test_concat (JUnit), test_post_user, test_logout (JSON)
        $flaky.Count | Should -Be 4

        [string]$md = New-MarkdownSummary -AggregatedResults $merged -FlakyTests $flaky
        $md | Should -Not -BeNullOrEmpty
        $md | Should -Match 'Test Results Summary'
        $md | Should -Match 'Flaky Tests'
    }
}
