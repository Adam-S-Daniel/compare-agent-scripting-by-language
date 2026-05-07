# Test Results Aggregator — Pester test suite
# TDD approach: tests written before implementation, red then green.
# Covers: JUnit XML parsing, JSON parsing, aggregation, flaky detection,
# markdown generation, workflow structure, actionlint, and act execution.

BeforeAll {
    # Load the implementation (will fail on first red run — that's expected)
    . "$PSScriptRoot/Invoke-TestResultAggregator.ps1"
}

# ---------------------------------------------------------------------------
# RED 1: JUnit XML parsing
# ---------------------------------------------------------------------------
Describe "ConvertFrom-JUnitXml" {
    It "parses a simple JUnit XML file and returns a result object" {
        $xml = "$PSScriptRoot/fixtures/junit-matrix-1.xml"
        $result = ConvertFrom-JUnitXml -Path $xml

        $result.SourceFile | Should -Be $xml
        $result.Suite     | Should -Be "core.UnitTests"
        $result.Passed    | Should -Be 3
        $result.Failed    | Should -Be 1
        $result.Skipped   | Should -Be 1
        $result.Duration  | Should -Be 3.5
        $result.Tests.Count | Should -Be 5
    }

    It "marks individual test cases with correct status" {
        $xml = "$PSScriptRoot/fixtures/junit-matrix-1.xml"
        $result = ConvertFrom-JUnitXml -Path $xml

        $multiply = $result.Tests | Where-Object Name -EQ "test_multiply"
        $multiply.Status | Should -Be "Failed"

        $modulo = $result.Tests | Where-Object Name -EQ "test_modulo"
        $modulo.Status | Should -Be "Skipped"

        $add = $result.Tests | Where-Object Name -EQ "test_add"
        $add.Status | Should -Be "Passed"
    }

    It "parses second JUnit XML with no skipped tests" {
        $xml = "$PSScriptRoot/fixtures/junit-matrix-2.xml"
        $result = ConvertFrom-JUnitXml -Path $xml

        $result.Passed   | Should -Be 4
        $result.Failed   | Should -Be 1
        $result.Skipped  | Should -Be 0
        $result.Duration | Should -Be 4.2
    }

    It "throws a meaningful error for a missing file" {
        { ConvertFrom-JUnitXml -Path "/nonexistent/path.xml" } |
            Should -Throw "*not found*"
    }
}

# ---------------------------------------------------------------------------
# RED 2: JSON parsing
# ---------------------------------------------------------------------------
Describe "ConvertFrom-JsonResults" {
    It "parses a JSON test result file correctly" {
        $json = "$PSScriptRoot/fixtures/json-matrix-1.json"
        $result = ConvertFrom-JsonResults -Path $json

        $result.SourceFile | Should -Be $json
        $result.Suite      | Should -Be "IntegrationTests"
        $result.Passed     | Should -Be 3
        $result.Failed     | Should -Be 0
        $result.Skipped    | Should -Be 0
        $result.Duration   | Should -Be 2.1
        $result.Tests.Count | Should -Be 3
    }

    It "correctly records a failed test from JSON" {
        $json = "$PSScriptRoot/fixtures/json-matrix-2.json"
        $result = ConvertFrom-JsonResults -Path $json

        $result.Failed | Should -Be 1
        $apiCall = $result.Tests | Where-Object Name -EQ "test_api_call"
        $apiCall.Status | Should -Be "Failed"
    }

    It "throws a meaningful error for invalid JSON" {
        $tmp = [System.IO.Path]::GetTempFileName() + ".json"
        Set-Content $tmp "{ not valid json"
        { ConvertFrom-JsonResults -Path $tmp } | Should -Throw "*invalid*"
        Remove-Item $tmp -Force
    }
}

# ---------------------------------------------------------------------------
# RED 3: Aggregation
# ---------------------------------------------------------------------------
Describe "Invoke-AggregateResults" {
    BeforeAll {
        $fixtures = "$PSScriptRoot/fixtures"
        $script:agg = Invoke-AggregateResults -InputPath $fixtures
    }

    It "aggregates passed count across all fixture files" {
        # junit-1: 3, junit-2: 4, json-1: 3, json-2: 2 => 12
        $script:agg.TotalPassed | Should -Be 12
    }

    It "aggregates failed count across all fixture files" {
        # junit-1: 1, junit-2: 1, json-1: 0, json-2: 1 => 3
        $script:agg.TotalFailed | Should -Be 3
    }

    It "aggregates skipped count across all fixture files" {
        # junit-1: 1, rest: 0 => 1
        $script:agg.TotalSkipped | Should -Be 1
    }

    It "sums duration across all fixture files" {
        # 3.5 + 4.2 + 2.1 + 1.8 = 11.6
        $script:agg.TotalDuration | Should -Be 11.6
    }

    It "returns a Files array with one entry per input file" {
        $script:agg.Files.Count | Should -Be 4
    }

    It "reports total test count" {
        # 5+5+3+3 = 16
        $script:agg.TotalTests | Should -Be 16
    }
}

# ---------------------------------------------------------------------------
# RED 4: Flaky test detection
# ---------------------------------------------------------------------------
Describe "Find-FlakyTests" {
    BeforeAll {
        $fixtures = "$PSScriptRoot/fixtures"
        $agg = Invoke-AggregateResults -InputPath $fixtures
        $script:flaky = Find-FlakyTests -AggregatedResults $agg
    }

    It "identifies exactly 3 flaky tests across all files" {
        $script:flaky.Count | Should -Be 3
    }

    It "flags test_multiply in core.UnitTests as flaky" {
        $f = $script:flaky | Where-Object { $_.Name -eq "test_multiply" -and $_.Suite -eq "core.UnitTests" }
        $f | Should -Not -BeNullOrEmpty
        $f.PassedRuns | Should -Be 1
        $f.FailedRuns | Should -Be 1
    }

    It "flags test_subtract in core.UnitTests as flaky" {
        $f = $script:flaky | Where-Object { $_.Name -eq "test_subtract" -and $_.Suite -eq "core.UnitTests" }
        $f | Should -Not -BeNullOrEmpty
    }

    It "flags test_api_call in IntegrationTests as flaky" {
        $f = $script:flaky | Where-Object { $_.Name -eq "test_api_call" -and $_.Suite -eq "IntegrationTests" }
        $f | Should -Not -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# RED 5: Markdown summary generation
# ---------------------------------------------------------------------------
Describe "New-MarkdownSummary" {
    BeforeAll {
        $fixtures = "$PSScriptRoot/fixtures"
        $agg = Invoke-AggregateResults -InputPath $fixtures
        $flaky = Find-FlakyTests -AggregatedResults $agg
        $script:md = New-MarkdownSummary -AggregatedResults $agg -FlakyTests $flaky
    }

    It "contains the heading" {
        $script:md | Should -Match "## Test Results Summary"
    }

    It "contains Total Passed with exact value 12" {
        $script:md | Should -Match "Total Passed.*12"
    }

    It "contains Total Failed with exact value 3" {
        $script:md | Should -Match "Total Failed.*3"
    }

    It "contains Total Skipped with exact value 1" {
        $script:md | Should -Match "Total Skipped.*1"
    }

    It "contains duration 11.60s" {
        $script:md | Should -Match "11\.60"
    }

    It "mentions 3 flaky tests in the heading" {
        $script:md | Should -Match "Flaky Tests.*3"
    }

    It "lists test_multiply as flaky" {
        $script:md | Should -Match "test_multiply"
    }
}

# ---------------------------------------------------------------------------
# RED 6: End-to-end script invocation
# ---------------------------------------------------------------------------
Describe "Invoke-TestResultAggregator script (end-to-end)" {
    It "emits machine-readable result markers when run against fixtures" {
        # Capture output as a single string so -Match checks the full text
        $outputStr = (& "$PSScriptRoot/Invoke-TestResultAggregator.ps1" `
            -InputPath "$PSScriptRoot/fixtures" 2>&1) -join "`n"

        $outputStr | Should -Match "AGGREGATOR_RESULT_PASSED=12"
        $outputStr | Should -Match "AGGREGATOR_RESULT_FAILED=3"
        $outputStr | Should -Match "AGGREGATOR_RESULT_SKIPPED=1"
        $outputStr | Should -Match "AGGREGATOR_RESULT_FLAKY=3"
        $outputStr | Should -Match "AGGREGATOR_RESULT_TOTAL=16"
    }
}

# ---------------------------------------------------------------------------
# RED 7: Workflow structure tests
# Tag: workflow-structure — skipped when running inside the act container
# ---------------------------------------------------------------------------
Describe "GitHub Actions Workflow Structure" -Tag "workflow-structure" {
    BeforeAll {
        $wfPath = "$PSScriptRoot/.github/workflows/test-results-aggregator.yml"
        $script:wfContent = Get-Content $wfPath -Raw -ErrorAction SilentlyContinue
        # Parse YAML as text (no external YAML module needed for basic checks)
    }

    It "workflow file exists" {
        Test-Path "$PSScriptRoot/.github/workflows/test-results-aggregator.yml" |
            Should -BeTrue
    }

    It "references the aggregator script" {
        $script:wfContent | Should -Match "Invoke-TestResultAggregator\.ps1"
    }

    It "references fixtures directory" {
        $script:wfContent | Should -Match "fixtures"
    }

    It "has push trigger" {
        $script:wfContent | Should -Match "push:"
    }

    It "has workflow_dispatch trigger" {
        $script:wfContent | Should -Match "workflow_dispatch:"
    }

    It "uses actions/checkout@v4" {
        $script:wfContent | Should -Match "actions/checkout@v4"
    }

    It "uses shell: pwsh on run steps" {
        $script:wfContent | Should -Match "shell: pwsh"
    }

    It "passes actionlint validation" {
        $wfPath = "$PSScriptRoot/.github/workflows/test-results-aggregator.yml"
        $result = & actionlint $wfPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $result"
    }

    It "referenced script file exists on disk" {
        Test-Path "$PSScriptRoot/Invoke-TestResultAggregator.ps1" | Should -BeTrue
    }

    It "fixtures directory exists on disk" {
        Test-Path "$PSScriptRoot/fixtures" | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# RED 8: Act execution (integration test — writes act-result.txt)
# Tag: act-integration — excluded from runs inside the act container itself
# ---------------------------------------------------------------------------
Describe "Act Workflow Execution" -Tag "act-integration" {
    BeforeAll {
        $workDir = $PSScriptRoot
        $actResult = "$workDir/act-result.txt"

        # Initialise a minimal git repo in a temp dir and copy project files
        $tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-aggregator-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmpRepo | Out-Null

        # Copy project files
        Copy-Item "$workDir/Invoke-TestResultAggregator.ps1"       $tmpRepo
        Copy-Item "$workDir/Invoke-TestResultAggregator.Tests.ps1"  $tmpRepo
        Copy-Item "$workDir/fixtures" $tmpRepo -Recurse
        New-Item -ItemType Directory -Path "$tmpRepo/.github/workflows" -Force | Out-Null
        Copy-Item "$workDir/.github/workflows/test-results-aggregator.yml" `
                  "$tmpRepo/.github/workflows/"

        # Copy .actrc so act uses the custom image
        if (Test-Path "$workDir/.actrc") {
            Copy-Item "$workDir/.actrc" $tmpRepo
        }

        Push-Location $tmpRepo
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test"
        git add -A
        git commit -q -m "test"

        # Run act — limit to 3 total runs across all tests.
        # --pull=false: use local image without trying to pull from registry
        $actOutput = act push --rm --pull=false 2>&1 | Out-String
        $script:actExitCode = $LASTEXITCODE
        $script:actOutput   = $actOutput

        Pop-Location
        Remove-Item $tmpRepo -Recurse -Force -ErrorAction SilentlyContinue

        # Append this run's output to act-result.txt
        $delimiter = "`n" + ("=" * 60) + "`nACT RUN: test-results-aggregator`n" + ("=" * 60) + "`n"
        Add-Content -Path $actResult -Value ($delimiter + $actOutput)
    }

    It "act exits with code 0" {
        $script:actExitCode | Should -Be 0 -Because $script:actOutput
    }

    It "workflow job shows succeeded" {
        $script:actOutput | Should -Match "Job succeeded"
    }

    It "output contains exact passed count 12" {
        $script:actOutput | Should -Match "AGGREGATOR_RESULT_PASSED=12"
    }

    It "output contains exact failed count 3" {
        $script:actOutput | Should -Match "AGGREGATOR_RESULT_FAILED=3"
    }

    It "output contains exact skipped count 1" {
        $script:actOutput | Should -Match "AGGREGATOR_RESULT_SKIPPED=1"
    }

    It "output contains exact flaky count 3" {
        $script:actOutput | Should -Match "AGGREGATOR_RESULT_FLAKY=3"
    }

    It "output contains exact total count 16" {
        $script:actOutput | Should -Match "AGGREGATOR_RESULT_TOTAL=16"
    }

    It "act-result.txt artifact was created" {
        Test-Path "$PSScriptRoot/act-result.txt" | Should -BeTrue
    }
}
