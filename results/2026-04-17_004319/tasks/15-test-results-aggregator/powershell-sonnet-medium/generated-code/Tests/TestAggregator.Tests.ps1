# Test Results Aggregator - Pester Tests
# TDD approach: tests written first (red), then implementation makes them pass (green).
#
# Expected fixture totals (used for exact assertions):
#   junit-run1.xml : TestA(pass,0.5s) TestB(fail,0.3s) TestC(skip,0.0s) TestD(pass,1.2s)
#   junit-run2.xml : TestA(pass,0.4s) TestB(pass,0.2s) TestC(skip,0.0s) TestD(fail,1.0s)
#   json-run1.json : TestE(pass,0.8s) TestF(fail,0.5s)
#   json-run2.json : TestE(fail,0.7s) TestF(pass,0.4s)
#   Total: 12 tests, 6 passed, 4 failed, 2 skipped, 6.00s duration
#   Flaky: TestB, TestD, TestE, TestF (4 tests)

BeforeAll {
    . "$PSScriptRoot/../TestAggregator-Functions.ps1"
    $script:FixturesPath = "$PSScriptRoot/../fixtures"
}

# ── TDD Cycle 1: Parse JUnit XML ──────────────────────────────────────────────
Describe "Parse-JUnitXml" {

    It "Should parse 4 test cases from junit-run1.xml" {
        $results = Parse-JUnitXml -FilePath "$script:FixturesPath/junit-run1.xml"
        $results.Count | Should -Be 4
    }

    It "Should identify 2 passed tests in run1" {
        $results = Parse-JUnitXml -FilePath "$script:FixturesPath/junit-run1.xml"
        ($results | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 2
    }

    It "Should identify TestB as failed in run1" {
        $results = Parse-JUnitXml -FilePath "$script:FixturesPath/junit-run1.xml"
        $failed = $results | Where-Object { $_.Status -eq 'failed' }
        $failed.Count | Should -Be 1
        $failed[0].Name | Should -Be 'TestB'
    }

    It "Should identify TestC as skipped in run1" {
        $results = Parse-JUnitXml -FilePath "$script:FixturesPath/junit-run1.xml"
        $skipped = $results | Where-Object { $_.Status -eq 'skipped' }
        $skipped.Count | Should -Be 1
        $skipped[0].Name | Should -Be 'TestC'
    }

    It "Should capture TestA duration of 0.5s" {
        $results = Parse-JUnitXml -FilePath "$script:FixturesPath/junit-run1.xml"
        ($results | Where-Object { $_.Name -eq 'TestA' }).Duration | Should -Be 0.5
    }

    It "Should capture failure message for TestB" {
        $results = Parse-JUnitXml -FilePath "$script:FixturesPath/junit-run1.xml"
        ($results | Where-Object { $_.Name -eq 'TestB' }).Message | Should -Match "Assertion failed"
    }

    It "Should throw for a non-existent XML file" {
        { Parse-JUnitXml -FilePath "/nonexistent/file.xml" } | Should -Throw
    }
}

# ── TDD Cycle 2: Parse JSON ───────────────────────────────────────────────────
Describe "Parse-JsonResults" {

    It "Should parse 2 test cases from json-run1.json" {
        $results = Parse-JsonResults -FilePath "$script:FixturesPath/json-run1.json"
        $results.Count | Should -Be 2
    }

    It "Should identify TestE as passed" {
        $results = Parse-JsonResults -FilePath "$script:FixturesPath/json-run1.json"
        $passed = $results | Where-Object { $_.Status -eq 'passed' }
        $passed.Count | Should -Be 1
        $passed[0].Name | Should -Be 'TestE'
    }

    It "Should identify TestF as failed" {
        $results = Parse-JsonResults -FilePath "$script:FixturesPath/json-run1.json"
        $failed = $results | Where-Object { $_.Status -eq 'failed' }
        $failed.Count | Should -Be 1
        $failed[0].Name | Should -Be 'TestF'
    }

    It "Should capture TestE duration of 0.8s" {
        $results = Parse-JsonResults -FilePath "$script:FixturesPath/json-run1.json"
        ($results | Where-Object { $_.Name -eq 'TestE' }).Duration | Should -Be 0.8
    }

    It "Should capture suite name 'APITests'" {
        $results = Parse-JsonResults -FilePath "$script:FixturesPath/json-run1.json"
        $results[0].Suite | Should -Be 'APITests'
    }

    It "Should throw for a non-existent JSON file" {
        { Parse-JsonResults -FilePath "/nonexistent/file.json" } | Should -Throw
    }
}

# ── TDD Cycle 3: Aggregate all results ───────────────────────────────────────
Describe "Get-AllResults" {

    It "Should return 12 total results from all 4 fixture files" {
        $results = Get-AllResults -ResultsPath $script:FixturesPath
        $results.Count | Should -Be 12
    }

    It "Should return 6 passed tests across all files" {
        $results = Get-AllResults -ResultsPath $script:FixturesPath
        ($results | Where-Object { $_.Status -eq 'passed' }).Count | Should -Be 6
    }

    It "Should return 4 failed tests across all files" {
        $results = Get-AllResults -ResultsPath $script:FixturesPath
        ($results | Where-Object { $_.Status -eq 'failed' }).Count | Should -Be 4
    }

    It "Should return 2 skipped tests across all files" {
        $results = Get-AllResults -ResultsPath $script:FixturesPath
        ($results | Where-Object { $_.Status -eq 'skipped' }).Count | Should -Be 2
    }

    It "Should sum total duration to exactly 6.00s" {
        $results = Get-AllResults -ResultsPath $script:FixturesPath
        $total = ($results | Measure-Object -Property Duration -Sum).Sum
        [Math]::Round($total, 2) | Should -Be 6.0
    }

    It "Should throw for a non-existent results path" {
        { Get-AllResults -ResultsPath "/nonexistent/path" } | Should -Throw
    }
}

# ── TDD Cycle 4: Detect flaky tests ──────────────────────────────────────────
Describe "Find-FlakyTests" {

    BeforeAll {
        $script:AllResults = Get-AllResults -ResultsPath $script:FixturesPath
    }

    It "Should detect exactly 4 flaky tests" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Count | Should -Be 4
    }

    It "Should mark TestB as flaky (failed run1, passed run2)" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Name | Should -Contain 'TestB'
    }

    It "Should mark TestD as flaky (passed run1, failed run2)" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Name | Should -Contain 'TestD'
    }

    It "Should mark TestE as flaky (passed run1, failed run2)" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Name | Should -Contain 'TestE'
    }

    It "Should mark TestF as flaky (failed run1, passed run2)" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Name | Should -Contain 'TestF'
    }

    It "Should NOT mark TestA as flaky (consistently passed)" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Name | Should -Not -Contain 'TestA'
    }

    It "Should NOT mark TestC as flaky (consistently skipped)" {
        $flaky = Find-FlakyTests -Results $script:AllResults
        $flaky.Name | Should -Not -Contain 'TestC'
    }

    It "Should return 0 flaky tests when all results are stable" {
        $stable = @(
            [PSCustomObject]@{ Name = 'TestX'; Status = 'passed'; Duration = 0.1 },
            [PSCustomObject]@{ Name = 'TestX'; Status = 'passed'; Duration = 0.2 }
        )
        $flaky = Find-FlakyTests -Results $stable
        $flaky.Count | Should -Be 0
    }
}

# ── TDD Cycle 5: Generate markdown summary ────────────────────────────────────
Describe "New-MarkdownSummary" {

    BeforeAll {
        $results  = Get-AllResults -ResultsPath $script:FixturesPath
        $flaky    = Find-FlakyTests -Results $results
        $script:Summary = New-MarkdownSummary -Results $results -FlakyTests $flaky
    }

    It "Should produce non-empty markdown output" {
        $script:Summary | Should -Not -BeNullOrEmpty
    }

    It "Should contain '## Overall Results' heading" {
        $script:Summary | Should -Match "## Overall Results"
    }

    It "Should contain total test count of 12" {
        $script:Summary | Should -Match "Total Tests \| 12"
    }

    It "Should contain passed count of 6" {
        $script:Summary | Should -Match "Passed \| 6"
    }

    It "Should contain failed count of 4" {
        $script:Summary | Should -Match "Failed \| 4"
    }

    It "Should contain skipped count of 2" {
        $script:Summary | Should -Match "Skipped \| 2"
    }

    It "Should contain total duration of 6.00s" {
        $script:Summary | Should -Match "Total Duration \| 6\.00s"
    }

    It "Should have '## Flaky Tests' section" {
        $script:Summary | Should -Match "## Flaky Tests"
    }

    It "Should list TestB in flaky section" {
        $script:Summary | Should -Match "TestB"
    }

    It "Should list TestD in flaky section" {
        $script:Summary | Should -Match "TestD"
    }

    It "Should list TestE in flaky section" {
        $script:Summary | Should -Match "TestE"
    }

    It "Should list TestF in flaky section" {
        $script:Summary | Should -Match "TestF"
    }
}

# ── TDD Cycle 6: Workflow structure validation ────────────────────────────────
Describe "Workflow Structure" {

    BeforeAll {
        $script:WorkflowPath = "$PSScriptRoot/../.github/workflows/test-results-aggregator.yml"
        if (Test-Path $script:WorkflowPath) {
            $script:WorkflowContent = Get-Content $script:WorkflowPath -Raw
        } else {
            $script:WorkflowContent = ""
        }
    }

    It "Should have workflow file at .github/workflows/test-results-aggregator.yml" {
        Test-Path $script:WorkflowPath | Should -Be $true
    }

    It "Should have 'push' trigger" {
        $script:WorkflowContent | Should -Match "push:"
    }

    It "Should have 'pull_request' trigger" {
        $script:WorkflowContent | Should -Match "pull_request:"
    }

    It "Should have 'workflow_dispatch' trigger" {
        $script:WorkflowContent | Should -Match "workflow_dispatch:"
    }

    It "Should reference Invoke-TestAggregator.ps1" {
        $script:WorkflowContent | Should -Match "Invoke-TestAggregator\.ps1"
    }

    It "Should use actions/checkout@v4" {
        $script:WorkflowContent | Should -Match "actions/checkout@v4"
    }

    It "Should use 'shell: pwsh'" {
        $script:WorkflowContent | Should -Match "shell: pwsh"
    }

    It "Script files referenced in workflow should exist on disk" {
        Test-Path "$PSScriptRoot/../Invoke-TestAggregator.ps1" | Should -Be $true
        Test-Path "$PSScriptRoot/../TestAggregator-Functions.ps1" | Should -Be $true
        Test-Path "$PSScriptRoot/../fixtures" | Should -Be $true
    }

    It "Should pass actionlint with exit code 0" -Skip:($null -eq (Get-Command actionlint -ErrorAction SilentlyContinue)) {
        $output = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
