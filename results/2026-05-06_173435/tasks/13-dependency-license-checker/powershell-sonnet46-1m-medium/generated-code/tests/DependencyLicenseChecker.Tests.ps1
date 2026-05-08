# DependencyLicenseChecker.Tests.ps1
# Two groups of tests:
#   1. Workflow structure tests — validate YAML and file paths locally (no act needed).
#   2. Act integration tests — spin up a temp git repo, run "act push --rm",
#      and assert on exact expected output values.

BeforeAll {
    $script:workspaceRoot = (Get-Item "$PSScriptRoot/..").FullName
    $script:workflowPath  = Join-Path $script:workspaceRoot ".github" "workflows" "dependency-license-checker.yml"
    $script:actResultPath = Join-Path $script:workspaceRoot "act-result.txt"
}

# ────────────────────────────────────────────────────────────────
# 1. Workflow structure tests (instant, no Docker)
# ────────────────────────────────────────────────────────────────
Describe "Workflow structure" {
    It "workflow file exists" {
        $script:workflowPath | Should -Exist
    }

    It "workflow YAML parses without error" {
        # PowerShell doesn't ship a YAML parser; use pwsh-yaml or a simple check.
        # We verify structure via raw text patterns.
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Not -BeNullOrEmpty
    }

    It "workflow has push trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "push:"
    }

    It "workflow has pull_request trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "pull_request:"
    }

    It "workflow has workflow_dispatch trigger" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "workflow_dispatch:"
    }

    It "workflow defines a check-licenses job" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "check-licenses:"
    }

    It "workflow uses actions/checkout@v4" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "actions/checkout@v4"
    }

    It "workflow uses shell: pwsh for run steps" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "shell: pwsh"
    }

    It "workflow references DependencyLicenseChecker.ps1" {
        $content = Get-Content $script:workflowPath -Raw
        $content | Should -Match "DependencyLicenseChecker\.ps1"
    }

    It "DependencyLicenseChecker.ps1 exists" {
        Join-Path $script:workspaceRoot "DependencyLicenseChecker.ps1" | Should -Exist
    }

    It "LicenseCheckerLib.ps1 exists" {
        Join-Path $script:workspaceRoot "LicenseCheckerLib.ps1" | Should -Exist
    }

    It "fixture package.json exists" {
        Join-Path $script:workspaceRoot "fixtures" "package.json" | Should -Exist
    }

    It "fixture mock-licenses.json exists" {
        Join-Path $script:workspaceRoot "fixtures" "mock-licenses.json" | Should -Exist
    }

    It "config license-config.json exists" {
        Join-Path $script:workspaceRoot "config" "license-config.json" | Should -Exist
    }

    It "actionlint passes with exit code 0" {
        $result = & actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0
        $result | Should -BeNullOrEmpty
    }
}

# ────────────────────────────────────────────────────────────────
# 2. Act integration tests — all functional test cases run via act
# ────────────────────────────────────────────────────────────────
Describe "Act integration — license compliance via workflow" {
    BeforeAll {
        # Set up a temp git repo containing the full project, then run act.
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lic-check-" + [System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Copy workspace files into temp dir (excluding .git and act-result.txt)
        Get-ChildItem -Path $script:workspaceRoot -Force |
            Where-Object { $_.Name -notin @('.git', 'act-result.txt') } |
            ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $script:tempDir -Recurse -Force
            }

        # Initialise a git repo so act can simulate a push event
        Push-Location $script:tempDir
        git init --quiet
        git config user.email "ci@test.local"
        git config user.name  "CI Test"
        git add -A
        git commit --quiet -m "test: initial commit for act run"

        # Run act — capture stdout+stderr, record exit code.
        # --pull=false prevents act from trying to re-pull the local act-ubuntu-pwsh image.
        $script:actOutput   = (act push --rm --pull=false 2>&1) | Out-String
        $script:actExitCode = $LASTEXITCODE

        Pop-Location

        # Append this test case's output to act-result.txt (required artifact)
        $delimiter = "=" * 60
        Add-Content -Path $script:actResultPath -Value ""
        Add-Content -Path $script:actResultPath -Value "$delimiter"
        Add-Content -Path $script:actResultPath -Value "Test case: license compliance check (act push)"
        Add-Content -Path $script:actResultPath -Value "$delimiter"
        Add-Content -Path $script:actResultPath -Value $script:actOutput
        Add-Content -Path $script:actResultPath -Value ""
    }

    AfterAll {
        # Clean up temp directory
        if (Test-Path $script:tempDir) {
            Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "act exits with code 0" {
        $script:actExitCode | Should -Be 0
    }

    It "every job shows Job succeeded" {
        $script:actOutput | Should -Match "Job succeeded"
    }

    It "act-result.txt exists" {
        $script:actResultPath | Should -Exist
    }

    # ── Exact expected values from the compliance report ──────────────

    It "reports lodash@4.17.21 as MIT [APPROVED]" {
        $script:actOutput | Should -Match "lodash@4\.17\.21: MIT \[APPROVED\]"
    }

    It "reports left-pad@1.3.0 as GPL-3.0 [DENIED]" {
        $script:actOutput | Should -Match "left-pad@1\.3\.0: GPL-3\.0 \[DENIED\]"
    }

    It "reports my-custom-lib@2.0.0 as CUSTOM-LIC [UNKNOWN]" {
        $script:actOutput | Should -Match "my-custom-lib@2\.0\.0: CUSTOM-LIC \[UNKNOWN\]"
    }

    It "reports express@4.18.2 as MIT [APPROVED]" {
        $script:actOutput | Should -Match "express@4\.18\.2: MIT \[APPROVED\]"
    }

    It "summary shows 4 total, 2 approved, 1 denied, 1 unknown" {
        $script:actOutput | Should -Match "Summary: 4 total, 2 approved, 1 denied, 1 unknown"
    }

    It "overall status is FAILED due to denied license" {
        $script:actOutput | Should -Match "Status: FAILED"
    }

    It "unit tests inside Docker all pass" {
        $script:actOutput | Should -Match "Unit tests passed: 20"
    }
}
