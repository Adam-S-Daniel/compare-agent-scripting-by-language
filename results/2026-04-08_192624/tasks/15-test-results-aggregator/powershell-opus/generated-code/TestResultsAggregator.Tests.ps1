# TestResultsAggregator.Tests.ps1
# Pester tests for the Test Results Aggregator workflow.
# All functional tests run through act (GitHub Actions local runner).
# Structural tests validate the workflow YAML and file references.

BeforeAll {
    $script:ProjectRoot = $PSScriptRoot
    $script:WorkflowPath = Join-Path $ProjectRoot ".github/workflows/test-results-aggregator.yml"
    $script:ScriptPath = Join-Path $ProjectRoot "Aggregate-TestResults.ps1"
    $script:FixturesDir = Join-Path $ProjectRoot "fixtures"
    $script:ActResultFile = Join-Path $ProjectRoot "act-result.txt"

    # Clear act-result.txt at the start of the test run
    "" | Set-Content $script:ActResultFile

    # Helper: create a temp git repo with project files and specified fixtures
    function New-TempActRepo {
        param(
            [string[]]$FixtureFiles
        )
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Copy the aggregation script
        Copy-Item $script:ScriptPath $tempDir

        # Copy the workflow
        $wfDir = Join-Path $tempDir ".github/workflows"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item $script:WorkflowPath $wfDir

        # Copy specified fixtures into a fixtures/ subdirectory
        $fixDir = Join-Path $tempDir "fixtures"
        New-Item -ItemType Directory -Path $fixDir -Force | Out-Null
        foreach ($f in $FixtureFiles) {
            Copy-Item (Join-Path $script:FixturesDir $f) $fixDir
        }

        # Initialize a git repository so act can operate
        Push-Location $tempDir
        git init -q 2>&1 | Out-Null
        git config user.email "test@test.com" 2>&1 | Out-Null
        git config user.name "Test" 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -q -m "initial" 2>&1 | Out-Null
        Pop-Location

        return $tempDir
    }

    # Helper: run act push in a repo directory and return output + exit code
    function Invoke-ActPush {
        param(
            [string]$RepoDir
        )
        Push-Location $RepoDir
        $output = & act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-latest 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        Pop-Location

        return @{
            Output   = $output
            ExitCode = $exitCode
        }
    }
}

# ---------------------------------------------------------------------------
# Structural tests: validate workflow YAML, triggers, file references, lint
# ---------------------------------------------------------------------------
Describe "Workflow Structure" {
    It "has a valid YAML workflow file" {
        Test-Path $script:WorkflowPath | Should -BeTrue
    }

    It "contains a push trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "push"
    }

    It "contains a pull_request trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "pull_request"
    }

    It "contains a workflow_dispatch trigger" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "workflow_dispatch"
    }

    It "references Aggregate-TestResults.ps1 which exists on disk" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "Aggregate-TestResults\.ps1"
        Test-Path $script:ScriptPath | Should -BeTrue
    }

    It "references the fixtures directory" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "fixtures"
        Test-Path $script:FixturesDir | Should -BeTrue
    }

    It "uses actions/checkout@v4" {
        $content = Get-Content $script:WorkflowPath -Raw
        $content | Should -Match "actions/checkout@v4"
    }

    It "passes actionlint with exit code 0" {
        $result = & actionlint $script:WorkflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

# ---------------------------------------------------------------------------
# Full aggregation test: all 4 fixture files (2 JUnit XML + 2 JSON)
# Expected totals: 14 total, 8 passed, 4 failed, 2 skipped, 7.20s
# Flaky: ApiTests.TestGetUsers, Suite1.TestLogout
# ---------------------------------------------------------------------------
Describe "Full Aggregation via Act" {
    BeforeAll {
        $tempDir = New-TempActRepo -FixtureFiles @(
            "junit-run1.xml",
            "junit-run2.xml",
            "json-run1.json",
            "json-run2.json"
        )

        $result = Invoke-ActPush -RepoDir $tempDir

        $script:fullOutput   = $result.Output
        $script:fullExitCode = $result.ExitCode

        # Append output to act-result.txt
        "=== Full Aggregation Test ===" | Add-Content $script:ActResultFile
        $script:fullOutput | Add-Content $script:ActResultFile

        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "act exits with code 0" {
        $script:fullExitCode | Should -Be 0
    }

    It "job shows succeeded" {
        $script:fullOutput | Should -Match "Job succeeded"
    }

    It "reports exactly 14 total tests" {
        $script:fullOutput | Should -Match '\| Total \| 14 \|'
    }

    It "reports exactly 8 passed tests" {
        $script:fullOutput | Should -Match '\| Passed \| 8 \|'
    }

    It "reports exactly 4 failed tests" {
        $script:fullOutput | Should -Match '\| Failed \| 4 \|'
    }

    It "reports exactly 2 skipped tests" {
        $script:fullOutput | Should -Match '\| Skipped \| 2 \|'
    }

    It "reports exactly 7.20s total duration" {
        $script:fullOutput | Should -Match '\| Duration \| 7\.20s \|'
    }

    It "identifies ApiTests.TestGetUsers as flaky" {
        $script:fullOutput | Should -Match 'ApiTests\.TestGetUsers \| 1 \| 1'
    }

    It "identifies Suite1.TestLogout as flaky" {
        $script:fullOutput | Should -Match 'Suite1\.TestLogout \| 1 \| 1'
    }

    It "shows per-file breakdown for junit-run1.xml with exact values" {
        $script:fullOutput | Should -Match 'junit-run1\.xml \| 4 \| 2 \| 1 \| 1 \| 2\.50s'
    }

    It "shows per-file breakdown for junit-run2.xml with exact values" {
        $script:fullOutput | Should -Match 'junit-run2\.xml \| 4 \| 3 \| 0 \| 1 \| 2\.60s'
    }

    It "shows per-file breakdown for json-run1.json with exact values" {
        $script:fullOutput | Should -Match 'json-run1\.json \| 3 \| 2 \| 1 \| 0 \| 0\.90s'
    }

    It "shows per-file breakdown for json-run2.json with exact values" {
        $script:fullOutput | Should -Match 'json-run2\.json \| 3 \| 1 \| 2 \| 0 \| 1\.20s'
    }
}

# ---------------------------------------------------------------------------
# JUnit-only aggregation test: only the 2 JUnit XML fixture files
# Expected totals: 8 total, 5 passed, 1 failed, 2 skipped, 5.10s
# Flaky: Suite1.TestLogout
# ---------------------------------------------------------------------------
Describe "JUnit-Only Aggregation via Act" {
    BeforeAll {
        $tempDir = New-TempActRepo -FixtureFiles @(
            "junit-run1.xml",
            "junit-run2.xml"
        )

        $result = Invoke-ActPush -RepoDir $tempDir

        $script:junitOutput   = $result.Output
        $script:junitExitCode = $result.ExitCode

        # Append output to act-result.txt
        "`n=== JUnit-Only Aggregation Test ===" | Add-Content $script:ActResultFile
        $script:junitOutput | Add-Content $script:ActResultFile

        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "act exits with code 0" {
        $script:junitExitCode | Should -Be 0
    }

    It "job shows succeeded" {
        $script:junitOutput | Should -Match "Job succeeded"
    }

    It "reports exactly 8 total tests" {
        $script:junitOutput | Should -Match '\| Total \| 8 \|'
    }

    It "reports exactly 5 passed tests" {
        $script:junitOutput | Should -Match '\| Passed \| 5 \|'
    }

    It "reports exactly 1 failed test" {
        $script:junitOutput | Should -Match '\| Failed \| 1 \|'
    }

    It "reports exactly 2 skipped tests" {
        $script:junitOutput | Should -Match '\| Skipped \| 2 \|'
    }

    It "reports exactly 5.10s total duration" {
        $script:junitOutput | Should -Match '\| Duration \| 5\.10s \|'
    }

    It "identifies Suite1.TestLogout as flaky" {
        $script:junitOutput | Should -Match 'Suite1\.TestLogout \| 1 \| 1'
    }

    It "does not list ApiTests.TestGetUsers (no JSON files)" {
        $script:junitOutput | Should -Not -Match 'ApiTests\.TestGetUsers'
    }

    It "shows per-file breakdown for junit-run1.xml" {
        $script:junitOutput | Should -Match 'junit-run1\.xml \| 4 \| 2 \| 1 \| 1 \| 2\.50s'
    }

    It "shows per-file breakdown for junit-run2.xml" {
        $script:junitOutput | Should -Match 'junit-run2\.xml \| 4 \| 3 \| 0 \| 1 \| 2\.60s'
    }
}

# ---------------------------------------------------------------------------
# JSON-only aggregation test: only the 2 JSON fixture files
# Expected totals: 6 total, 3 passed, 3 failed, 0 skipped, 2.10s
# Flaky: ApiTests.TestGetUsers
# ---------------------------------------------------------------------------
Describe "JSON-Only Aggregation via Act" {
    BeforeAll {
        $tempDir = New-TempActRepo -FixtureFiles @(
            "json-run1.json",
            "json-run2.json"
        )

        $result = Invoke-ActPush -RepoDir $tempDir

        $script:jsonOutput   = $result.Output
        $script:jsonExitCode = $result.ExitCode

        # Append output to act-result.txt
        "`n=== JSON-Only Aggregation Test ===" | Add-Content $script:ActResultFile
        $script:jsonOutput | Add-Content $script:ActResultFile

        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "act exits with code 0" {
        $script:jsonExitCode | Should -Be 0
    }

    It "job shows succeeded" {
        $script:jsonOutput | Should -Match "Job succeeded"
    }

    It "reports exactly 6 total tests" {
        $script:jsonOutput | Should -Match '\| Total \| 6 \|'
    }

    It "reports exactly 3 passed tests" {
        $script:jsonOutput | Should -Match '\| Passed \| 3 \|'
    }

    It "reports exactly 3 failed tests" {
        $script:jsonOutput | Should -Match '\| Failed \| 3 \|'
    }

    It "reports exactly 0 skipped tests" {
        $script:jsonOutput | Should -Match '\| Skipped \| 0 \|'
    }

    It "reports exactly 2.10s total duration" {
        $script:jsonOutput | Should -Match '\| Duration \| 2\.10s \|'
    }

    It "identifies ApiTests.TestGetUsers as flaky" {
        $script:jsonOutput | Should -Match 'ApiTests\.TestGetUsers \| 1 \| 1'
    }

    It "does not list Suite1.TestLogout (no JUnit files)" {
        $script:jsonOutput | Should -Not -Match 'Suite1\.TestLogout'
    }
}

AfterAll {
    # Verify act-result.txt was written
    if (Test-Path $script:ActResultFile) {
        $size = (Get-Item $script:ActResultFile).Length
        Write-Host "act-result.txt written ($size bytes)"
    }
    else {
        Write-Warning "act-result.txt was not created!"
    }
}
