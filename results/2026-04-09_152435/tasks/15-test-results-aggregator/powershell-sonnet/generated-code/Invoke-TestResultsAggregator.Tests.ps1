# Invoke-TestResultsAggregator.Tests.ps1
#
# TDD approach:
#   RED   — write a failing test for a function that doesn't exist yet
#   GREEN — add the minimum implementation to make it pass
#   REFACTOR — clean up without breaking tests
#
# We follow this cycle for each piece of functionality:
#   1. Parse-JUnitXml
#   2. Parse-JsonResults
#   3. Aggregate-TestResults
#   4. Find-FlakyTests
#   5. New-MarkdownSummary
# Plus workflow-structure validation tests.

BeforeAll {
    # Load all functions from the main script without running its main body.
    # The script guards execution with "if ($InputPaths)" so dot-sourcing is safe.
    $script:ScriptDir = Split-Path -Parent $PSCommandPath
    . "$script:ScriptDir/Invoke-TestResultsAggregator.ps1"

    # Fixture paths (designed once, used across all Describe blocks)
    $script:Fixture1 = Join-Path $script:ScriptDir "fixtures/junit-results-1.xml"
    $script:Fixture2 = Join-Path $script:ScriptDir "fixtures/junit-results-2.xml"
    $script:Fixture3 = Join-Path $script:ScriptDir "fixtures/json-results-1.json"
}

# ─── RED → GREEN cycle 1: Parse-JUnitXml ─────────────────────────────────────
Describe "Parse-JUnitXml" {
    Context "Given junit-results-1.xml (3 tests: 2 passed, 1 failed)" {
        BeforeAll {
            $script:R1 = Parse-JUnitXml -Path $script:Fixture1
        }

        It "Returns exactly 3 test results" {
            $script:R1 | Should -HaveCount 3
        }

        It "Identifies 2 passed tests" {
            ($script:R1 | Where-Object { $_.Status -eq "passed" }) | Should -HaveCount 2
        }

        It "Identifies 1 failed test" {
            ($script:R1 | Where-Object { $_.Status -eq "failed" }) | Should -HaveCount 1
        }

        It "Names the failed test correctly" {
            $failed = $script:R1 | Where-Object { $_.Status -eq "failed" }
            $failed.Name | Should -Be "test_register"
        }

        It "Captures the failure message" {
            $failed = $script:R1 | Where-Object { $_.Status -eq "failed" }
            $failed.Message | Should -BeLike "*Expected status 201*"
        }

        It "Records the source file name on every result" {
            $script:R1 | ForEach-Object { $_.File | Should -Be "junit-results-1.xml" }
        }

        It "Records per-test durations summing to ~1.500 s" {
            $total = ($script:R1 | Measure-Object -Property Duration -Sum).Sum
            $total | Should -BeGreaterOrEqual 1.499
            $total | Should -BeLessOrEqual 1.501
        }
    }

    Context "Given junit-results-2.xml (3 tests: all passed)" {
        BeforeAll {
            $script:R2 = Parse-JUnitXml -Path $script:Fixture2
        }

        It "Returns exactly 3 test results" {
            $script:R2 | Should -HaveCount 3
        }

        It "All tests are passed (0 failures)" {
            ($script:R2 | Where-Object { $_.Status -eq "failed" }) | Should -HaveCount 0
        }
    }
}

# ─── RED → GREEN cycle 2: Parse-JsonResults ──────────────────────────────────
Describe "Parse-JsonResults" {
    Context "Given json-results-1.json (3 tests: 2 passed, 1 skipped)" {
        BeforeAll {
            $script:J1 = Parse-JsonResults -Path $script:Fixture3
        }

        It "Returns exactly 3 test results" {
            $script:J1 | Should -HaveCount 3
        }

        It "Identifies 2 passed tests" {
            ($script:J1 | Where-Object { $_.Status -eq "passed" }) | Should -HaveCount 2
        }

        It "Identifies 1 skipped test" {
            ($script:J1 | Where-Object { $_.Status -eq "skipped" }) | Should -HaveCount 1
        }

        It "Names the skipped test correctly" {
            $skipped = $script:J1 | Where-Object { $_.Status -eq "skipped" }
            $skipped.Name | Should -Be "test_delete_user"
        }

        It "Records the source file name on every result" {
            $script:J1 | ForEach-Object { $_.File | Should -Be "json-results-1.json" }
        }
    }
}

# ─── RED → GREEN cycle 3: Aggregate-TestResults ───────────────────────────────
Describe "Aggregate-TestResults" {
    BeforeAll {
        $r1 = Parse-JUnitXml    -Path $script:Fixture1
        $r2 = Parse-JUnitXml    -Path $script:Fixture2
        $r3 = Parse-JsonResults -Path $script:Fixture3
        $script:AllResults = @() + $r1 + $r2 + $r3
        $script:Agg = Aggregate-TestResults -AllResults $script:AllResults
    }

    It "Computes total count = 9" {
        $script:Agg.Total | Should -Be 9
    }

    It "Computes passed count = 7" {
        $script:Agg.Passed | Should -Be 7
    }

    It "Computes failed count = 1" {
        $script:Agg.Failed | Should -Be 1
    }

    It "Computes skipped count = 1" {
        $script:Agg.Skipped | Should -Be 1
    }

    It "Computes total duration = 3.40 s" {
        $script:Agg.Duration | Should -Be 3.40
    }

    It "Includes the 1 failed test detail" {
        $script:Agg.FailedTests | Should -HaveCount 1
        $script:Agg.FailedTests[0].Name | Should -Be "test_register"
    }
}

# ─── RED → GREEN cycle 4: Find-FlakyTests ────────────────────────────────────
Describe "Find-FlakyTests" {
    BeforeAll {
        $r1 = Parse-JUnitXml    -Path $script:Fixture1
        $r2 = Parse-JUnitXml    -Path $script:Fixture2
        $r3 = Parse-JsonResults -Path $script:Fixture3
        $script:AllForFlaky = @() + $r1 + $r2 + $r3
    }

    Context "Results that contain a flaky test (test_register)" {
        BeforeAll {
            $script:Flaky = Find-FlakyTests -AllResults $script:AllForFlaky
        }

        It "Detects test_register as flaky" {
            ($script:Flaky | Where-Object { $_.Name -eq "test_register" }) | Should -Not -BeNullOrEmpty
        }

        It "Reports 1 pass and 1 fail for test_register" {
            $f = $script:Flaky | Where-Object { $_.Name -eq "test_register" }
            $f.Passed | Should -Be 1
            $f.Failed  | Should -Be 1
        }
    }

    Context "Results with no flaky tests (runs 2 and 3 only)" {
        BeforeAll {
            $r2Only = Parse-JUnitXml    -Path $script:Fixture2
            $r3Only = Parse-JsonResults -Path $script:Fixture3
            $script:NoFlaky = Find-FlakyTests -AllResults (@() + $r2Only + $r3Only)
        }

        It "Returns an empty collection" {
            $script:NoFlaky | Should -HaveCount 0
        }
    }
}

# ─── RED → GREEN cycle 5: New-MarkdownSummary ────────────────────────────────
Describe "New-MarkdownSummary" {
    BeforeAll {
        $r1 = Parse-JUnitXml    -Path $script:Fixture1
        $r2 = Parse-JUnitXml    -Path $script:Fixture2
        $r3 = Parse-JsonResults -Path $script:Fixture3
        $all = @() + $r1 + $r2 + $r3
        $agg   = Aggregate-TestResults -AllResults $all
        $flaky = Find-FlakyTests       -AllResults $all
        $script:MD = New-MarkdownSummary -Aggregated $agg -FlakyTests $flaky
    }

    It "Contains the H1 title" {
        $script:MD | Should -Match "# Test Results Summary"
    }

    It "Contains the totals table row for Total Tests = 9" {
        $script:MD | Should -Match "\| Total Tests \| 9 \|"
    }

    It "Contains the totals table row for Passed = 7" {
        $script:MD | Should -Match "\| Passed \| 7 \|"
    }

    It "Contains the totals table row for Failed = 1" {
        $script:MD | Should -Match "\| Failed \| 1 \|"
    }

    It "Contains the totals table row for Skipped = 1" {
        $script:MD | Should -Match "\| Skipped \| 1 \|"
    }

    It "Contains the duration row (3.40)" {
        $script:MD | Should -Match "\| Duration.*3\.40"
    }

    It "Lists test_register as a flaky test" {
        $script:MD | Should -Match "test_register"
    }

    It "Includes the failure message in the Failed Tests section" {
        $script:MD | Should -Match "Expected status 201"
    }
}

# ─── Workflow-structure tests (run inside the act container too) ──────────────
Describe "WorkflowStructure" {
    BeforeAll {
        $script:WFPath    = Join-Path $script:ScriptDir ".github/workflows/test-results-aggregator.yml"
        $script:WFContent = if (Test-Path $script:WFPath) { Get-Content -Path $script:WFPath -Raw } else { "" }
    }

    It "Workflow file exists at .github/workflows/test-results-aggregator.yml" {
        Test-Path $script:WFPath | Should -Be $true
    }

    It "Has a push trigger" {
        $script:WFContent | Should -Match "push:"
    }

    It "Has a workflow_dispatch trigger" {
        $script:WFContent | Should -Match "workflow_dispatch:"
    }

    It "Uses actions/checkout@v4" {
        $script:WFContent | Should -Match "actions/checkout@v4"
    }

    It "References Invoke-TestResultsAggregator.ps1" {
        $script:WFContent | Should -Match "Invoke-TestResultsAggregator\.ps1"
    }

    It "Main script file exists" {
        Test-Path (Join-Path $script:ScriptDir "Invoke-TestResultsAggregator.ps1") | Should -Be $true
    }

    It "All three fixture files exist" {
        Test-Path (Join-Path $script:ScriptDir "fixtures/junit-results-1.xml")  | Should -Be $true
        Test-Path (Join-Path $script:ScriptDir "fixtures/junit-results-2.xml")  | Should -Be $true
        Test-Path (Join-Path $script:ScriptDir "fixtures/json-results-1.json")  | Should -Be $true
    }

    It "Passes actionlint validation" {
        $al = Get-Command actionlint -ErrorAction SilentlyContinue
        if (-not $al) {
            Set-ItResult -Skipped -Because "actionlint not installed in this environment"
            return
        }
        $out = & actionlint $script:WFPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $out"
    }
}
