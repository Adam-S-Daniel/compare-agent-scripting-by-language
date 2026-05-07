# Pester tests for Aggregate-TestResults (TDD - written before implementation)

BeforeAll {
    . $PSScriptRoot/Aggregate-TestResults.ps1
    $fixturesDir = Join-Path $PSScriptRoot 'fixtures'
}

Describe "Import-JUnitXml" {
    It "parses a valid JUnit XML file correctly" {
        $result = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $result.SuiteName | Should -Be "Unit Tests - Chrome"
        $result.TotalTests | Should -Be 5
        $result.Passed | Should -Be 3
        $result.Failed | Should -Be 1
        $result.Skipped | Should -Be 1
        $result.Duration | Should -Be 2.8
    }

    It "extracts individual test case details" {
        $result = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $result.TestCases.Count | Should -Be 5
        $login = $result.TestCases | Where-Object { $_.Name -eq 'TestLogin' }
        $login.ClassName | Should -Be 'AuthTests'
        $login.Duration | Should -Be 0.5
        $login.Status | Should -Be 'passed'
        $signup = $result.TestCases | Where-Object { $_.Name -eq 'TestSignup' }
        $signup.Status | Should -Be 'failed'
        $signup.ErrorMessage | Should -Be 'Email validation error'
    }

    It "throws on non-existent file" {
        { Import-JUnitXml -Path '/nonexistent/path.xml' } | Should -Throw "*not found*"
    }

    It "throws on invalid XML content" {
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "bad-$(Get-Random).xml"
        Set-Content -Path $tmp -Value "not valid xml <<<"
        try {
            { Import-JUnitXml -Path $tmp } | Should -Throw
        } finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
}

Describe "Import-JsonTestResults" {
    It "parses a valid JSON results file correctly" {
        $result = Import-JsonTestResults -Path (Join-Path $fixturesDir 'run3-results.json')
        $result.SuiteName | Should -Be "Unit Tests - Safari"
        $result.TotalTests | Should -Be 5
        $result.Passed | Should -Be 4
        $result.Failed | Should -Be 0
        $result.Skipped | Should -Be 1
        $result.Duration | Should -Be 2.8
    }

    It "extracts individual test case details" {
        $result = Import-JsonTestResults -Path (Join-Path $fixturesDir 'run3-results.json')
        $result.TestCases.Count | Should -Be 5
        $dashboard = $result.TestCases | Where-Object { $_.Name -eq 'TestDashboard' }
        $dashboard.ClassName | Should -Be 'UITests'
        $dashboard.Duration | Should -Be 0.9
        $dashboard.Status | Should -Be 'passed'
    }

    It "throws on non-existent file" {
        { Import-JsonTestResults -Path '/nonexistent/results.json' } | Should -Throw "*not found*"
    }
}

Describe "Merge-TestResults" {
    BeforeAll {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $r2 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run2-junit.xml')
        $r3 = Import-JsonTestResults -Path (Join-Path $fixturesDir 'run3-results.json')
        $script:merged = Merge-TestResults -Results @($r1, $r2, $r3)
    }

    It "computes correct aggregate totals" {
        $script:merged.TotalTests | Should -Be 15
        $script:merged.Passed | Should -Be 9
        $script:merged.Failed | Should -Be 3
        $script:merged.Skipped | Should -Be 3
        $script:merged.Duration | Should -Be 8.4
    }

    It "calculates correct pass rate" {
        $script:merged.PassRate | Should -Be 75.0
    }

    It "handles a single result set" {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $single = Merge-TestResults -Results @($r1)
        $single.TotalTests | Should -Be 5
        $single.Passed | Should -Be 3
        $single.Runs.Count | Should -Be 1
    }
}

Describe "Find-FlakyTests" {
    BeforeAll {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $r2 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run2-junit.xml')
        $r3 = Import-JsonTestResults -Path (Join-Path $fixturesDir 'run3-results.json')
        $script:flaky = Find-FlakyTests -Results @($r1, $r2, $r3)
    }

    It "identifies tests with mixed pass/fail results" {
        $script:flaky.Count | Should -Be 2
        $names = $script:flaky | ForEach-Object { $_.Name }
        $names | Should -Contain 'TestLogout'
        $names | Should -Contain 'TestSignup'
    }

    It "returns empty array when all tests are consistent" {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $consistent = Find-FlakyTests -Results @($r1)
        $consistent.Count | Should -Be 0
    }

    It "ignores skipped tests in flaky detection" {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $r2 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run2-junit.xml')
        $r3 = Import-JsonTestResults -Path (Join-Path $fixturesDir 'run3-results.json')
        $flaky = Find-FlakyTests -Results @($r1, $r2, $r3)
        $names = $flaky | ForEach-Object { $_.Name }
        $names | Should -Not -Contain 'TestSettings'
    }
}

Describe "New-MarkdownSummary" {
    BeforeAll {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $r2 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run2-junit.xml')
        $r3 = Import-JsonTestResults -Path (Join-Path $fixturesDir 'run3-results.json')
        $merged = Merge-TestResults -Results @($r1, $r2, $r3)
        $flaky = Find-FlakyTests -Results @($r1, $r2, $r3)
        $script:markdown = New-MarkdownSummary -MergedResults $merged -FlakyTests $flaky
    }

    It "includes correct totals table" {
        $script:markdown | Should -Match '\| Total Tests \| 15 \|'
        $script:markdown | Should -Match '\| Passed \| 9 \|'
        $script:markdown | Should -Match '\| Failed \| 3 \|'
        $script:markdown | Should -Match '\| Skipped \| 3 \|'
        $script:markdown | Should -Match '\| Duration \| 8\.40s \|'
        $script:markdown | Should -Match '\| Pass Rate \| 75\.0% \|'
    }

    It "includes flaky tests section when flaky tests exist" {
        $script:markdown | Should -Match 'Flaky Tests'
        $script:markdown | Should -Match 'TestLogout'
        $script:markdown | Should -Match 'TestSignup'
    }

    It "omits flaky section when no flaky tests" {
        $r1 = Import-JUnitXml -Path (Join-Path $fixturesDir 'run1-junit.xml')
        $merged = Merge-TestResults -Results @($r1)
        $noFlaky = Find-FlakyTests -Results @($r1)
        $md = New-MarkdownSummary -MergedResults $merged -FlakyTests $noFlaky
        $md | Should -Not -Match 'Flaky Tests'
    }

    It "includes per-run breakdown" {
        $script:markdown | Should -Match 'Unit Tests - Chrome'
        $script:markdown | Should -Match 'Unit Tests - Firefox'
        $script:markdown | Should -Match 'Unit Tests - Safari'
    }

    It "includes failed tests section" {
        $script:markdown | Should -Match 'Failed Tests'
        $script:markdown | Should -Match 'Email validation error'
        $script:markdown | Should -Match 'Session timeout'
    }
}
