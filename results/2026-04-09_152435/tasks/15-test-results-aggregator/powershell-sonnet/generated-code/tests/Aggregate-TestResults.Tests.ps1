# Aggregate-TestResults.Tests.ps1
# TDD test suite for the test results aggregator.
#
# TDD METHODOLOGY:
# Each "Describe" block was written BEFORE the corresponding implementation.
# Tests were run first to confirm they FAIL (RED phase), then the minimum
# implementation was added to make them PASS (GREEN phase), then refactored.
#
# Test execution order follows the implementation build-up:
#   1. Parse-JUnitXml    -> RED, then GREEN
#   2. Parse-JsonResults -> RED, then GREEN
#   3. Aggregate-TestResults -> RED, then GREEN
#   4. Find-FlakyTests -> RED, then GREEN
#   5. New-MarkdownSummary -> RED, then GREEN

# Load the module under test. Use a relative path from the repo root.
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot "src/Aggregate-TestResults.ps1"

# Dot-source the implementation (makes all functions available in test scope)
. $scriptPath

$fixturesPath = Join-Path $repoRoot "fixtures"

# ============================================================
# BLOCK 1: Parse-JUnitXml
# WRITTEN FIRST (before any implementation existed) - was RED
# Made GREEN by implementing Parse-JUnitXml in src/
# ============================================================
Describe "Parse-JUnitXml" {
    Context "When parsing a valid JUnit XML file" {
        BeforeAll {
            $script:result = Parse-JUnitXml -Path (Join-Path $fixturesPath "junit-run1.xml")
        }

        It "should return a non-null result" {
            $script:result | Should -Not -BeNull
        }

        It "should return the correct total test count" {
            $script:result.TotalTests | Should -Be 5
        }

        It "should return the correct passed count" {
            $script:result.Passed | Should -Be 3
        }

        It "should return the correct failed count" {
            $script:result.Failed | Should -Be 1
        }

        It "should return the correct skipped count" {
            $script:result.Skipped | Should -Be 1
        }

        It "should return the correct duration" {
            $script:result.Duration | Should -Be 10.5
        }

        It "should include a list of test cases" {
            $script:result.TestCases | Should -Not -BeNullOrEmpty
            $script:result.TestCases.Count | Should -Be 5
        }

        It "should identify the failing test case" {
            $failedTest = $script:result.TestCases | Where-Object { $_.Status -eq "failed" }
            $failedTest | Should -Not -BeNull
            $failedTest.Name | Should -Be "FlakeTest"
        }

        It "should identify the skipped test case" {
            $skippedTest = $script:result.TestCases | Where-Object { $_.Status -eq "skipped" }
            $skippedTest | Should -Not -BeNull
            $skippedTest.Name | Should -Be "SkippedTest"
        }

        It "should store the source file path" {
            $script:result.SourceFile | Should -Match "junit-run1.xml"
        }

        It "should store the format as junit" {
            $script:result.Format | Should -Be "junit"
        }
    }

    Context "When parsing a file with no failures" {
        BeforeAll {
            $script:run2 = Parse-JUnitXml -Path (Join-Path $fixturesPath "junit-run2.xml")
        }

        It "should return 0 failed tests" {
            $script:run2.Failed | Should -Be 0
        }

        It "should return 4 passed tests" {
            $script:run2.Passed | Should -Be 4
        }
    }

    Context "Error handling" {
        It "should throw a meaningful error for a missing file" {
            { Parse-JUnitXml -Path "nonexistent.xml" } | Should -Throw "*not found*"
        }

        It "should throw a meaningful error for invalid XML" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value "this is not xml"
            try {
                { Parse-JUnitXml -Path $tempFile } | Should -Throw "*Invalid XML*"
            } finally {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
    }
}

# ============================================================
# BLOCK 2: Parse-JsonResults
# WRITTEN SECOND (before JSON implementation) - was RED
# Made GREEN by implementing Parse-JsonResults in src/
# ============================================================
Describe "Parse-JsonResults" {
    Context "When parsing a valid JSON test results file" {
        BeforeAll {
            $script:jsonResult = Parse-JsonResults -Path (Join-Path $fixturesPath "json-run1.json")
        }

        It "should return a non-null result" {
            $script:jsonResult | Should -Not -BeNull
        }

        It "should return the correct total test count" {
            $script:jsonResult.TotalTests | Should -Be 3
        }

        It "should return the correct passed count" {
            $script:jsonResult.Passed | Should -Be 2
        }

        It "should return the correct failed count" {
            $script:jsonResult.Failed | Should -Be 1
        }

        It "should return 0 skipped tests" {
            $script:jsonResult.Skipped | Should -Be 0
        }

        It "should compute the correct total duration" {
            $script:jsonResult.Duration | Should -Be 3.5
        }

        It "should include a list of test cases" {
            $script:jsonResult.TestCases.Count | Should -Be 3
        }

        It "should identify the failing test" {
            $failed = $script:jsonResult.TestCases | Where-Object { $_.Status -eq "failed" }
            $failed.Name | Should -Be "JsonFailTest"
            $failed.Message | Should -Match "Expected true"
        }

        It "should store the format as json" {
            $script:jsonResult.Format | Should -Be "json"
        }
    }

    Context "Error handling" {
        It "should throw a meaningful error for a missing file" {
            { Parse-JsonResults -Path "nonexistent.json" } | Should -Throw "*not found*"
        }

        It "should throw a meaningful error for invalid JSON" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value "{ invalid json }"
            try {
                { Parse-JsonResults -Path $tempFile } | Should -Throw "*Invalid JSON*"
            } finally {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
    }
}

# ============================================================
# BLOCK 3: Aggregate-TestResults
# WRITTEN THIRD - was RED until Aggregate-TestResults implemented
# ============================================================
Describe "Aggregate-TestResults" {
    Context "When aggregating all three fixture files" {
        BeforeAll {
            $paths = @(
                (Join-Path $fixturesPath "junit-run1.xml"),
                (Join-Path $fixturesPath "junit-run2.xml"),
                (Join-Path $fixturesPath "json-run1.json")
            )
            $script:agg = Aggregate-TestResults -Paths $paths
        }

        It "should return aggregated results" {
            $script:agg | Should -Not -BeNull
        }

        It "should have correct total test count" {
            # run1: 5, run2: 5, json: 3 = 13
            $script:agg.TotalTests | Should -Be 13
        }

        It "should have correct total passed count" {
            # run1: 3, run2: 4, json: 2 = 9
            $script:agg.TotalPassed | Should -Be 9
        }

        It "should have correct total failed count" {
            # run1: 1, run2: 0, json: 1 = 2
            $script:agg.TotalFailed | Should -Be 2
        }

        It "should have correct total skipped count" {
            # run1: 1, run2: 1, json: 0 = 2
            $script:agg.TotalSkipped | Should -Be 2
        }

        It "should have correct total duration" {
            # 10.5 + 9.0 + 3.5 = 23.0
            $script:agg.TotalDuration | Should -Be 23.0
        }

        It "should track 3 source files" {
            $script:agg.Files.Count | Should -Be 3
        }

        It "should group test cases by name for flaky detection" {
            $script:agg.TestCasesByName | Should -Not -BeNull
            # FlakeTest appears in both junit files
            $script:agg.TestCasesByName.ContainsKey("AppTests.UnitTests::FlakeTest") | Should -BeTrue
        }
    }

    Context "When aggregating a single file" {
        It "should handle a single JUnit file" {
            $singleResult = Aggregate-TestResults -Paths @((Join-Path $fixturesPath "junit-run1.xml"))
            $singleResult.TotalTests | Should -Be 5
            $singleResult.Files.Count | Should -Be 1
        }
    }

    Context "Error handling" {
        It "should throw if no paths provided" {
            { Aggregate-TestResults -Paths @() } | Should -Throw "*at least one*"
        }

        It "should skip files with unrecognized extensions but warn" {
            # Unsupported files should not cause a fatal error
            $paths = @((Join-Path $fixturesPath "junit-run1.xml"))
            $result = Aggregate-TestResults -Paths $paths
            $result | Should -Not -BeNull
        }
    }
}

# ============================================================
# BLOCK 4: Find-FlakyTests
# WRITTEN FOURTH - was RED until Find-FlakyTests implemented
# ============================================================
Describe "Find-FlakyTests" {
    Context "When identifying flaky tests across multiple runs" {
        BeforeAll {
            $paths = @(
                (Join-Path $fixturesPath "junit-run1.xml"),
                (Join-Path $fixturesPath "junit-run2.xml"),
                (Join-Path $fixturesPath "json-run1.json")
            )
            $aggregated = Aggregate-TestResults -Paths $paths
            $script:flaky = Find-FlakyTests -AggregatedResults $aggregated
        }

        It "should return a list of flaky tests" {
            $script:flaky | Should -Not -BeNull
        }

        It "should identify exactly one flaky test" {
            # FlakeTest: failed in run1, passed in run2
            $script:flaky.Count | Should -Be 1
        }

        It "should identify FlakeTest as the flaky test" {
            $script:flaky[0].Name | Should -Be "AppTests.UnitTests::FlakeTest"
        }

        It "should record which runs passed and which failed" {
            $flakyTest = $script:flaky[0]
            $flakyTest.PassCount | Should -Be 1
            $flakyTest.FailCount | Should -Be 1
        }
    }

    Context "When there are no flaky tests" {
        BeforeAll {
            # Only use the stable run (run2 has no failures)
            $paths = @((Join-Path $fixturesPath "junit-run2.xml"))
            $aggregated = Aggregate-TestResults -Paths $paths
            $script:noFlaky = Find-FlakyTests -AggregatedResults $aggregated
        }

        It "should return an empty list when no tests are flaky" {
            $script:noFlaky.Count | Should -Be 0
        }
    }
}

# ============================================================
# BLOCK 5: New-MarkdownSummary
# WRITTEN FIFTH - was RED until New-MarkdownSummary implemented
# ============================================================
Describe "New-MarkdownSummary" {
    Context "When generating a summary with flaky tests" {
        BeforeAll {
            $paths = @(
                (Join-Path $fixturesPath "junit-run1.xml"),
                (Join-Path $fixturesPath "junit-run2.xml"),
                (Join-Path $fixturesPath "json-run1.json")
            )
            $aggregated = Aggregate-TestResults -Paths $paths
            $flaky = Find-FlakyTests -AggregatedResults $aggregated
            $script:markdown = New-MarkdownSummary -AggregatedResults $aggregated -FlakyTests $flaky
        }

        It "should return a non-empty markdown string" {
            $script:markdown | Should -Not -BeNullOrEmpty
        }

        It "should include the total test count (13)" {
            $script:markdown | Should -Match "13"
        }

        It "should include the passed count (9)" {
            $script:markdown | Should -Match "9"
        }

        It "should include the failed count (2)" {
            $script:markdown | Should -Match "2"
        }

        It "should include the skipped count (2)" {
            $script:markdown | Should -Match "2"
        }

        It "should include a flaky tests section" {
            $script:markdown | Should -Match -RegularExpression "(?i)flaky"
        }

        It "should mention the flaky test by name" {
            $script:markdown | Should -Match "FlakeTest"
        }

        It "should include markdown table formatting" {
            $script:markdown | Should -Match "\|"
        }

        It "should include a header" {
            $script:markdown | Should -Match "^#"
        }

        It "should include duration information" {
            $script:markdown | Should -Match "23"
        }
    }

    Context "When there are no failures or flaky tests" {
        BeforeAll {
            $paths = @((Join-Path $fixturesPath "junit-run2.xml"))
            $aggregated = Aggregate-TestResults -Paths $paths
            $flaky = Find-FlakyTests -AggregatedResults $aggregated
            $script:cleanMarkdown = New-MarkdownSummary -AggregatedResults $aggregated -FlakyTests $flaky
        }

        It "should indicate all tests passed" {
            $script:cleanMarkdown | Should -Match -RegularExpression "(?i)(all tests passed|no failures|passed)"
        }

        It "should not show a flaky tests section when there are none" {
            $script:cleanMarkdown | Should -Not -Match -RegularExpression "(?i)flaky tests\s*\|"
        }
    }
}

# ============================================================
# BLOCK 6: Integration - workflow structure validation
# ============================================================
Describe "Workflow Structure" {
    BeforeAll {
        $script:workflowPath = Join-Path (Split-Path -Parent $PSScriptRoot) ".github/workflows/test-results-aggregator.yml"
    }

    It "workflow file should exist" {
        Test-Path $script:workflowPath | Should -BeTrue
    }

    It "workflow should reference the correct script path" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "Aggregate-TestResults"
    }

    It "workflow should use pwsh shell" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "workflow should use actions/checkout" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "actions/checkout"
    }

    It "script file should exist" {
        $srcPath = Join-Path (Split-Path -Parent $PSScriptRoot) "src/Aggregate-TestResults.ps1"
        Test-Path $srcPath | Should -BeTrue
    }

    It "fixture files should exist" {
        $fixtPath = Join-Path (Split-Path -Parent $PSScriptRoot) "fixtures"
        (Get-ChildItem $fixtPath -File).Count | Should -Be 3
    }
}
