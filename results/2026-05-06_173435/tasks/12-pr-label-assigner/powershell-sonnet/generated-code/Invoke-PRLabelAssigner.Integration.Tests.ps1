# Invoke-PRLabelAssigner.Integration.Tests.ps1
# Integration test harness: validates workflow structure and drives `act push --rm`.
#
# These tests run LOCALLY only (not inside the GitHub Actions container) because
# they invoke `act` and `actionlint`, which are not available inside the runner.
#
# Run with: Invoke-Pester ./Invoke-PRLabelAssigner.Integration.Tests.ps1 -Output Detailed

# ---------------------------------------------------------------------------
# Workflow Structure Tests (no act required)
# ---------------------------------------------------------------------------
Describe "Workflow Structure Tests" {
    BeforeAll {
        $script:workingDir      = $PSScriptRoot
        $script:workflowPath    = Join-Path $PSScriptRoot ".github/workflows/pr-label-assigner.yml"
        $script:workflowContent = Get-Content $script:workflowPath -Raw -ErrorAction SilentlyContinue
    }

    It "workflow file exists at .github/workflows/pr-label-assigner.yml" {
        Test-Path $script:workflowPath | Should -Be $true
    }

    It "workflow has 'push' trigger" {
        $script:workflowContent | Should -Match 'push'
    }

    It "workflow has 'pull_request' trigger" {
        $script:workflowContent | Should -Match 'pull_request'
    }

    It "workflow has 'workflow_dispatch' trigger" {
        $script:workflowContent | Should -Match 'workflow_dispatch'
    }

    It "workflow has 'schedule' trigger" {
        $script:workflowContent | Should -Match 'schedule'
    }

    It "workflow has at least one job" {
        $script:workflowContent | Should -Match 'jobs:'
    }

    It "workflow job uses ubuntu-latest runner" {
        $script:workflowContent | Should -Match 'ubuntu-latest'
    }

    It "workflow uses actions/checkout@v4" {
        $script:workflowContent | Should -Match 'actions/checkout@v4'
    }

    It "workflow uses 'shell: pwsh' for PowerShell steps" {
        $script:workflowContent | Should -Match 'shell:\s*pwsh'
    }

    It "workflow references Invoke-PRLabelAssigner.ps1" {
        $script:workflowContent | Should -Match 'Invoke-PRLabelAssigner\.ps1'
    }

    It "workflow has permissions block" {
        $script:workflowContent | Should -Match 'permissions:'
    }

    It "source script file Invoke-PRLabelAssigner.ps1 exists" {
        Test-Path (Join-Path $script:workingDir "Invoke-PRLabelAssigner.ps1") | Should -Be $true
    }

    It "unit test file Invoke-PRLabelAssigner.Tests.ps1 exists" {
        Test-Path (Join-Path $script:workingDir "Invoke-PRLabelAssigner.Tests.ps1") | Should -Be $true
    }

    It "workflow references all five test cases" {
        $script:workflowContent | Should -Match 'TC1'
        $script:workflowContent | Should -Match 'TC2'
        $script:workflowContent | Should -Match 'TC3'
        $script:workflowContent | Should -Match 'TC4'
        $script:workflowContent | Should -Match 'TC5'
    }

    It "actionlint passes with exit code 0" {
        $output = & actionlint $script:workflowPath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "actionlint errors: $($output -join '; ')"
    }
}

# ---------------------------------------------------------------------------
# Integration Tests via act
# Runs act push --rm ONCE; all assertions share the captured output.
# ---------------------------------------------------------------------------
Describe "Integration Tests via act" {
    BeforeAll {
        $actResultFile = Join-Path $PSScriptRoot "act-result.txt"
        Push-Location $PSScriptRoot
        try {
            Write-Host "Running: act push --rm --pull=false (this may take 30-90 seconds)..."
            $script:actOutput   = & act push --rm --pull=false 2>&1
            $script:actExitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $delimiter = "=" * 70

        # Write act-result.txt — required artifact.
        $resultLines = @(
            $delimiter,
            "act push --rm run at $timestamp",
            "Exit Code: $($script:actExitCode)",
            $delimiter,
            ($script:actOutput -join "`n"),
            $delimiter,
            "End of act run",
            $delimiter
        )
        $resultLines -join "`n" | Set-Content -Path $actResultFile -Encoding utf8

        $script:actStr         = $script:actOutput -join "`n"
        $script:actResultFile  = $actResultFile
        Write-Host "act exit code: $($script:actExitCode)"
        Write-Host "act-result.txt written to: $actResultFile"
    }

    It "act exits with code 0" {
        $script:actExitCode | Should -Be 0 -Because "act-result.txt contains full output"
    }

    # TC1: Basic documentation label
    It "TC1 output shows TC1_LABELS=documentation" {
        $script:actStr | Should -Match "TC1_LABELS=documentation"
    }

    It "TC1 step shows PASS" {
        $script:actStr | Should -Match "TC1_RESULT=PASS"
    }

    # TC2: Multiple files, multiple labels (sorted: api,documentation)
    It "TC2 output shows TC2_LABELS=api,documentation" {
        $script:actStr | Should -Match "TC2_LABELS=api,documentation"
    }

    It "TC2 step shows PASS" {
        $script:actStr | Should -Match "TC2_RESULT=PASS"
    }

    # TC3: Glob pattern test files
    It "TC3 output shows TC3_LABELS=tests" {
        $script:actStr | Should -Match "TC3_LABELS=tests"
    }

    It "TC3 step shows PASS" {
        $script:actStr | Should -Match "TC3_RESULT=PASS"
    }

    # TC4: Multiple labels per file (sorted: api,tests)
    It "TC4 output shows TC4_LABELS=api,tests" {
        $script:actStr | Should -Match "TC4_LABELS=api,tests"
    }

    It "TC4 step shows PASS" {
        $script:actStr | Should -Match "TC4_RESULT=PASS"
    }

    # TC5: Priority ordering (sorted: api,backend; api is first by priority)
    It "TC5 output shows TC5_LABELS=api,backend" {
        $script:actStr | Should -Match "TC5_LABELS=api,backend"
    }

    It "TC5 output shows TC5_PRIORITY_FIRST=api (highest priority label first)" {
        $script:actStr | Should -Match "TC5_PRIORITY_FIRST=api"
    }

    It "TC5 step shows PASS" {
        $script:actStr | Should -Match "TC5_RESULT=PASS"
    }

    # Pester inside workflow
    It "workflow Pester step shows PESTER_RESULT=PASS" {
        $script:actStr | Should -Match "PESTER_RESULT=PASS"
    }

    It "workflow shows at least one 'Job succeeded'" {
        $script:actStr | Should -Match "Job succeeded"
    }

    It "act-result.txt file was created" {
        Test-Path $script:actResultFile | Should -Be $true
    }
}
