# TDD approach: these tests were written BEFORE the implementation.
# Red phase: all tests fail because src/Invoke-TestAggregator.ps1 doesn't exist yet.
# Green phase: implement the minimum code to make each test pass.
# Refactor phase: improve code quality without breaking tests.

BeforeAll {
    $script:TestRoot    = Split-Path $PSScriptRoot -Parent
    $script:FixturesPath = "$script:TestRoot/fixtures"
    . "$script:TestRoot/src/Invoke-TestAggregator.ps1"
}

# ─── ConvertFrom-JUnitXml ───────────────────────────────────────────────────

Describe "ConvertFrom-JUnitXml" {
    Context "Given run1-junit.xml (6 passed, 1 failed, 1 skipped, duration 12.5)" {
        BeforeAll {
            $script:r1 = ConvertFrom-JUnitXml -Path "$script:FixturesPath/run1-junit.xml"
        }

        It "Returns 8 test cases" {
            $script:r1.Tests.Count | Should -Be 8
        }

        It "Identifies 6 passed tests" {
            ($script:r1.Tests | Where-Object Status -eq 'passed').Count | Should -Be 6
        }

        It "Identifies 1 failed test (TestSubtract)" {
            $failed = $script:r1.Tests | Where-Object Status -eq 'failed'
            $failed.Count  | Should -Be 1
            $failed[0].Name | Should -Be 'TestSubtract'
        }

        It "Identifies 1 skipped test (TestMultiply)" {
            $skipped = $script:r1.Tests | Where-Object Status -eq 'skipped'
            $skipped.Count  | Should -Be 1
            $skipped[0].Name | Should -Be 'TestMultiply'
        }

        It "Sets total duration to 12.5" {
            $script:r1.Duration | Should -Be 12.5
        }

        It "Sets run name from filename" {
            $script:r1.Run | Should -Be 'run1-junit'
        }
    }

    Context "Given run2-junit.xml (6 passed, 2 failed, 0 skipped, duration 10.2)" {
        BeforeAll {
            $script:r2 = ConvertFrom-JUnitXml -Path "$script:FixturesPath/run2-junit.xml"
        }

        It "Returns 8 test cases" {
            $script:r2.Tests.Count | Should -Be 8
        }

        It "Identifies 2 failed tests" {
            ($script:r2.Tests | Where-Object Status -eq 'failed').Count | Should -Be 2
        }

        It "Sets total duration to 10.2" {
            $script:r2.Duration | Should -Be 10.2
        }
    }
}

# ─── ConvertFrom-JsonResults ────────────────────────────────────────────────

Describe "ConvertFrom-JsonResults" {
    Context "Given run3-results.json (5 passed, 1 failed, 1 skipped, duration 8.3)" {
        BeforeAll {
            $script:r3 = ConvertFrom-JsonResults -Path "$script:FixturesPath/run3-results.json"
        }

        It "Returns 7 test cases" {
            $script:r3.Tests.Count | Should -Be 7
        }

        It "Identifies 5 passed tests" {
            ($script:r3.Tests | Where-Object Status -eq 'passed').Count | Should -Be 5
        }

        It "Identifies 1 failed test (TestLogout)" {
            $failed = $script:r3.Tests | Where-Object Status -eq 'failed'
            $failed.Count   | Should -Be 1
            $failed[0].Name | Should -Be 'TestLogout'
        }

        It "Uses run name from JSON field" {
            $script:r3.Run | Should -Be 'run3'
        }

        It "Uses run-level duration from JSON" {
            $script:r3.Duration | Should -Be 8.3
        }
    }

    Context "Given run4-results.json (6 passed, 1 failed, 0 skipped, duration 9.1)" {
        BeforeAll {
            $script:r4 = ConvertFrom-JsonResults -Path "$script:FixturesPath/run4-results.json"
        }

        It "Returns 7 test cases" {
            $script:r4.Tests.Count | Should -Be 7
        }

        It "Identifies 1 failed test (TestSubtract)" {
            $failed = $script:r4.Tests | Where-Object Status -eq 'failed'
            $failed.Count   | Should -Be 1
            $failed[0].Name | Should -Be 'TestSubtract'
        }
    }
}

# ─── Merge-TestResults ──────────────────────────────────────────────────────

Describe "Merge-TestResults" {
    # Exact expected totals across all 4 runs:
    #   Passed : 6+6+5+6 = 23
    #   Failed : 1+2+1+1 = 5
    #   Skipped: 1+0+1+0 = 2
    #   Duration: 12.5+10.2+8.3+9.1 = 40.1
    #   Total tests: 8+8+7+7 = 30

    BeforeAll {
        $run1 = ConvertFrom-JUnitXml    -Path "$script:FixturesPath/run1-junit.xml"
        $run2 = ConvertFrom-JUnitXml    -Path "$script:FixturesPath/run2-junit.xml"
        $run3 = ConvertFrom-JsonResults -Path "$script:FixturesPath/run3-results.json"
        $run4 = ConvertFrom-JsonResults -Path "$script:FixturesPath/run4-results.json"
        $script:merged = Merge-TestResults -RunResults @($run1, $run2, $run3, $run4)
    }

    It "Computes TotalPassed = 23" {
        $script:merged.TotalPassed | Should -Be 23
    }

    It "Computes TotalFailed = 5" {
        $script:merged.TotalFailed | Should -Be 5
    }

    It "Computes TotalSkipped = 2" {
        $script:merged.TotalSkipped | Should -Be 2
    }

    It "Computes TotalDuration = 40.1" {
        $script:merged.TotalDuration | Should -Be 40.1
    }

    It "Includes all 30 test entries" {
        $script:merged.Tests.Count | Should -Be 30
    }
}

# ─── Find-FlakyTests ────────────────────────────────────────────────────────

Describe "Find-FlakyTests" {
    # Flaky = test appears with both 'passed' and 'failed' status across runs.
    # Skipped results are neutral and never determine flakiness.
    #
    # TestSubtract : failed(r1) passed(r2) passed(r3) failed(r4) → FLAKY
    # TestDivide   : passed(r1) failed(r2) passed(r3) passed(r4) → FLAKY
    # TestAPICall  : passed(r1) failed(r2)                        → FLAKY
    # TestLogout   :                        failed(r3) passed(r4) → FLAKY
    # TestMultiply : skipped(r1) passed(r2) passed(r3) passed(r4)→ NOT flaky

    BeforeAll {
        $run1 = ConvertFrom-JUnitXml    -Path "$script:FixturesPath/run1-junit.xml"
        $run2 = ConvertFrom-JUnitXml    -Path "$script:FixturesPath/run2-junit.xml"
        $run3 = ConvertFrom-JsonResults -Path "$script:FixturesPath/run3-results.json"
        $run4 = ConvertFrom-JsonResults -Path "$script:FixturesPath/run4-results.json"
        $merged = Merge-TestResults -RunResults @($run1, $run2, $run3, $run4)
        $script:flaky = Find-FlakyTests -AllTests $merged.Tests
    }

    It "Finds exactly 4 flaky tests" {
        $script:flaky.Count | Should -Be 4
    }

    It "Includes TestSubtract" {
        $script:flaky | Should -Contain 'TestSubtract'
    }

    It "Includes TestDivide" {
        $script:flaky | Should -Contain 'TestDivide'
    }

    It "Includes TestAPICall" {
        $script:flaky | Should -Contain 'TestAPICall'
    }

    It "Includes TestLogout" {
        $script:flaky | Should -Contain 'TestLogout'
    }

    It "Does NOT include TestAdd (always passed)" {
        $script:flaky | Should -Not -Contain 'TestAdd'
    }

    It "Does NOT include TestMultiply (only skipped+passed, never failed)" {
        $script:flaky | Should -Not -Contain 'TestMultiply'
    }
}

# ─── New-MarkdownSummary ────────────────────────────────────────────────────

Describe "New-MarkdownSummary" {
    BeforeAll {
        $agg = [PSCustomObject]@{
            TotalPassed   = 23
            TotalFailed   = 5
            TotalSkipped  = 2
            TotalDuration = 40.1
            Tests         = @()
        }
        $script:md = New-MarkdownSummary -Aggregated $agg -FlakyTests @(
            'TestAPICall', 'TestDivide', 'TestLogout', 'TestSubtract'
        )
    }

    It "Contains the summary heading" {
        $script:md | Should -Match '## Test Results Summary'
    }

    It "Shows passed count in table" {
        $script:md | Should -Match '\| Passed \| 23 \|'
    }

    It "Shows failed count in table" {
        $script:md | Should -Match '\| Failed \| 5 \|'
    }

    It "Shows skipped count in table" {
        $script:md | Should -Match '\| Skipped \| 2 \|'
    }

    It "Shows duration in table" {
        $script:md | Should -Match '\| Total Duration \| 40\.1s \|'
    }

    It "Shows pass rate" {
        # 23/(23+5+2) = 23/30 = 76.7%
        $script:md | Should -Match '\| Pass Rate \| 76\.7% \|'
    }

    It "Lists flaky tests section with count" {
        $script:md | Should -Match '### Flaky Tests \(4\)'
    }

    It "Lists each flaky test as a bullet" {
        $script:md | Should -Match '- TestAPICall'
        $script:md | Should -Match '- TestDivide'
        $script:md | Should -Match '- TestLogout'
        $script:md | Should -Match '- TestSubtract'
    }

    It "Shows 'No Flaky Tests' when there are none" {
        $agg2 = [PSCustomObject]@{ TotalPassed=5; TotalFailed=0; TotalSkipped=0; TotalDuration=1.0; Tests=@() }
        $md2  = New-MarkdownSummary -Aggregated $agg2 -FlakyTests @()
        $md2  | Should -Match 'No Flaky Tests Detected'
    }
}

# ─── Workflow Structure ──────────────────────────────────────────────────────

Describe "Workflow Structure" {
    BeforeAll {
        $script:WorkflowPath = "$script:TestRoot/.github/workflows/test-results-aggregator.yml"
        $script:WorkflowContent = if (Test-Path $script:WorkflowPath) {
            Get-Content $script:WorkflowPath -Raw
        } else { '' }
    }

    It "Workflow file exists" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "Source script exists" {
        Test-Path "$script:TestRoot/src/Invoke-TestAggregator.ps1" | Should -Be $true
    }

    It "All 4 fixture files exist" {
        Test-Path "$script:FixturesPath/run1-junit.xml"      | Should -Be $true
        Test-Path "$script:FixturesPath/run2-junit.xml"      | Should -Be $true
        Test-Path "$script:FixturesPath/run3-results.json"   | Should -Be $true
        Test-Path "$script:FixturesPath/run4-results.json"   | Should -Be $true
    }

    It "Workflow has push trigger" {
        $script:WorkflowContent | Should -Match 'push:'
    }

    It "Workflow has pull_request trigger" {
        $script:WorkflowContent | Should -Match 'pull_request:'
    }

    It "Workflow has workflow_dispatch trigger" {
        $script:WorkflowContent | Should -Match 'workflow_dispatch:'
    }

    It "Workflow uses shell: pwsh" {
        $script:WorkflowContent | Should -Match 'shell:\s*pwsh'
    }

    It "Workflow references Invoke-TestAggregator.ps1" {
        $script:WorkflowContent | Should -Match 'Invoke-TestAggregator\.ps1'
    }

    It "Workflow uses actions/checkout@v4" {
        $script:WorkflowContent | Should -Match 'actions/checkout@v4'
    }
}
