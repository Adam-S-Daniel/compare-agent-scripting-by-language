#requires -Version 7.0
#requires -Modules @{ModuleName='Pester'; ModuleVersion='5.0.0'}

# Integration tests that exercise the aggregator end-to-end through the
# GitHub Actions workflow via `act`. Per the task spec, no direct unit
# tests of the script — every assertion is on output produced by act.
#
# Each Context block:
#   1. Builds a temp git repo containing the project files + a fixture set
#   2. Runs `act push --rm` once
#   3. Appends the output (delimited) to act-result.txt at the repo root
#   4. Asserts exit code 0, "Job succeeded", and exact expected values
#      derived from the known-good outcome of that fixture set.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:ActResultFile = Join-Path $script:RepoRoot "act-result.txt"

    # Truncate act-result.txt at the start of the test session so each
    # `Invoke-Pester` run produces a fresh artifact.
    Set-Content -Path $script:ActResultFile -Value ""

    function Invoke-ActWithFixtures {
        param(
            [Parameter(Mandatory)] [string] $CaseName,
            [Parameter(Mandatory)] [string] $FixtureDir
        )

        # Build a clean temp git repo so `act` sees only the project files
        # plus this case's fixture data — no leftover state from other cases.
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ("aggr-act-" + [guid]::NewGuid().ToString('N')))
        try {
            Copy-Item -Path (Join-Path $script:RepoRoot "Aggregator.psm1") -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:RepoRoot "Invoke-Aggregator.ps1") -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:RepoRoot ".actrc") -Destination $tmp.FullName
            Copy-Item -Path (Join-Path $script:RepoRoot ".github") -Destination $tmp.FullName -Recurse

            $fxDest = Join-Path $tmp.FullName "fixtures"
            New-Item -ItemType Directory -Path $fxDest | Out-Null
            Copy-Item -Path (Join-Path $FixtureDir "*") -Destination $fxDest -Recurse

            Push-Location $tmp.FullName
            try {
                git init -q -b main 2>&1 | Out-Null
                git config user.email "ci@example.com" 2>&1 | Out-Null
                git config user.name "ci" 2>&1 | Out-Null
                git add -A 2>&1 | Out-Null
                git commit -q -m "test: $CaseName" 2>&1 | Out-Null

                $output = & act push --rm 2>&1 | Out-String
                $exit = $LASTEXITCODE
            } finally {
                Pop-Location
            }

            $delim = "===== act run: $CaseName ====="
            Add-Content -Path $script:ActResultFile -Value "`n$delim`n$output`nexit_code=$exit`n===== end $CaseName =====`n"

            return [pscustomobject]@{ Output = $output; ExitCode = $exit }
        } finally {
            Remove-Item -Recurse -Force $tmp.FullName -ErrorAction SilentlyContinue
        }
    }
}

Describe "Aggregator via act - case1: basic aggregation across mixed formats" {
    # case1 expected totals:
    #   3 files: run1.junit.xml(4) + run2.junit.xml(3) + run3.json(3) = 10 tests
    #   passed = 3 + 3 + 2 = 8
    #   failed = 1 + 0 + 0 = 1
    #   skipped = 0 + 0 + 1 = 1
    #   duration = 0.500 + 0.300 + 0.120 = 0.920s
    #   flaky = 0  (each test name appears in only one file)
    BeforeAll {
        $script:Result = Invoke-ActWithFixtures -CaseName "case1" -FixtureDir (Join-Path $RepoRoot "fixtures/case1")
    }

    It "exits with code 0" {
        $script:Result.ExitCode | Should -Be 0
    }

    It "shows 'Job succeeded'" {
        $script:Result.Output | Should -Match 'Job succeeded'
    }

    It "reports total of 10 tests" {
        $script:Result.Output | Should -Match 'Total:\s*10'
    }

    It "reports 8 passed" {
        $script:Result.Output | Should -Match 'Passed:\s*8'
    }

    It "reports 1 failed" {
        $script:Result.Output | Should -Match 'Failed:\s*1'
    }

    It "reports 1 skipped" {
        $script:Result.Output | Should -Match 'Skipped:\s*1'
    }

    It "reports duration of 0.92 seconds" {
        $script:Result.Output | Should -Match 'Duration:\s*0\.92\s*s'
    }

    It "reports zero flaky tests" {
        $script:Result.Output | Should -Match 'Flaky tests:\s*0'
    }

    It "names the failing test (testDiv)" {
        $script:Result.Output | Should -Match 'testDiv'
    }
}

Describe "Aggregator via act - case2: flaky test detection" {
    # case2 expected totals:
    #   3 files, 3 tests each = 9 total
    #   passed = 7, failed = 2, skipped = 0
    #   testNetwork: passed,failed,passed -> FLAKY
    #   testTimeout: failed,passed,passed -> FLAKY
    #   testStable:  passed,passed,passed -> NOT flaky
    #   flaky count = 2
    BeforeAll {
        $script:Result = Invoke-ActWithFixtures -CaseName "case2" -FixtureDir (Join-Path $RepoRoot "fixtures/case2")
    }

    It "exits with code 0" {
        $script:Result.ExitCode | Should -Be 0
    }

    It "shows 'Job succeeded'" {
        $script:Result.Output | Should -Match 'Job succeeded'
    }

    It "reports total of 9 tests" {
        $script:Result.Output | Should -Match 'Total:\s*9'
    }

    It "reports 7 passed" {
        $script:Result.Output | Should -Match 'Passed:\s*7'
    }

    It "reports 2 failed" {
        $script:Result.Output | Should -Match 'Failed:\s*2'
    }

    It "reports 2 flaky tests" {
        $script:Result.Output | Should -Match 'Flaky tests:\s*2'
    }

    It "lists testNetwork as flaky" {
        $script:Result.Output | Should -Match 'testNetwork'
    }

    It "lists testTimeout as flaky" {
        $script:Result.Output | Should -Match 'testTimeout'
    }

    It "does NOT mark testStable as flaky" {
        # testStable should appear nowhere in a 'Flaky' context
        if ($script:Result.Output -match '(?s)## Flaky Tests(.*?)(##|$)') {
            $matches[1] | Should -Not -Match 'testStable'
        }
    }
}

Describe "Aggregator via act - case3: skipped-heavy / duration handling" {
    # case3 expected totals:
    #   skipped.junit.xml: 2 tests, both skipped, duration 0.000
    #   passed.json: 3 tests, all passed, duration 0.001 + 0.250 + 1.500 = 1.751
    #   total = 5, passed = 3, failed = 0, skipped = 2
    #   total duration = 1.751
    #   flaky = 0
    BeforeAll {
        $script:Result = Invoke-ActWithFixtures -CaseName "case3" -FixtureDir (Join-Path $RepoRoot "fixtures/case3")
    }

    It "exits with code 0" {
        $script:Result.ExitCode | Should -Be 0
    }

    It "shows 'Job succeeded'" {
        $script:Result.Output | Should -Match 'Job succeeded'
    }

    It "reports total of 5 tests" {
        $script:Result.Output | Should -Match 'Total:\s*5'
    }

    It "reports 3 passed" {
        $script:Result.Output | Should -Match 'Passed:\s*3'
    }

    It "reports 0 failed" {
        $script:Result.Output | Should -Match 'Failed:\s*0'
    }

    It "reports 2 skipped" {
        $script:Result.Output | Should -Match 'Skipped:\s*2'
    }

    It "reports duration of 1.75 seconds" {
        $script:Result.Output | Should -Match 'Duration:\s*1\.75\s*s'
    }

    It "reports zero flaky tests" {
        $script:Result.Output | Should -Match 'Flaky tests:\s*0'
    }
}
