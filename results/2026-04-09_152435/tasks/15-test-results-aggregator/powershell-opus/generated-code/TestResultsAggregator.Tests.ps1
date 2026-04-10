# TestResultsAggregator.Tests.ps1
#
# TDD Red-Green-Refactor approach:
#   1. These tests were written FIRST, before any implementation code
#   2. Each Describe block targets a specific piece of functionality
#   3. Tests verify exact expected values from known fixture data
#
# Test fixture data (3 runs simulating a matrix build):
#   Run 1 (ubuntu XML): TestA=pass, TestB=fail, TestC=pass, TestD=skip, TestE=pass
#   Run 2 (macos XML):  TestA=pass, TestB=fail, TestC=fail, TestD=skip, TestE=pass
#   Run 3 (windows JSON): TestA=pass, TestB=fail, TestC=pass, TestD=skip, TestE=pass
#
# Expected aggregated totals: 15 total, 8 passed, 4 failed, 3 skipped, 12.4s
# Expected flaky test: TestC (passed 2/3 = 66.7%)

BeforeAll {
    $script:ProjectRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $ProjectRoot '.github' 'workflows' 'test-results-aggregator.yml'
    $script:ScriptPath = Join-Path $ProjectRoot 'TestResultsAggregator.ps1'
    $script:FixturesPath = Join-Path $ProjectRoot 'fixtures'
    $script:ActResultFile = Join-Path $ProjectRoot 'act-result.txt'

    # Initialize act-result.txt (required artifact)
    Set-Content -Path $script:ActResultFile -Value "# Act Test Results Log`n"

    # Helper: create a temp git repo with project files + specified fixture files
    function New-ActTestRepo {
        param([string[]]$FixtureFiles)

        $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $TempDir '.github' 'workflows') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $TempDir 'fixtures') -Force | Out-Null

        # Copy workflow, script, and actrc into the temp repo
        Copy-Item $script:WorkflowPath (Join-Path $TempDir '.github' 'workflows' 'test-results-aggregator.yml')
        Copy-Item $script:ScriptPath (Join-Path $TempDir 'TestResultsAggregator.ps1')
        Copy-Item (Join-Path $script:ProjectRoot '.actrc') (Join-Path $TempDir '.actrc')

        # Copy the specified fixture files into fixtures/
        foreach ($f in $FixtureFiles) {
            Copy-Item $f (Join-Path $TempDir 'fixtures' (Split-Path $f -Leaf))
        }

        # Initialize a git repo (act requires it for checkout)
        Push-Location $TempDir
        git init --quiet 2>&1 | Out-Null
        git -c user.email="test@test.com" -c user.name="Test" add -A 2>&1 | Out-Null
        git -c user.email="test@test.com" -c user.name="Test" commit -m "init" --quiet 2>&1 | Out-Null
        Pop-Location

        return $TempDir
    }

    # Helper: run act push in a given repo directory and capture output + exit code
    function Invoke-ActPush {
        param([string]$RepoDir)

        Push-Location $RepoDir
        $output = & act push --rm --pull=false 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        Pop-Location

        return @{ Output = $output; ExitCode = $exitCode }
    }
}

# ============================================================================
# WORKFLOW STRUCTURE TESTS - validate YAML structure without running act
# ============================================================================
Describe "Workflow Structure Tests" {

    It "workflow YAML file exists" {
        $script:WorkflowPath | Should -Exist
    }

    It "aggregator script file exists" {
        $script:ScriptPath | Should -Exist
    }

    It "fixture files exist" {
        Join-Path $script:FixturesPath 'run1-ubuntu.xml' | Should -Exist
        Join-Path $script:FixturesPath 'run2-macos.xml' | Should -Exist
        Join-Path $script:FixturesPath 'run3-windows.json' | Should -Exist
    }

    Context "YAML content validation" {
        BeforeAll {
            $script:YamlContent = Get-Content $script:WorkflowPath -Raw
        }

        It "has push trigger" {
            $script:YamlContent | Should -Match 'push'
        }

        It "has pull_request trigger" {
            $script:YamlContent | Should -Match 'pull_request'
        }

        It "has workflow_dispatch trigger" {
            $script:YamlContent | Should -Match 'workflow_dispatch'
        }

        It "uses actions/checkout@v4" {
            $script:YamlContent | Should -Match 'actions/checkout@v4'
        }

        It "uses shell: pwsh for run steps" {
            $script:YamlContent | Should -Match 'shell:\s*pwsh'
        }

        It "references TestResultsAggregator.ps1" {
            $script:YamlContent | Should -Match 'TestResultsAggregator\.ps1'
        }
    }

    It "passes actionlint validation" {
        $lintOutput = & actionlint $script:WorkflowPath 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $lintOutput"
    }
}

# ============================================================================
# ACT INTEGRATION TEST 1: Mixed results with flaky tests
# Expected: 15 total, 8 passed, 4 failed, 3 skipped, 12.4s, TestC flaky
# ============================================================================
Describe "Act Integration - Mixed Results with Flaky Tests" {
    BeforeAll {
        $fixtures = @(
            (Join-Path $script:FixturesPath 'run1-ubuntu.xml'),
            (Join-Path $script:FixturesPath 'run2-macos.xml'),
            (Join-Path $script:FixturesPath 'run3-windows.json')
        )
        $script:MixedRepo = New-ActTestRepo -FixtureFiles $fixtures
        $script:MixedResult = Invoke-ActPush -RepoDir $script:MixedRepo

        # Append output to act-result.txt (required artifact)
        "`n=== MIXED RESULTS TEST ===" | Add-Content $script:ActResultFile
        $script:MixedResult.Output | Add-Content $script:ActResultFile
        "=== END MIXED RESULTS TEST ===`n" | Add-Content $script:ActResultFile
    }

    It "act exits with code 0" {
        $script:MixedResult.ExitCode | Should -Be 0
    }

    It "job shows succeeded" {
        $script:MixedResult.Output | Should -Match 'Job succeeded'
    }

    # Exact value assertions on aggregated totals
    It "reports exactly 15 total tests" {
        $script:MixedResult.Output | Should -Match 'Total[^\n]*15'
    }

    It "reports exactly 8 passed tests" {
        $script:MixedResult.Output | Should -Match 'Passed[^\n]*8'
    }

    It "reports exactly 4 failed tests" {
        $script:MixedResult.Output | Should -Match 'Failed[^\n]*4'
    }

    It "reports exactly 3 skipped tests" {
        $script:MixedResult.Output | Should -Match 'Skipped[^\n]*3'
    }

    It "reports total duration of 12.4s" {
        $script:MixedResult.Output | Should -Match '12\.4'
    }

    # Flaky test detection
    It "identifies TestC as a flaky test" {
        $script:MixedResult.Output | Should -Match 'TestC'
    }

    It "labels the flaky tests section" {
        $script:MixedResult.Output | Should -Match '[Ff]laky'
    }

    It "shows TestC pass rate of 66.7%" {
        $script:MixedResult.Output | Should -Match '66\.7'
    }

    AfterAll {
        if ($script:MixedRepo -and (Test-Path $script:MixedRepo)) {
            Remove-Item -Recurse -Force $script:MixedRepo -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# ACT INTEGRATION TEST 2: All tests passing (no failures, no flaky)
# Expected: 3 total, 3 passed, 0 failed, 0 skipped, 2.3s, no flaky
# ============================================================================
Describe "Act Integration - All Passing Tests" {
    BeforeAll {
        # Create an all-passing JSON fixture dynamically
        $allPassDir = Join-Path ([System.IO.Path]::GetTempPath()) "allpass-$(Get-Random)"
        New-Item -ItemType Directory -Path $allPassDir -Force | Out-Null

        $allPassData = @{
            testsuites = @(
                @{
                    name = "AllPassSuite"
                    testcases = @(
                        @{ name = "TestX"; status = "passed"; duration = 0.5 }
                        @{ name = "TestY"; status = "passed"; duration = 1.0 }
                        @{ name = "TestZ"; status = "passed"; duration = 0.8 }
                    )
                }
            )
        }
        $allPassData | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $allPassDir 'all-pass.json')

        $script:PassRepo = New-ActTestRepo -FixtureFiles @((Join-Path $allPassDir 'all-pass.json'))
        $script:PassResult = Invoke-ActPush -RepoDir $script:PassRepo

        # Append output to act-result.txt
        "`n=== ALL PASSING TEST ===" | Add-Content $script:ActResultFile
        $script:PassResult.Output | Add-Content $script:ActResultFile
        "=== END ALL PASSING TEST ===`n" | Add-Content $script:ActResultFile

        Remove-Item -Recurse -Force $allPassDir -ErrorAction SilentlyContinue
    }

    It "act exits with code 0" {
        $script:PassResult.ExitCode | Should -Be 0
    }

    It "job shows succeeded" {
        $script:PassResult.Output | Should -Match 'Job succeeded'
    }

    It "reports exactly 3 total tests" {
        $script:PassResult.Output | Should -Match 'Total[^\n]*3'
    }

    It "reports exactly 3 passed tests" {
        $script:PassResult.Output | Should -Match 'Passed[^\n]*3'
    }

    It "reports 0 failed tests" {
        $script:PassResult.Output | Should -Match 'Failed[^\n]*0'
    }

    It "reports 0 skipped tests" {
        $script:PassResult.Output | Should -Match 'Skipped[^\n]*0'
    }

    It "reports duration of 2.3s" {
        $script:PassResult.Output | Should -Match '2\.3'
    }

    It "indicates no flaky tests found" {
        $script:PassResult.Output | Should -Match '[Nn]o flaky tests'
    }

    AfterAll {
        if ($script:PassRepo -and (Test-Path $script:PassRepo)) {
            Remove-Item -Recurse -Force $script:PassRepo -ErrorAction SilentlyContinue
        }
    }
}
