# ============================================================
# TestResultsAggregator.Tests.ps1
#
# TDD Approach:
#   RED   -> Write this test file first; all tests fail because
#             the module does not exist yet.
#   GREEN -> Create TestResultsAggregator.psm1 with just enough
#             code to make every test pass.
#   REFACTOR -> Tidy internals without breaking tests.
#
# Expected fixture data (all four runs combined):
#   Total tests  : 16  (5 + 5 + 3 + 3)
#   Passed       : 10
#   Failed       :  4
#   Skipped      :  2
#   Flaky tests  :  4
#     MyApp.FeatureA.test_connection  (fail run1, pass run2)
#     MyApp.FeatureB.test_timeout     (pass run1, fail run2)
#     MyApp.Setup.test_config         (pass run3, fail run4)
#     MyApp.Setup.test_uninstall      (fail run3, pass run4)
# ============================================================

# ── File-level setup ──────────────────────────────────────────
# NOTE: Set-StrictMode is placed inside BeforeAll, not at file scope,
#       because Pester runs the file during discovery and top-level
#       Set-StrictMode interferes with that phase.
BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    [string]$script:ModulePath    = Join-Path $PSScriptRoot 'TestResultsAggregator.psm1'
    Import-Module $script:ModulePath -Force

    [string]$script:FixturesDir   = Join-Path $PSScriptRoot 'fixtures'
    [string]$script:JUnitRun1     = Join-Path $script:FixturesDir 'junit-run1.xml'
    [string]$script:JUnitRun2     = Join-Path $script:FixturesDir 'junit-run2.xml'
    [string]$script:JsonRun3      = Join-Path $script:FixturesDir 'json-run3.json'
    [string]$script:JsonRun4      = Join-Path $script:FixturesDir 'json-run4.json'
}

# ══════════════════════════════════════════════════════════════
# TDD CYCLE 1: ConvertFrom-JUnitXml
# RED  -> Tests fail because function does not exist yet.
# GREEN-> Implement XML parser to make these pass.
# ══════════════════════════════════════════════════════════════
Describe 'ConvertFrom-JUnitXml' {

    Context 'Error handling' {
        It 'throws a meaningful error when the file does not exist' {
            { ConvertFrom-JUnitXml -FilePath 'nonexistent.xml' } |
                Should -Throw "*not found*"
        }
    }

    Context 'Parsing junit-run1.xml (3 passed, 1 failed, 1 skipped)' {
        BeforeAll {
            $script:run1 = ConvertFrom-JUnitXml -FilePath $script:JUnitRun1 -RunId 'run1'
        }

        It 'returns a non-null object' {
            $script:run1 | Should -Not -BeNullOrEmpty
        }

        It 'stores the supplied RunId' {
            $script:run1.RunId | Should -Be 'run1'
        }

        It 'reports format as junit-xml' {
            $script:run1.Format | Should -Be 'junit-xml'
        }

        It 'counts total tests correctly' {
            $script:run1.Total | Should -Be 5
        }

        It 'counts passed tests correctly' {
            $script:run1.Passed | Should -Be 3
        }

        It 'counts failed tests correctly' {
            $script:run1.Failed | Should -Be 1
        }

        It 'counts skipped tests correctly' {
            $script:run1.Skipped | Should -Be 1
        }

        It 'calculates a positive total duration' {
            $script:run1.Duration | Should -BeGreaterThan 0
        }

        It 'marks test_connection as failed' {
            [PSCustomObject]$failed = $script:run1.Tests |
                Where-Object { [string]$_.Name -eq 'test_connection' }
            $failed | Should -Not -BeNullOrEmpty
            [string]$failed.Status | Should -Be 'failed'
        }

        It 'captures the failure message for test_connection' {
            [PSCustomObject]$failed = $script:run1.Tests |
                Where-Object { [string]$_.Name -eq 'test_connection' }
            [string]$failed.Message | Should -Not -BeNullOrEmpty
        }

        It 'marks test_retry as skipped' {
            [PSCustomObject]$skipped = $script:run1.Tests |
                Where-Object { [string]$_.Name -eq 'test_retry' }
            $skipped | Should -Not -BeNullOrEmpty
            [string]$skipped.Status | Should -Be 'skipped'
        }

        It 'builds FullName as ClassName.Name' {
            [PSCustomObject]$t = $script:run1.Tests |
                Where-Object { [string]$_.Name -eq 'test_login' }
            [string]$t.FullName | Should -Be 'MyApp.FeatureA.test_login'
        }

        It 'propagates RunId into each test case' {
            [PSCustomObject]$t = $script:run1.Tests | Select-Object -First 1
            [string]$t.RunId | Should -Be 'run1'
        }
    }

    Context 'Parsing junit-run2.xml (test_connection now passes, test_timeout now fails)' {
        BeforeAll {
            $script:run2 = ConvertFrom-JUnitXml -FilePath $script:JUnitRun2 -RunId 'run2'
        }

        It 'marks test_connection as passed' {
            [PSCustomObject]$t = $script:run2.Tests |
                Where-Object { [string]$_.Name -eq 'test_connection' }
            [string]$t.Status | Should -Be 'passed'
        }

        It 'marks test_timeout as failed' {
            [PSCustomObject]$t = $script:run2.Tests |
                Where-Object { [string]$_.Name -eq 'test_timeout' }
            [string]$t.Status | Should -Be 'failed'
        }
    }

    Context 'RunId defaults to filename when not supplied' {
        BeforeAll {
            $script:run1NoId = ConvertFrom-JUnitXml -FilePath $script:JUnitRun1
        }

        It 'uses the file name without extension as RunId' {
            $script:run1NoId.RunId | Should -Be 'junit-run1'
        }
    }
}

# ══════════════════════════════════════════════════════════════
# TDD CYCLE 2: ConvertFrom-JsonTestResults
# ══════════════════════════════════════════════════════════════
Describe 'ConvertFrom-JsonTestResults' {

    Context 'Error handling' {
        It 'throws a meaningful error when the file does not exist' {
            { ConvertFrom-JsonTestResults -FilePath 'nonexistent.json' } |
                Should -Throw "*not found*"
        }
    }

    Context 'Parsing json-run3.json (2 passed, 1 failed)' {
        BeforeAll {
            $script:run3 = ConvertFrom-JsonTestResults -FilePath $script:JsonRun3
        }

        It 'returns a non-null object' {
            $script:run3 | Should -Not -BeNullOrEmpty
        }

        It 'reads runId from the JSON file' {
            $script:run3.RunId | Should -Be 'Matrix-Windows-Node18'
        }

        It 'reports format as json' {
            $script:run3.Format | Should -Be 'json'
        }

        It 'counts total tests correctly' {
            $script:run3.Total | Should -Be 3
        }

        It 'counts passed tests correctly' {
            $script:run3.Passed | Should -Be 2
        }

        It 'counts failed tests correctly' {
            $script:run3.Failed | Should -Be 1
        }

        It 'counts skipped tests correctly' {
            $script:run3.Skipped | Should -Be 0
        }

        It 'marks test_uninstall as failed with a message' {
            [PSCustomObject]$t = $script:run3.Tests |
                Where-Object { [string]$_.Name -eq 'test_uninstall' }
            [string]$t.Status  | Should -Be 'failed'
            [string]$t.Message | Should -Not -BeNullOrEmpty
        }

        It 'builds FullName correctly' {
            [PSCustomObject]$t = $script:run3.Tests |
                Where-Object { [string]$_.Name -eq 'test_install' }
            [string]$t.FullName | Should -Be 'MyApp.Setup.test_install'
        }
    }

    Context 'Parsing json-run4.json (test_config fails, test_uninstall passes)' {
        BeforeAll {
            $script:run4 = ConvertFrom-JsonTestResults -FilePath $script:JsonRun4
        }

        It 'marks test_config as failed' {
            [PSCustomObject]$t = $script:run4.Tests |
                Where-Object { [string]$_.Name -eq 'test_config' }
            [string]$t.Status | Should -Be 'failed'
        }

        It 'marks test_uninstall as passed' {
            [PSCustomObject]$t = $script:run4.Tests |
                Where-Object { [string]$_.Name -eq 'test_uninstall' }
            [string]$t.Status | Should -Be 'passed'
        }
    }

    Context 'RunId override via parameter' {
        BeforeAll {
            $script:run3Override = ConvertFrom-JsonTestResults -FilePath $script:JsonRun3 -RunId 'override-id'
        }

        It 'uses the supplied RunId over the one in the file' {
            $script:run3Override.RunId | Should -Be 'override-id'
        }
    }
}

# ══════════════════════════════════════════════════════════════
# TDD CYCLE 3: Merge-TestRuns
# ══════════════════════════════════════════════════════════════
Describe 'Merge-TestRuns' {

    BeforeAll {
        [PSCustomObject[]]$script:allRuns = @(
            (ConvertFrom-JUnitXml          -FilePath $script:JUnitRun1 -RunId 'run1')
            (ConvertFrom-JUnitXml          -FilePath $script:JUnitRun2 -RunId 'run2')
            (ConvertFrom-JsonTestResults   -FilePath $script:JsonRun3)
            (ConvertFrom-JsonTestResults   -FilePath $script:JsonRun4)
        )
        $script:merged = Merge-TestRuns -TestRuns $script:allRuns
    }

    It 'returns a non-null result object' {
        $script:merged | Should -Not -BeNullOrEmpty
    }

    It 'reports correct total test count (5+5+3+3=16)' {
        $script:merged.TotalTests | Should -Be 16
    }

    It 'reports correct total passed count (3+3+2+2=10)' {
        $script:merged.TotalPassed | Should -Be 10
    }

    It 'reports correct total failed count (1+1+1+1=4)' {
        $script:merged.TotalFailed | Should -Be 4
    }

    It 'reports correct total skipped count (1+1+0+0=2)' {
        $script:merged.TotalSkipped | Should -Be 2
    }

    It 'has a positive total duration' {
        $script:merged.TotalDuration | Should -BeGreaterThan 0
    }

    It 'reports correct run count' {
        $script:merged.RunCount | Should -Be 4
    }

    It 'includes all individual runs' {
        $script:merged.Runs.Count | Should -Be 4
    }

    It 'collects all individual test cases into AllTests' {
        $script:merged.AllTests.Count | Should -Be 16
    }

    It 'handles an empty runs array without error' {
        [PSCustomObject]$empty = Merge-TestRuns -TestRuns @()
        $empty.TotalTests | Should -Be 0
    }
}

# ══════════════════════════════════════════════════════════════
# TDD CYCLE 4: Find-FlakyTests
# ══════════════════════════════════════════════════════════════
Describe 'Find-FlakyTests' {

    Context 'When all tests are consistent across runs' {
        BeforeAll {
            # Pass the same run twice — every test result is identical, so nothing is flaky
            [PSCustomObject]$sameRun = ConvertFrom-JUnitXml -FilePath $script:JUnitRun1 -RunId 'r'
            $script:noFlaky = @(Find-FlakyTests -TestRuns @($sameRun, $sameRun))
        }

        It 'returns zero flaky tests' {
            $script:noFlaky.Count | Should -Be 0
        }
    }

    Context 'When four fixture runs contain four flaky tests' {
        BeforeAll {
            [PSCustomObject[]]$runs = @(
                (ConvertFrom-JUnitXml        -FilePath $script:JUnitRun1 -RunId 'run1')
                (ConvertFrom-JUnitXml        -FilePath $script:JUnitRun2 -RunId 'run2')
                (ConvertFrom-JsonTestResults -FilePath $script:JsonRun3)
                (ConvertFrom-JsonTestResults -FilePath $script:JsonRun4)
            )
            $script:flaky = @(Find-FlakyTests -TestRuns $runs)
        }

        It 'identifies exactly 4 flaky tests' {
            $script:flaky.Count | Should -Be 4
        }

        It 'flags MyApp.FeatureA.test_connection as flaky' {
            $script:flaky.FullName | Should -Contain 'MyApp.FeatureA.test_connection'
        }

        It 'flags MyApp.FeatureB.test_timeout as flaky' {
            $script:flaky.FullName | Should -Contain 'MyApp.FeatureB.test_timeout'
        }

        It 'flags MyApp.Setup.test_config as flaky' {
            $script:flaky.FullName | Should -Contain 'MyApp.Setup.test_config'
        }

        It 'flags MyApp.Setup.test_uninstall as flaky' {
            $script:flaky.FullName | Should -Contain 'MyApp.Setup.test_uninstall'
        }

        It 'includes PassCount and FailCount on each flaky entry' {
            [PSCustomObject]$conn = $script:flaky |
                Where-Object { [string]$_.FullName -eq 'MyApp.FeatureA.test_connection' }
            [int]$conn.PassCount | Should -Be 1
            [int]$conn.FailCount | Should -Be 1
        }

        It 'does NOT flag consistently-failing test_retry (always skipped)' {
            $script:flaky.FullName | Should -Not -Contain 'MyApp.FeatureB.test_retry'
        }

        It 'does NOT flag consistently-passing test_login' {
            $script:flaky.FullName | Should -Not -Contain 'MyApp.FeatureA.test_login'
        }
    }
}

# ══════════════════════════════════════════════════════════════
# TDD CYCLE 5: New-MarkdownSummary
# ══════════════════════════════════════════════════════════════
Describe 'New-MarkdownSummary' {

    BeforeAll {
        [PSCustomObject[]]$runs = @(
            (ConvertFrom-JUnitXml        -FilePath $script:JUnitRun1 -RunId 'run1')
            (ConvertFrom-JUnitXml        -FilePath $script:JUnitRun2 -RunId 'run2')
            (ConvertFrom-JsonTestResults -FilePath $script:JsonRun3)
            (ConvertFrom-JsonTestResults -FilePath $script:JsonRun4)
        )
        $script:mdAggregated = Merge-TestRuns -TestRuns $runs
        $script:mdFlaky      = @(Find-FlakyTests -TestRuns $runs)
        $script:md           = New-MarkdownSummary `
            -AggregatedResults $script:mdAggregated `
            -FlakyTests        $script:mdFlaky
    }

    It 'returns a string' {
        $script:md | Should -BeOfType [string]
    }

    It 'contains the top-level heading' {
        $script:md | Should -Match '## Test Results Summary'
    }

    It 'includes the total test count (16)' {
        $script:md | Should -Match '\b16\b'
    }

    It 'includes the total passed count (10)' {
        $script:md | Should -Match '\b10\b'
    }

    It 'contains a Results by Run section' {
        $script:md | Should -Match '### Results by Run'
    }

    It 'lists all four run IDs in the per-run table' {
        $script:md | Should -Match 'run1'
        $script:md | Should -Match 'run2'
        $script:md | Should -Match 'Matrix-Windows-Node18'
        $script:md | Should -Match 'Matrix-Windows-Node20'
    }

    It 'contains a Flaky Tests section' {
        $script:md | Should -Match '### Flaky Tests'
    }

    It 'names each flaky test in the markdown' {
        $script:md | Should -Match 'test_connection'
        $script:md | Should -Match 'test_timeout'
        $script:md | Should -Match 'test_config'
        $script:md | Should -Match 'test_uninstall'
    }

    Context 'When there are no flaky tests' {
        BeforeAll {
            [PSCustomObject]$oneRun      = ConvertFrom-JUnitXml -FilePath $script:JUnitRun1 -RunId 'r'
            [PSCustomObject]$oneAgg      = Merge-TestRuns -TestRuns @($oneRun)
            $script:mdNoFlaky            = New-MarkdownSummary `
                -AggregatedResults $oneAgg `
                -FlakyTests        @()
        }

        It 'states no flaky tests were detected' {
            $script:mdNoFlaky | Should -Match 'No flaky tests detected'
        }
    }
}

# ══════════════════════════════════════════════════════════════
# TDD CYCLE 6: Invoke-TestResultsAggregator (integration)
# ══════════════════════════════════════════════════════════════
Describe 'Invoke-TestResultsAggregator' {

    Context 'Aggregating all four fixture files' {
        BeforeAll {
            $script:integResult = Invoke-TestResultsAggregator -FilePaths @(
                $script:JUnitRun1
                $script:JUnitRun2
                $script:JsonRun3
                $script:JsonRun4
            )
        }

        It 'returns a non-null result object' {
            $script:integResult | Should -Not -BeNullOrEmpty
        }

        It 'exposes AggregatedResults' {
            $script:integResult.AggregatedResults | Should -Not -BeNullOrEmpty
        }

        It 'AggregatedResults has 16 total tests' {
            $script:integResult.AggregatedResults.TotalTests | Should -Be 16
        }

        It 'returns 4 flaky tests' {
            @($script:integResult.FlakyTests).Count | Should -Be 4
        }

        It 'returns empty markdown when -GenerateMarkdown is not specified' {
            $script:integResult.Markdown | Should -Be ''
        }
    }

    Context 'With -GenerateMarkdown switch' {
        BeforeAll {
            $script:integWithMd = Invoke-TestResultsAggregator `
                -FilePaths @($script:JUnitRun1, $script:JUnitRun2) `
                -GenerateMarkdown
        }

        It 'generates a non-empty markdown string' {
            $script:integWithMd.Markdown | Should -Not -BeNullOrEmpty
        }

        It 'markdown contains the summary heading' {
            $script:integWithMd.Markdown | Should -Match 'Test Results Summary'
        }
    }

    Context 'Error handling' {
        It 'throws for an unsupported file extension' {
            { Invoke-TestResultsAggregator -FilePaths @('test.txt') } |
                Should -Throw "*Unsupported*"
        }

        It 'throws with a meaningful message when an XML file is not found' {
            { Invoke-TestResultsAggregator -FilePaths @('missing.xml') } |
                Should -Throw "*not found*"
        }
    }
}
