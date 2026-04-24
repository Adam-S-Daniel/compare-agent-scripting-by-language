# TDD test suite for Test Results Aggregator
# Tests run in order: structure tests first, then act integration tests.
# Act integration tests run the workflow in a temporary git repo and assert
# on EXACT output values from the aggregator script.

BeforeAll {
    $script:projectRoot = Split-Path -Parent $PSScriptRoot
    $script:scriptPath  = Join-Path $script:projectRoot "Invoke-TestResultsAggregator.ps1"
    $script:workflowPath = Join-Path $script:projectRoot ".github/workflows/test-results-aggregator.yml"
    $script:fixturesPath = Join-Path $script:projectRoot "fixtures"
    $script:actResultPath = Join-Path $script:projectRoot "act-result.txt"
}

# ── RED: these fail first; passing requires the files to exist ────────────────

Describe "Script and Fixture Files Exist" {
    It "main aggregator script exists" {
        $script:scriptPath | Should -Exist
    }
    It "fixtures directory exists" {
        $script:fixturesPath | Should -Exist
    }
    It "JUnit fixture run1 exists" {
        Join-Path $script:fixturesPath "junit-run1.xml" | Should -Exist
    }
    It "JUnit fixture run2 exists" {
        Join-Path $script:fixturesPath "junit-run2.xml" | Should -Exist
    }
    It "JSON fixture run3 exists" {
        Join-Path $script:fixturesPath "results-run3.json" | Should -Exist
    }
    It "JSON fixture run4 exists" {
        Join-Path $script:fixturesPath "results-run4.json" | Should -Exist
    }
}

Describe "Workflow Structure" {
    BeforeAll {
        if (Test-Path $script:workflowPath) {
            $script:wf = Get-Content -Path $script:workflowPath -Raw
        } else {
            $script:wf = ""
        }
    }

    It "workflow file exists" {
        $script:workflowPath | Should -Exist
    }
    It "has push trigger" {
        $script:wf | Should -Match "push"
    }
    It "has workflow_dispatch trigger" {
        $script:wf | Should -Match "workflow_dispatch"
    }
    It "has aggregate-results job" {
        $script:wf | Should -Match "aggregate-results"
    }
    It "uses ubuntu-latest runner" {
        $script:wf | Should -Match "ubuntu-latest"
    }
    It "uses shell: pwsh for PowerShell steps" {
        $script:wf | Should -Match "shell:\s*pwsh"
    }
    It "references the aggregator script" {
        $script:wf | Should -Match "Invoke-TestResultsAggregator"
    }
    It "references the fixtures path" {
        $script:wf | Should -Match "fixtures"
    }
    It "passes actionlint validation" {
        $out = & actionlint $script:workflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $out"
    }
}

# ── GREEN: act integration tests ──────────────────────────────────────────────
# These run the workflow via act in an isolated temp git repo and assert on
# exact output values produced by the aggregator script against the fixtures.
#
# Expected fixture data summary:
#   junit-run1.xml : TestAlpha(pass 0.25s) TestBeta(fail 0.5s)  TestGamma(skip)
#   junit-run2.xml : TestAlpha(pass 0.5s)  TestBeta(pass 0.5s)  TestGamma(skip)
#   results-run3.json: TestDelta(pass 0.25s) TestEpsilon(fail 0.5s)
#   results-run4.json: TestDelta(pass 0.5s)  TestEpsilon(pass 0.5s)
#
# Aggregated: Passed=6, Failed=2, Skipped=2, Duration=3.5
# Flaky: TestBeta (fail run1, pass run2), TestEpsilon (fail run3, pass run4)

Describe "Act Integration — Aggregate Results" {
    BeforeAll {
        # Create a temp git repo with all project files
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "tra-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $script:tmpDir = $tmp

        # Copy project artifacts into the temp repo
        Copy-Item -Path $script:scriptPath -Destination $tmp
        Copy-Item -Path $script:fixturesPath -Destination $tmp -Recurse
        Copy-Item -Path (Join-Path $script:projectRoot ".github") -Destination $tmp -Recurse

        # Copy .actrc so act uses the pre-built pwsh container image
        $actrc = Join-Path $script:projectRoot ".actrc"
        if (Test-Path $actrc) {
            Copy-Item -Path $actrc -Destination $tmp
        }

        # Bootstrap the git repo
        & git -C $tmp init          2>&1 | Out-Null
        & git -C $tmp config user.email "test@ci.local" 2>&1 | Out-Null
        & git -C $tmp config user.name  "CI Test"       2>&1 | Out-Null
        & git -C $tmp add -A        2>&1 | Out-Null
        & git -C $tmp commit -m "ci: test fixture commit" 2>&1 | Out-Null

        # Run act and capture all output (stdout + stderr merged)
        Push-Location $tmp
        $script:actOut      = & act push --rm 2>&1 | Out-String
        $script:actExit     = $LASTEXITCODE
        Pop-Location

        # Append to act-result.txt (required artifact)
        $sep = "=" * 70
        @(
            $sep,
            "Test Case : Aggregate Results (4 fixture files)",
            "Date      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
            "Exit code : $($script:actExit)",
            $sep,
            $script:actOut,
            ""
        ) -join "`n" | Add-Content -Path $script:actResultPath
    }

    AfterAll {
        if ($script:tmpDir -and (Test-Path $script:tmpDir)) {
            Remove-Item -Path $script:tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "act exits with code 0" {
        $script:actExit | Should -Be 0 -Because "act output: $($script:actOut | Select-String 'error|Error|FAIL' | Select-Object -First 10)"
    }
    It "output contains exact aggregate totals" {
        $script:actOut | Should -Match "AGGREGATE: Passed=6 Failed=2 Skipped=2 Duration=3\.5"
    }
    It "output identifies flaky tests" {
        $script:actOut | Should -Match "FLAKY: TestBeta TestEpsilon"
    }
    It "every job shows Job succeeded" {
        $script:actOut | Should -Match "Job succeeded"
    }
    It "act-result.txt artifact was created" {
        $script:actResultPath | Should -Exist
    }
}
