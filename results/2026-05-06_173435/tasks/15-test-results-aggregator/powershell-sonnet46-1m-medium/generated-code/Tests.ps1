#Requires -Module Pester
# Test Results Aggregator - Pester Test Suite
# TDD approach: tests are written first, then implementation is added to make them pass.
# All substantive tests run through the GitHub Actions workflow via act.
# This file contains: workflow structure tests + act integration tests.

param(
    [string]$WorkspaceRoot = $PSScriptRoot
)

BeforeAll {
    $script:WorkspaceRoot = if ($PSScriptRoot) { $PSScriptRoot } else { $WorkspaceRoot }
    $script:WorkflowPath = Join-Path $script:WorkspaceRoot ".github/workflows/test-results-aggregator.yml"
    $script:ScriptPath = Join-Path $script:WorkspaceRoot "Invoke-TestAggregator.ps1"
    $script:FixturesDir = Join-Path $script:WorkspaceRoot "fixtures"
    $script:ActResultFile = Join-Path $script:WorkspaceRoot "act-result.txt"

    # Initialize act-result.txt
    "# Act Integration Test Results" | Out-File -FilePath $script:ActResultFile -Force -Encoding utf8
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $script:ActResultFile -Append -Encoding utf8
    "" | Out-File -FilePath $script:ActResultFile -Append -Encoding utf8

    # Helper: set up a temp git repo, run act push --rm, save output to act-result.txt.
    # Must be defined here in BeforeAll so Pester's run phase can access it.
    function script:Invoke-ActTest {
        param(
            [string]$TestName,
            [string]$FixtureDir,
            [string]$WorkspaceRoot
        )

        $originalDir = Get-Location
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $tempDir | Out-Null

        try {
            # Copy required project files into the temp git repo
            Copy-Item (Join-Path $WorkspaceRoot "Invoke-TestAggregator.ps1") $tempDir -Force
            Copy-Item (Join-Path $WorkspaceRoot ".actrc") $tempDir -Force

            $wfDir = Join-Path $tempDir ".github/workflows"
            New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
            Copy-Item (Join-Path $WorkspaceRoot ".github/workflows/test-results-aggregator.yml") $wfDir -Force

            # Copy fixture files for this test case
            $tempFixtures = Join-Path $tempDir "fixtures"
            New-Item -ItemType Directory -Path $tempFixtures -Force | Out-Null
            if ($FixtureDir -and (Test-Path $FixtureDir)) {
                Copy-Item (Join-Path $FixtureDir "*") $tempFixtures -Force
            }

            Set-Location $tempDir

            # Initialize git repo and commit all files
            & git init -b main 2>$null | Out-Null
            & git config user.email "test@example.com" 2>$null | Out-Null
            & git config user.name "Test Runner" 2>$null | Out-Null
            & git add -A 2>$null | Out-Null
            & git commit -m "test: add project files for act test" 2>$null | Out-Null

            # Run act — all output captured for assertions
            $output = & act push --rm 2>&1
            $actExitCode = $LASTEXITCODE
            $outputStr = $output -join "`n"

            # Append full output to act-result.txt for the required artifact
            $delim = "=" * 60
            @"
$delim
TEST CASE: $TestName
$delim
Exit Code: $actExitCode
Output:
$outputStr

"@ | Out-File -FilePath (Join-Path $WorkspaceRoot "act-result.txt") -Append -Encoding utf8

            return @{
                ExitCode  = $actExitCode
                Output    = $outputStr
                OutputArr = $output
            }
        }
        finally {
            Set-Location $originalDir
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- WORKFLOW STRUCTURE TESTS ---
# These tests run directly (no act required) and validate the workflow file.

Describe "Workflow Structure Tests" {

    It "workflow file exists at expected path" {
        $script:WorkflowPath | Should -Exist
    }

    It "aggregator script file exists" {
        $script:ScriptPath | Should -Exist
    }

    It "fixtures directory exists" {
        $script:FixturesDir | Should -Exist
    }

    It "fixture JUnit XML run1 exists" {
        Join-Path $script:FixturesDir "junit-run1.xml" | Should -Exist
    }

    It "fixture JUnit XML run2 exists" {
        Join-Path $script:FixturesDir "junit-run2.xml" | Should -Exist
    }

    It "fixture JSON run3 exists" {
        Join-Path $script:FixturesDir "json-run3.json" | Should -Exist
    }

    It "workflow has push trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push:"
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "workflow_dispatch:"
    }

    It "workflow references the aggregator script" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "Invoke-TestAggregator\.ps1"
    }

    It "workflow uses shell: pwsh for PowerShell steps" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "workflow uses actions/checkout@v4" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "actions/checkout@v4"
    }

    It "actionlint passes with exit code 0" {
        $result = & actionlint $script:WorkflowPath 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            Write-Host "actionlint output: $result"
        }
        $exitCode | Should -Be 0
    }
}

# --- ACT INTEGRATION TESTS ---
# These tests use the GitHub Actions workflow to validate the aggregator logic.
# Each test sets up a git repo, runs act push --rm, and asserts on the output.

Describe "Act Integration - Full Aggregation with JUnit XML and JSON" {

    BeforeAll {
        # Use all three fixture files: junit-run1.xml, junit-run2.xml, json-run3.json
        # Expected:
        #   run1: TestA(pass,1.0s), TestB(fail,0.5s), TestC(pass,2.0s), TestD(skip,0.0s)
        #   run2: TestA(pass,1.2s), TestB(pass,0.6s), TestE(fail,0.3s)
        #   run3: TestF(pass,0.8s), TestG(pass,1.5s)
        # Totals: passed=6, failed=2, skipped=1, duration=7.9s
        # Flaky: TestB (failed in run1, passed in run2)
        $script:ActResult = Invoke-ActTest `
            -TestName "Full Aggregation with JUnit XML and JSON" `
            -FixtureDir $script:FixturesDir `
            -WorkspaceRoot $script:WorkspaceRoot
    }

    It "act exits with code 0" {
        $script:ActResult.ExitCode | Should -Be 0
    }

    It "every job shows Job succeeded" {
        $script:ActResult.Output | Should -Match "Job succeeded"
    }

    It "reports correct total passed count (6)" {
        $script:ActResult.Output | Should -Match "AGGREGATE_PASSED=6"
    }

    It "reports correct total failed count (2)" {
        $script:ActResult.Output | Should -Match "AGGREGATE_FAILED=2"
    }

    It "reports correct total skipped count (1)" {
        $script:ActResult.Output | Should -Match "AGGREGATE_SKIPPED=1"
    }

    It "reports correct total count (9)" {
        $script:ActResult.Output | Should -Match "AGGREGATE_TOTAL=9"
    }

    It "reports correct total duration (7.9s)" {
        $script:ActResult.Output | Should -Match "AGGREGATE_DURATION=7\.9"
    }

    It "identifies TestB as flaky" {
        $script:ActResult.Output | Should -Match "FLAKY_TESTS=TestB"
    }

    It "generates markdown summary header" {
        $script:ActResult.Output | Should -Match "Test Results Summary"
    }
}
