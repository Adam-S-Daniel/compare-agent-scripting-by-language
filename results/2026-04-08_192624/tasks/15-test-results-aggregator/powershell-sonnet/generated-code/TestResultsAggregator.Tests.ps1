# TestResultsAggregator.Tests.ps1
#
# Red/Green TDD test suite for the Test Results Aggregator.
#
# TDD sequence followed:
#   Iteration 1 → Parse-JUnitXml      (red first, then green in implementation)
#   Iteration 2 → Parse-JsonResults   (red first, then green)
#   Iteration 3 → Parse-TestResultFile dispatcher
#   Iteration 4 → Aggregate-TestResults
#   Iteration 5 → Find-FlakyTests
#   Iteration 6 → New-MarkdownSummary
#   Iteration 7 → Invoke-TestResultsAggregator (integration)
#   Iteration 8 → Workflow structure tests (actionlint, paths)
#   Iteration 9 → Act-based integration tests (runs act for each test case)
#
# All tests are runnable with:  Invoke-Pester ./TestResultsAggregator.Tests.ps1

#region ── Shared setup ──────────────────────────────────────────────────────

BeforeAll {
    # Source the implementation – functions become available in this scope
    . "$PSScriptRoot/Invoke-TestResultsAggregator.ps1"

    # ── Helper: strip ANSI escape sequences from act output ──────────────────
    function Remove-AnsiCodes {
        param([string]$Text)
        return $Text -replace '\x1b\[[0-9;]*[mKJHF]', ''
    }

    # ── Helper: run one act test case and return result ───────────────────────
    # For each test case we:
    #   1. Create an isolated temp git repo
    #   2. Copy the project files + the case-specific fixtures into it
    #   3. Run `act push --rm` and capture output
    #   4. Append clearly-delimited output to act-result.txt
    #   5. Return @{ ExitCode; Output } for test assertions
    function Invoke-ActTestCase {
        param(
            [string]$TestCaseName,
            [string]$FixturesDir,
            [string]$ActResultPath
        )

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-tc-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        try {
            # ── Init bare git repo ────────────────────────────────────────────
            & git -C $tempDir init --quiet
            & git -C $tempDir config user.email 'ci@test.local'
            & git -C $tempDir config user.name  'CI Test'

            # ── Copy project files ────────────────────────────────────────────
            Copy-Item "$PSScriptRoot/Invoke-TestResultsAggregator.ps1" $tempDir
            Copy-Item "$PSScriptRoot/.github" $tempDir -Recurse

            # ── Copy test-case-specific fixtures to ./fixtures/ ───────────────
            $destFixtures = Join-Path $tempDir 'fixtures'
            New-Item -ItemType Directory -Path $destFixtures | Out-Null
            Copy-Item (Join-Path $FixturesDir '*') $destFixtures

            # ── Commit so git/act is happy ────────────────────────────────────
            & git -C $tempDir add -A
            & git -C $tempDir commit -m "test: $TestCaseName" --quiet

            # ── Run act ───────────────────────────────────────────────────────
            Push-Location $tempDir
            try {
                $actOutput = & act push --rm `
                    -P 'ubuntu-latest=catthehacker/ubuntu:act-latest' `
                    --pull=false `
                    2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            $rawOutput   = $actOutput -join "`n"
            $cleanOutput = Remove-AnsiCodes -Text $rawOutput

            # ── Append to act-result.txt ──────────────────────────────────────
            $sep = '=' * 70
            $block = @"
$sep
TEST CASE: $TestCaseName
$sep
$cleanOutput
$sep

"@
            Add-Content -Path $ActResultPath -Value $block -Encoding utf8

            return @{
                ExitCode = $exitCode
                Output   = $cleanOutput
            }

        } finally {
            # Clean up temp dir even on failure
            if (Test-Path $tempDir) {
                Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 1 (RED → GREEN): Parse-JUnitXml
# These tests were written FIRST; Parse-JUnitXml was then implemented.
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Parse-JUnitXml' {

    Context 'Basic JUnit XML with mixed results' {
        BeforeAll {
            $script:r1 = Parse-JUnitXml -Path "$PSScriptRoot/fixtures/junit-basic.xml"
        }

        It 'Returns correct total count' {
            $r1.Total | Should -Be 4
        }

        It 'Returns correct passed count' {
            $r1.Passed | Should -Be 2
        }

        It 'Returns correct failed count' {
            $r1.Failed | Should -Be 1
        }

        It 'Returns correct skipped count' {
            $r1.Skipped | Should -Be 1
        }

        It 'Returns correct total duration (sum of individual times)' {
            $r1.Duration | Should -Be 1.0
        }

        It 'Returns Tests array with one entry per testcase' {
            $r1.Tests.Count | Should -Be 4
        }

        It 'First test has correct name and status' {
            $r1.Tests[0].Name   | Should -Be 'test_addition'
            $r1.Tests[0].Status | Should -Be 'passed'
        }

        It 'Failed test has status "failed"' {
            $failed = $r1.Tests | Where-Object { $_.Status -eq 'failed' }
            $failed.Name | Should -Be 'test_multiplication'
        }

        It 'Skipped test has status "skipped"' {
            $skipped = $r1.Tests | Where-Object { $_.Status -eq 'skipped' }
            $skipped.Name | Should -Be 'test_division'
        }

        It 'Sets Source to the file path' {
            $r1.Source | Should -Match 'junit-basic\.xml'
        }
    }

    Context 'Error handling' {
        It 'Throws for a missing file' {
            { Parse-JUnitXml -Path 'nonexistent-file.xml' } | Should -Throw
        }

        It 'Throws for invalid XML content' {
            $tmp = [System.IO.Path]::GetTempFileName() + '.xml'
            Set-Content $tmp -Value 'this is not xml'
            try {
                { Parse-JUnitXml -Path $tmp } | Should -Throw
            } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 2 (RED → GREEN): Parse-JsonResults
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Parse-JsonResults' {

    Context 'JSON file with all passing tests' {
        BeforeAll {
            $script:r2 = Parse-JsonResults -Path "$PSScriptRoot/fixtures/json-results.json"
        }

        It 'Returns correct total count' {
            $r2.Total | Should -Be 3
        }

        It 'Returns correct passed count' {
            $r2.Passed | Should -Be 3
        }

        It 'Returns zero failures' {
            $r2.Failed | Should -Be 0
        }

        It 'Returns zero skipped' {
            $r2.Skipped | Should -Be 0
        }

        It 'Returns correct total duration' {
            $r2.Duration | Should -Be 1.0
        }

        It 'Returns Tests array with correct entries' {
            $r2.Tests.Count | Should -Be 3
            $r2.Tests[0].Name | Should -Be 'test_get_users'
        }
    }

    Context 'Error handling' {
        It 'Throws for a missing file' {
            { Parse-JsonResults -Path 'missing.json' } | Should -Throw
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 3 (RED → GREEN): Parse-TestResultFile dispatcher
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Parse-TestResultFile' {

    It 'Dispatches .xml files to Parse-JUnitXml' {
        $r = Parse-TestResultFile -Path "$PSScriptRoot/fixtures/junit-basic.xml"
        $r.Total | Should -Be 4
    }

    It 'Dispatches .json files to Parse-JsonResults' {
        $r = Parse-TestResultFile -Path "$PSScriptRoot/fixtures/json-results.json"
        $r.Total | Should -Be 3
    }

    It 'Throws for unsupported file extension' {
        { Parse-TestResultFile -Path 'results.csv' } | Should -Throw -ExpectedMessage '*Unsupported*'
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 4 (RED → GREEN): Aggregate-TestResults
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Aggregate-TestResults' {

    It 'Sums totals correctly across two result sets' {
        $results = @(
            @{ Passed=2; Failed=1; Skipped=1; Duration=1.0; Tests=@() }
            @{ Passed=3; Failed=0; Skipped=0; Duration=1.5; Tests=@() }
        )
        $agg = Aggregate-TestResults -Results $results
        $agg.Passed   | Should -Be 5
        $agg.Failed   | Should -Be 1
        $agg.Skipped  | Should -Be 1
        $agg.Total    | Should -Be 7
        $agg.Duration | Should -Be 2.5
    }

    It 'Returns zero totals for empty input' {
        $agg = Aggregate-TestResults -Results @()
        $agg.Total   | Should -Be 0
        $agg.Passed  | Should -Be 0
        $agg.Failed  | Should -Be 0
        $agg.Skipped | Should -Be 0
    }

    It 'Collects all individual test entries' {
        $t1 = @{ Name='a'; Status='passed'; Duration=0.1; Suite='S' }
        $t2 = @{ Name='b'; Status='failed'; Duration=0.2; Suite='S' }
        $results = @(
            @{ Passed=1; Failed=0; Skipped=0; Duration=0.1; Tests=@($t1) }
            @{ Passed=0; Failed=1; Skipped=0; Duration=0.2; Tests=@($t2) }
        )
        $agg = Aggregate-TestResults -Results $results
        $agg.Tests.Count | Should -Be 2
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 5 (RED → GREEN): Find-FlakyTests
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Find-FlakyTests' {

    It 'Identifies tests that both passed and failed across runs' {
        $results = @(
            @{ Tests = @(
                @{ Name='alpha'; Status='passed'  }
                @{ Name='beta';  Status='failed'  }
            ) }
            @{ Tests = @(
                @{ Name='alpha'; Status='failed'  }
                @{ Name='beta';  Status='passed'  }
            ) }
        )
        $flaky = Find-FlakyTests -Results $results
        $flaky.Count      | Should -Be 2
        ($flaky.Name) | Should -Contain 'alpha'
        ($flaky.Name) | Should -Contain 'beta'
    }

    It 'Does not mark consistently passing tests as flaky' {
        $results = @(
            @{ Tests = @(@{ Name='stable'; Status='passed' }) }
            @{ Tests = @(@{ Name='stable'; Status='passed' }) }
        )
        $flaky = Find-FlakyTests -Results $results
        $flaky.Count | Should -Be 0
    }

    It 'Does not mark consistently failing tests as flaky' {
        $results = @(
            @{ Tests = @(@{ Name='broken'; Status='failed' }) }
            @{ Tests = @(@{ Name='broken'; Status='failed' }) }
        )
        $flaky = Find-FlakyTests -Results $results
        $flaky.Count | Should -Be 0
    }

    It 'Calculates PassRate correctly' {
        $results = @(
            @{ Tests = @(@{ Name='x'; Status='passed' }) }
            @{ Tests = @(@{ Name='x'; Status='passed' }) }
            @{ Tests = @(@{ Name='x'; Status='failed' }) }
        )
        $flaky = Find-FlakyTests -Results $results
        $flaky[0].PassRate | Should -Be 67
    }

    It 'Returns empty array for empty input' {
        $flaky = Find-FlakyTests -Results @()
        $flaky.Count | Should -Be 0
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 6 (RED → GREEN): New-MarkdownSummary
# ═══════════════════════════════════════════════════════════════════════════
Describe 'New-MarkdownSummary' {

    BeforeAll {
        $script:aggPass = @{ Total=3; Passed=3; Failed=0; Skipped=0; Duration=1.0 }
        $script:aggFail = @{ Total=4; Passed=2; Failed=1; Skipped=1; Duration=1.5 }
    }

    It 'Contains the h1 header' {
        $md = New-MarkdownSummary -Aggregated $aggPass -FlakyTests @() -Results @()
        $md | Should -Match '# Test Results Summary'
    }

    It 'Contains total test count in overview table' {
        $md = New-MarkdownSummary -Aggregated $aggFail -FlakyTests @() -Results @()
        $md | Should -Match '\| Total Tests \| 4 \|'
    }

    It 'Contains passed count in overview table' {
        $md = New-MarkdownSummary -Aggregated $aggFail -FlakyTests @() -Results @()
        $md | Should -Match '\| Passed \| 2 \|'
    }

    It 'Contains failed count in overview table' {
        $md = New-MarkdownSummary -Aggregated $aggFail -FlakyTests @() -Results @()
        $md | Should -Match '\| Failed \| 1 \|'
    }

    It 'Shows PASSED status when no failures' {
        $md = New-MarkdownSummary -Aggregated $aggPass -FlakyTests @() -Results @()
        $md | Should -Match 'Status: PASSED'
    }

    It 'Shows FAILED status when failures exist' {
        $md = New-MarkdownSummary -Aggregated $aggFail -FlakyTests @() -Results @()
        $md | Should -Match 'Status: FAILED'
    }

    It 'Includes Flaky Tests section when flaky tests present' {
        $flaky = @([pscustomobject]@{ Name='wobble'; PassRate=50; Passed=1; Failed=1 })
        $md = New-MarkdownSummary -Aggregated $aggFail -FlakyTests $flaky -Results @()
        $md | Should -Match 'Flaky Tests'
        $md | Should -Match 'wobble'
    }

    It 'Omits Flaky Tests section when no flaky tests' {
        $md = New-MarkdownSummary -Aggregated $aggPass -FlakyTests @() -Results @()
        $md | Should -Not -Match 'Flaky Tests'
    }

    It 'Includes Files Processed table when results provided' {
        $fakeResult = @{ Source = '/tmp/my-results.xml'; Passed=3; Failed=0; Skipped=0; Duration=1.0 }
        $md = New-MarkdownSummary -Aggregated $aggPass -FlakyTests @() -Results @($fakeResult)
        $md | Should -Match 'Files Processed'
        $md | Should -Match 'my-results\.xml'
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 7 (RED → GREEN): Invoke-TestResultsAggregator (integration)
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Invoke-TestResultsAggregator' {

    It 'Throws when Path does not exist' {
        { Invoke-TestResultsAggregator -Path '/no/such/path' } | Should -Throw
    }

    It 'Throws when directory has no supported files' {
        $empty = Join-Path ([System.IO.Path]::GetTempPath()) "empty-$(Get-Random)"
        New-Item -ItemType Directory $empty | Out-Null
        try {
            { Invoke-TestResultsAggregator -Path $empty } | Should -Throw
        } finally { Remove-Item $empty -Recurse -Force }
    }

    It 'Returns aggregated results from a JUnit XML file' {
        $result = Invoke-TestResultsAggregator -Path "$PSScriptRoot/fixtures"
        $result.Aggregated.Total | Should -BeGreaterThan 0
    }

    It 'Returns a non-empty Markdown string' {
        $result = Invoke-TestResultsAggregator -Path "$PSScriptRoot/fixtures"
        $result.Markdown | Should -Not -BeNullOrEmpty
        $result.Markdown | Should -Match '# Test Results Summary'
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 8: Workflow structure tests
# These verify the workflow file exists, has the right shape, and passes lint.
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Workflow Structure' {

    BeforeAll {
        $script:wfPath    = "$PSScriptRoot/.github/workflows/test-results-aggregator.yml"
        $script:wfContent = if (Test-Path $wfPath) { Get-Content $wfPath -Raw } else { '' }
    }

    It 'Workflow file exists at .github/workflows/test-results-aggregator.yml' {
        Test-Path $wfPath | Should -BeTrue
    }

    It 'Has a push trigger' {
        $wfContent | Should -Match 'push:'
    }

    It 'Has a workflow_dispatch trigger' {
        $wfContent | Should -Match 'workflow_dispatch:'
    }

    It 'References Invoke-TestResultsAggregator' {
        $wfContent | Should -Match 'Invoke-TestResultsAggregator'
    }

    It 'Uses actions/checkout@v4' {
        $wfContent | Should -Match 'actions/checkout@v4'
    }

    It 'Has a job that installs PowerShell' {
        $wfContent | Should -Match 'powershell'
    }

    It 'Implementation script exists' {
        Test-Path "$PSScriptRoot/Invoke-TestResultsAggregator.ps1" | Should -BeTrue
    }

    It 'actionlint passes with exit code 0' {
        $lintOut = & actionlint $wfPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $lintOut"
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# TDD ITERATION 9: Act-based integration tests
#
# Each test case:
#   1. Sets up a temp git repo with our project files + scenario fixtures
#   2. Runs `act push --rm` (Docker)
#   3. Asserts on EXACT EXPECTED VALUES in the captured output
#   4. Appends output to act-result.txt
# ═══════════════════════════════════════════════════════════════════════════
Describe 'Act Integration Tests' -Tag 'Act' {

    BeforeAll {
        # Initialise (overwrite) act-result.txt at the start of the act suite
        $script:actResultPath = "$PSScriptRoot/act-result.txt"
        Set-Content -Path $actResultPath -Value "# act Test Results`nGenerated: $(Get-Date -Format o)`n" -Encoding utf8
    }

    # ── Test Case 1: Basic JUnit XML ─────────────────────────────────────────
    Context 'TC1 – JUnit XML (2 passed, 1 failed, 1 skipped)' {
        BeforeAll {
            $script:tc1 = Invoke-ActTestCase `
                -TestCaseName  'TC1-BasicJUnitXML' `
                -FixturesDir   "$PSScriptRoot/test-fixtures/tc1" `
                -ActResultPath $actResultPath
        }

        It 'act exits with code 0' {
            $tc1.ExitCode | Should -Be 0
        }

        It 'Job succeeded appears in output' {
            $tc1.Output | Should -Match 'Job succeeded'
        }

        It 'Output contains exact Total Tests count: 4' {
            $tc1.Output | Should -Match 'Total Tests \| 4'
        }

        It 'Output contains exact Passed count: 2' {
            $tc1.Output | Should -Match 'Passed \| 2'
        }

        It 'Output contains exact Failed count: 1' {
            $tc1.Output | Should -Match 'Failed \| 1'
        }

        It 'Output contains exact Skipped count: 1' {
            $tc1.Output | Should -Match 'Skipped \| 1'
        }

        It 'Output shows FAILED status (because there is 1 failure)' {
            $tc1.Output | Should -Match 'Status: FAILED'
        }
    }

    # ── Test Case 2: JSON format (3 passing) ─────────────────────────────────
    Context 'TC2 – JSON results (3 passed, 0 failed)' {
        BeforeAll {
            $script:tc2 = Invoke-ActTestCase `
                -TestCaseName  'TC2-JSONFormat' `
                -FixturesDir   "$PSScriptRoot/test-fixtures/tc2" `
                -ActResultPath $actResultPath
        }

        It 'act exits with code 0' {
            $tc2.ExitCode | Should -Be 0
        }

        It 'Job succeeded appears in output' {
            $tc2.Output | Should -Match 'Job succeeded'
        }

        It 'Output contains exact Total Tests count: 3' {
            $tc2.Output | Should -Match 'Total Tests \| 3'
        }

        It 'Output contains exact Passed count: 3' {
            $tc2.Output | Should -Match 'Passed \| 3'
        }

        It 'Output shows PASSED status (no failures)' {
            $tc2.Output | Should -Match 'Status: PASSED'
        }
    }

    # ── Test Case 3: Flaky test detection (two XML files) ────────────────────
    Context 'TC3 – Flaky tests (test_network and test_timeout are flaky)' {
        BeforeAll {
            $script:tc3 = Invoke-ActTestCase `
                -TestCaseName  'TC3-FlakyTests' `
                -FixturesDir   "$PSScriptRoot/test-fixtures/tc3" `
                -ActResultPath $actResultPath
        }

        It 'act exits with code 0' {
            $tc3.ExitCode | Should -Be 0
        }

        It 'Job succeeded appears in output' {
            $tc3.Output | Should -Match 'Job succeeded'
        }

        It 'Output includes Flaky Tests section' {
            $tc3.Output | Should -Match 'Flaky Tests'
        }

        It 'test_network identified as flaky' {
            $tc3.Output | Should -Match 'test_network'
        }

        It 'test_timeout identified as flaky' {
            $tc3.Output | Should -Match 'test_timeout'
        }

        It 'Output shows FAILED status (failures exist across runs)' {
            $tc3.Output | Should -Match 'Status: FAILED'
        }
    }
}
