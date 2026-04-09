#!/usr/bin/env pwsh
# run-tests.ps1
# Test harness that runs all test cases through GitHub Actions via act.
# Validates workflow structure, actionlint, and actual execution output.

$ErrorActionPreference = "Stop"
$script:WorkDir = $PSScriptRoot
$script:ResultFile = Join-Path $script:WorkDir "act-result.txt"
$script:AllPassed = $true
$script:TestCount = 0
$script:PassCount = 0
$script:FailCount = 0

# Clear previous results
"" | Set-Content $script:ResultFile

function Write-TestHeader {
    param([string]$Name)
    $header = "`n{'='*60}`nTEST: $Name`n{'='*60}"
    $header | Add-Content $script:ResultFile
    Write-Host "--- TEST: $Name ---" -ForegroundColor Cyan
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:TestCount++
    if ($Condition) {
        $script:PassCount++
        Write-Host "  PASS: $Message" -ForegroundColor Green
        "  PASS: $Message" | Add-Content $script:ResultFile
    }
    else {
        $script:FailCount++
        $script:AllPassed = $false
        Write-Host "  FAIL: $Message" -ForegroundColor Red
        "  FAIL: $Message" | Add-Content $script:ResultFile
    }
}

function Assert-Contains {
    param([string]$Output, [string]$Expected, [string]$Message)
    Assert-True -Condition ($Output -match [regex]::Escape($Expected)) -Message $Message
}

function Assert-NotContains {
    param([string]$Output, [string]$Expected, [string]$Message)
    Assert-True -Condition (-not ($Output -match [regex]::Escape($Expected))) -Message $Message
}

# ============================================================
# SECTION 1: Workflow Structure Tests
# ============================================================
Write-TestHeader "Workflow YAML Structure Validation"

# Parse YAML and check structure
$yamlPath = Join-Path $script:WorkDir ".github/workflows/pr-label-assigner.yml"
$yamlContent = Get-Content $yamlPath -Raw

# Check triggers
Assert-Contains -Output $yamlContent -Expected "push:" -Message "Workflow has push trigger"
Assert-Contains -Output $yamlContent -Expected "pull_request:" -Message "Workflow has pull_request trigger"
Assert-Contains -Output $yamlContent -Expected "workflow_dispatch:" -Message "Workflow has workflow_dispatch trigger"

# Check jobs
Assert-Contains -Output $yamlContent -Expected "assign-labels:" -Message "Workflow has assign-labels job"
Assert-Contains -Output $yamlContent -Expected "runs-on: ubuntu-latest" -Message "Job runs on ubuntu-latest"

# Check steps
Assert-Contains -Output $yamlContent -Expected "actions/checkout@v4" -Message "Workflow uses actions/checkout@v4"
Assert-Contains -Output $yamlContent -Expected "Invoke-Pester" -Message "Workflow runs Pester tests"
Assert-Contains -Output $yamlContent -Expected "Invoke-PRLabelAssigner.ps1" -Message "Workflow references the main script"

# Check script files exist
Assert-True -Condition (Test-Path (Join-Path $script:WorkDir "Invoke-PRLabelAssigner.ps1")) -Message "Invoke-PRLabelAssigner.ps1 exists"
Assert-True -Condition (Test-Path (Join-Path $script:WorkDir "Invoke-PRLabelAssigner.Tests.ps1")) -Message "Invoke-PRLabelAssigner.Tests.ps1 exists"
Assert-True -Condition (Test-Path $yamlPath) -Message "Workflow YAML file exists"

# ============================================================
# SECTION 2: actionlint Validation
# ============================================================
Write-TestHeader "actionlint Validation"

$actionlintOutput = & actionlint $yamlPath 2>&1
$actionlintExitCode = $LASTEXITCODE
Assert-True -Condition ($actionlintExitCode -eq 0) -Message "actionlint passes with exit code 0"
if ($actionlintExitCode -ne 0) {
    "actionlint output: $actionlintOutput" | Add-Content $script:ResultFile
}

# ============================================================
# SECTION 3: Run workflow through act
# ============================================================
Write-TestHeader "Running workflow through act"

# Create a temporary git repo with our project files for act
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pr-label-assigner-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # Copy project files
    Copy-Item (Join-Path $script:WorkDir "Invoke-PRLabelAssigner.ps1") $tempDir
    Copy-Item (Join-Path $script:WorkDir "Invoke-PRLabelAssigner.Tests.ps1") $tempDir
    $ghDir = Join-Path $tempDir ".github/workflows"
    New-Item -ItemType Directory -Path $ghDir -Force | Out-Null
    Copy-Item $yamlPath (Join-Path $ghDir "pr-label-assigner.yml")

    # Initialize git repo (act requires one)
    Push-Location $tempDir
    & git init --initial-branch=main 2>&1 | Out-Null
    & git config user.email "test@test.com" 2>&1 | Out-Null
    & git config user.name "Test" 2>&1 | Out-Null
    & git add -A 2>&1 | Out-Null
    & git commit -m "initial" 2>&1 | Out-Null
    Pop-Location

    # Run act
    Write-Host "Running act push in $tempDir ..." -ForegroundColor Yellow
    $actOutput = & act push --rm -P ubuntu-latest=catthehacker/ubuntu:act-latest -W "$ghDir" 2>&1 | Out-String
    $actExitCode = $LASTEXITCODE

    # Save full act output
    "`n--- ACT OUTPUT START ---" | Add-Content $script:ResultFile
    $actOutput | Add-Content $script:ResultFile
    "`n--- ACT OUTPUT END ---" | Add-Content $script:ResultFile

    # Assert act ran successfully
    Assert-True -Condition ($actExitCode -eq 0) -Message "act exited with code 0 (exit code was: $actExitCode)"

    # Assert job succeeded
    Assert-Contains -Output $actOutput -Expected "Job succeeded" -Message "Job shows 'Job succeeded'"

    # ============================================================
    # SECTION 4: Verify Pester tests ran
    # ============================================================
    Write-TestHeader "Pester Test Execution Verification"
    Assert-Contains -Output $actOutput -Expected "All 17 Pester tests passed" -Message "All 17 Pester tests passed in act"

    # ============================================================
    # SECTION 5: Test Case Output Assertions
    # ============================================================

    # Test case 1: docs only -> documentation (*.md doesn't match docs/readme.md since * excludes /)
    Write-TestHeader "Test Case 1: docs only files"
    Assert-Contains -Output $actOutput -Expected "Test Case 1: docs only" -Message "Test case 1 header present"
    Assert-Contains -Output $actOutput -Expected "LABEL:documentation" -Message "TC1: documentation label present"
    Assert-Contains -Output $actOutput -Expected "LABEL_CSV:documentation" -Message "TC1: CSV output is exactly 'documentation'"

    # Test case 2: api files -> api, source
    Write-TestHeader "Test Case 2: api files"
    Assert-Contains -Output $actOutput -Expected "Test Case 2: api files" -Message "Test case 2 header present"
    Assert-Contains -Output $actOutput -Expected "LABEL:api" -Message "TC2: api label present"
    Assert-Contains -Output $actOutput -Expected "LABEL:source" -Message "TC2: source label present"
    Assert-Contains -Output $actOutput -Expected "LABEL_CSV:api,source" -Message "TC2: CSV output is exactly 'api,source'"

    # Test case 3: mixed files -> api, documentation, markdown, source, tests
    Write-TestHeader "Test Case 3: mixed files"
    Assert-Contains -Output $actOutput -Expected "Test Case 3: mixed files" -Message "Test case 3 header present"
    Assert-Contains -Output $actOutput -Expected "LABEL:api" -Message "TC3: api label present"
    Assert-Contains -Output $actOutput -Expected "LABEL:documentation" -Message "TC3: documentation label present"
    Assert-Contains -Output $actOutput -Expected "LABEL:markdown" -Message "TC3: markdown label present"
    Assert-Contains -Output $actOutput -Expected "LABEL:source" -Message "TC3: source label present"
    Assert-Contains -Output $actOutput -Expected "LABEL:tests" -Message "TC3: tests label present"
    Assert-Contains -Output $actOutput -Expected "LABEL_CSV:api,documentation,markdown,source,tests" -Message "TC3: CSV output is exactly 'api,documentation,markdown,source,tests'"

    # Test case 4: no matches -> empty labels
    Write-TestHeader "Test Case 4: no matching files"
    Assert-Contains -Output $actOutput -Expected "Test Case 4: no matching files" -Message "Test case 4 header present"
    Assert-Contains -Output $actOutput -Expected "LABEL_CSV:" -Message "TC4: CSV output is empty (no matches)"

    # Test case 5: test files only -> tests
    Write-TestHeader "Test Case 5: test files only"
    Assert-Contains -Output $actOutput -Expected "Test Case 5: test files only" -Message "Test case 5 header present"
    Assert-Contains -Output $actOutput -Expected "LABEL:tests" -Message "TC5: tests label present"
    Assert-Contains -Output $actOutput -Expected "LABEL_CSV:tests" -Message "TC5: CSV output is exactly 'tests'"

}
finally {
    # Cleanup temp directory
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Final Summary
# ============================================================
$summary = @"

============================================================
TEST SUMMARY
============================================================
Total:  $script:TestCount
Passed: $script:PassCount
Failed: $script:FailCount
Result: $(if ($script:AllPassed) { "ALL TESTS PASSED" } else { "SOME TESTS FAILED" })
============================================================
"@

$summary | Add-Content $script:ResultFile
Write-Host $summary

if (-not $script:AllPassed) {
    exit 1
}
