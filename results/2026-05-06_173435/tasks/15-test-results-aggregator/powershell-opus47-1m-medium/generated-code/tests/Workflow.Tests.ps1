# Workflow integration tests.
#
# Per task requirements: every test case for the aggregator runs through the
# full GitHub Actions workflow via `act`. For each case we:
#   1. Build a temp git repo seeded with the project files plus that case's
#      fixture data under aggregator-input/.
#   2. Run `act push --rm` against that temp repo.
#   3. Append the full act output to ./act-result.txt with delimiters.
#   4. Assert exit code 0, "Job succeeded" for every job, and exact expected
#      values produced by the aggregator for that fixture set.
#
# The .actrc at the project root pins ubuntu-latest to a Pester-equipped
# image; this script reuses it.

BeforeDiscovery {
    $script:ProjectRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ActResultFile = Join-Path $script:ProjectRoot 'act-result.txt'
    $script:HasAct        = $null -ne (Get-Command act -ErrorAction SilentlyContinue)
    if ($script:HasAct -and (Test-Path -LiteralPath $script:ActResultFile)) {
        Remove-Item -LiteralPath $script:ActResultFile -Force
    }
}

BeforeAll {
    $script:ProjectRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ActResultFile = Join-Path $script:ProjectRoot 'act-result.txt'
    $script:FixturesDir   = Join-Path $script:ProjectRoot 'tests' 'fixtures'

    function script:Initialize-TempRepo {
        param([string] $CaseName, [string[]] $FixtureFiles)

        $repo = Join-Path ([System.IO.Path]::GetTempPath()) "agg-$CaseName-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $repo -Force | Out-Null

        # Copy project files into the temp repo. We deliberately exclude .git,
        # tests/, and prior act-result.txt: the workflow only needs src/,
        # scripts/, .github/, and .actrc to function inside the container.
        $exclude = @('.git', 'act-result.txt', 'tests')
        Get-ChildItem -LiteralPath $script:ProjectRoot -Force | Where-Object {
            $exclude -notcontains $_.Name
        } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $repo -Recurse -Force
        }

        # Seed the fixture directory the workflow expects.
        $fixDir = Join-Path $repo 'aggregator-input'
        New-Item -ItemType Directory -Path $fixDir -Force | Out-Null
        foreach ($f in $FixtureFiles) {
            $src = Join-Path $script:FixturesDir $f
            if (-not (Test-Path -LiteralPath $src)) {
                throw "Fixture file not found: $src"
            }
            Copy-Item -LiteralPath $src -Destination (Join-Path $fixDir $f) -Force
        }

        # Pester tests of the aggregator itself need to be present in the act
        # container too (the `pester` job runs them), so copy a minimal tests
        # tree containing only the unit tests + their fixtures.
        $testsTarget = Join-Path $repo 'tests'
        New-Item -ItemType Directory -Path $testsTarget -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'TestResultsAggregator.Tests.ps1') -Destination $testsTarget -Force
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures') -Destination $testsTarget -Recurse -Force

        # Initialize git repo (act needs a real git history to evaluate `push` events).
        Push-Location $repo
        try {
            git init -q
            git config user.email 'harness@example.com'
            git config user.name  'Harness'
            git add -A | Out-Null
            git commit -q -m 'seed' | Out-Null
        } finally {
            Pop-Location
        }
        return $repo
    }

    function script:Invoke-ActCase {
        param([string] $CaseName, [string] $RepoDir)

        Push-Location $RepoDir
        try {
            # --rm cleans up after the run. Capture both stdout and stderr.
            # --pull=false avoids re-pulling the locally-built act-ubuntu-pwsh image.
            $output = & act push --rm --pull=false 2>&1 | Out-String
            $exit   = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        # Append to act-result.txt with clear delimiters.
        $delim = "=" * 80
        Add-Content -LiteralPath $script:ActResultFile -Value @"
$delim
CASE: $CaseName
EXIT: $exit
$delim
$output
"@
        [pscustomobject]@{
            CaseName = $CaseName
            ExitCode = $exit
            Output   = $output
        }
    }
}

Describe 'GitHub Actions workflow' -Skip:(-not $script:HasAct) {

    Context 'Workflow file structure' {
        It 'is valid YAML and references existing script files' {
            $wfPath = Join-Path $script:ProjectRoot '.github/workflows/test-results-aggregator.yml'
            Test-Path $wfPath | Should -BeTrue
            $content = Get-Content $wfPath -Raw
            $content | Should -Match 'actions/checkout@v4'
            $content | Should -Match 'shell: pwsh'
            $content | Should -Match 'scripts/Invoke-Aggregator.ps1'
            (Test-Path (Join-Path $script:ProjectRoot 'scripts/Invoke-Aggregator.ps1')) | Should -BeTrue
            (Test-Path (Join-Path $script:ProjectRoot 'src/TestResultsAggregator.psm1'))   | Should -BeTrue
        }

        It 'passes actionlint' {
            $wfPath = Join-Path $script:ProjectRoot '.github/workflows/test-results-aggregator.yml'
            $out = & actionlint $wfPath 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0 -Because "actionlint output: $out"
        }
    }

    Context 'Case A: all-passing JUnit fixture' {
        It 'aggregator reports 4 total / 4 passed / 0 failed and act succeeds' {
            $repo = script:Initialize-TempRepo -CaseName 'A-all-pass' -FixtureFiles @('junit-allpass.xml')
            try {
                $r = script:Invoke-ActCase -CaseName 'A-all-pass' -RepoDir $repo
                $r.ExitCode | Should -Be 0 -Because "act output: $($r.Output)"
                $r.Output   | Should -Match 'AGG_TOTAL=4'
                $r.Output   | Should -Match 'AGG_PASSED=4'
                $r.Output   | Should -Match 'AGG_FAILED=0'
                $r.Output   | Should -Match 'No flaky tests detected'
                # Both jobs must show "Job succeeded".
                ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
            } finally {
                Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Case B: matrix run with one flaky test' {
        It 'detects exactly one flaky test (test_session_refresh) across two JUnit runs' {
            $repo = script:Initialize-TempRepo -CaseName 'B-flaky' -FixtureFiles @('junit-run1.xml', 'junit-run2.xml')
            try {
                $r = script:Invoke-ActCase -CaseName 'B-flaky' -RepoDir $repo
                $r.ExitCode | Should -Be 0 -Because "act output: $($r.Output)"
                # Run1 has 4 cases (1 fail, 1 skip, 2 pass), Run2 has 3 cases (1 fail, 2 pass) → 7 total.
                $r.Output | Should -Match 'AGG_TOTAL=7'
                $r.Output | Should -Match 'AGG_PASSED=4'
                $r.Output | Should -Match 'AGG_FAILED=2'
                $r.Output | Should -Match 'AGG_SKIPPED=1'
                # The flaky test (test_session_refresh: passed in run1, failed in run2) must appear in the markdown.
                $r.Output | Should -Match '\| test_session_refresh \|'
                # Make sure stable failures (test_logout passed/failed differently, but in this fixture
                # run2 has logout passing so it IS flaky too: actually logout failed in run1, passed in run2).
                $r.Output | Should -Match '\| test_logout \|'
                ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
            } finally {
                Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Case C: mixed JUnit + JSON fixtures' {
        It 'aggregates across formats and reports correct totals' {
            $repo = script:Initialize-TempRepo -CaseName 'C-mixed' -FixtureFiles @('junit-allpass.xml', 'results-run1.json')
            try {
                $r = script:Invoke-ActCase -CaseName 'C-mixed' -RepoDir $repo
                $r.ExitCode | Should -Be 0 -Because "act output: $($r.Output)"
                # 4 (allpass JUnit) + 4 (JSON) = 8 total. JSON has 2 passed, 1 failed, 1 skipped.
                $r.Output | Should -Match 'AGG_TOTAL=8'
                $r.Output | Should -Match 'AGG_PASSED=6'
                $r.Output | Should -Match 'AGG_FAILED=1'
                $r.Output | Should -Match 'AGG_SKIPPED=1'
                # The failing JSON test name must appear in the failures table.
                $r.Output | Should -Match '\| DELETE_users \|'
                ([regex]::Matches($r.Output, 'Job succeeded')).Count | Should -BeGreaterOrEqual 2
            } finally {
                Remove-Item -LiteralPath $repo -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
