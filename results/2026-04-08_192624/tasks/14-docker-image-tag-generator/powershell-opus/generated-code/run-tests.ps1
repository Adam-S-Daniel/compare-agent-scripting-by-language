#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test harness that runs all Docker image tag generator tests through act (GitHub Actions).
    Each test case sets up a temp git repo, runs act, captures output, and asserts results.

.DESCRIPTION
    This script:
    1. Validates the workflow YAML structure
    2. Validates actionlint passes
    3. For each test case: creates a temp git repo with fixtures, runs act, parses output
    4. Saves all output to act-result.txt
    5. Asserts exact expected values in act output
#>

$ErrorActionPreference = "Stop"
$ResultFile = Join-Path $PSScriptRoot "act-result.txt"
$WorkflowFile = ".github/workflows/docker-image-tag-generator.yml"
$SourceDir = $PSScriptRoot

# Clear result file
"" | Set-Content $ResultFile

# Helper: append to result file
function Write-Result {
    param([string]$Text)
    $Text | Out-File -FilePath $ResultFile -Append
    Write-Host $Text
}

# Track test results
$totalTests = 0
$passedTests = 0
$failedTests = @()

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    $script:totalTests++
    if ($Condition) {
        $script:passedTests++
        Write-Result "  PASS: $Message"
    }
    else {
        $script:failedTests += $Message
        Write-Result "  FAIL: $Message"
    }
}

# ============================================================
# SECTION 1: Workflow structure tests (YAML parsing)
# ============================================================
Write-Result "=" * 70
Write-Result "WORKFLOW STRUCTURE TESTS"
Write-Result "=" * 70

# Test: Workflow YAML exists
$workflowPath = Join-Path $SourceDir $WorkflowFile
Assert-True -Condition (Test-Path $workflowPath) -Message "Workflow YAML file exists at $WorkflowFile"

# Test: Parse YAML and check structure
if (Test-Path $workflowPath) {
    $yamlContent = Get-Content $workflowPath -Raw

    # Test: Has expected triggers
    Assert-True -Condition ($yamlContent -match "on:") -Message "Workflow has 'on' trigger section"
    Assert-True -Condition ($yamlContent -match "push:") -Message "Workflow has 'push' trigger"
    Assert-True -Condition ($yamlContent -match "pull_request:") -Message "Workflow has 'pull_request' trigger"
    Assert-True -Condition ($yamlContent -match "workflow_dispatch:") -Message "Workflow has 'workflow_dispatch' trigger"

    # Test: Has expected jobs
    Assert-True -Condition ($yamlContent -match "jobs:") -Message "Workflow has 'jobs' section"
    Assert-True -Condition ($yamlContent -match "generate-tags:") -Message "Workflow has 'generate-tags' job"

    # Test: Has checkout step
    Assert-True -Condition ($yamlContent -match "actions/checkout@v4") -Message "Workflow uses actions/checkout@v4"

    # Test: References our script
    Assert-True -Condition ($yamlContent -match "docker-image-tag-generator\.ps1") -Message "Workflow references docker-image-tag-generator.ps1"
    Assert-True -Condition (Test-Path (Join-Path $SourceDir "docker-image-tag-generator.ps1")) -Message "Script file docker-image-tag-generator.ps1 exists"

    # Test: References test file
    Assert-True -Condition ($yamlContent -match "docker-image-tag-generator\.Tests\.ps1") -Message "Workflow references test file"
    Assert-True -Condition (Test-Path (Join-Path $SourceDir "docker-image-tag-generator.Tests.ps1")) -Message "Test file docker-image-tag-generator.Tests.ps1 exists"

    # Test: Has permissions
    Assert-True -Condition ($yamlContent -match "permissions:") -Message "Workflow has permissions section"
}

# Test: actionlint passes
Write-Result ""
Write-Result "Running actionlint..."
$actionlintResult = & actionlint $workflowPath 2>&1
$actionlintExitCode = $LASTEXITCODE
Assert-True -Condition ($actionlintExitCode -eq 0) -Message "actionlint passes with exit code 0"
if ($actionlintExitCode -ne 0) {
    Write-Result "  actionlint errors: $actionlintResult"
}

# ============================================================
# SECTION 2: Act integration tests
# ============================================================
Write-Result ""
Write-Result "=" * 70
Write-Result "ACT INTEGRATION TESTS"
Write-Result "=" * 70

# Define test cases: each has a description, env overrides, and expected tags
$testCases = @(
    @{
        Name           = "Main branch produces 'latest' tag"
        BranchName     = "main"
        CommitSha      = "abc1234def5678901234567890abcdef12345678"
        Tag            = ""
        PrNumber       = ""
        ExpectedTags   = @("latest")
        UnexpectedTags = @("main-abc1234")
    },
    @{
        Name           = "Feature branch produces branch-sha tag"
        BranchName     = "feature/cool-thing"
        CommitSha      = "deadbeef12345678901234567890abcdef123456"
        Tag            = ""
        PrNumber       = ""
        ExpectedTags   = @("feature-cool-thing-deadbee")
        UnexpectedTags = @("latest")
    },
    @{
        Name           = "PR produces pr-number tag"
        BranchName     = "feature/test-pr"
        CommitSha      = "cafebabe12345678901234567890abcdef123456"
        Tag            = ""
        PrNumber       = "42"
        ExpectedTags   = @("pr-42", "feature-test-pr-cafebab")
        UnexpectedTags = @("latest")
    },
    @{
        Name           = "Semver tag produces version tags"
        BranchName     = "main"
        CommitSha      = "1111111122222222333333334444444455555555"
        Tag            = "v2.5.1"
        PrNumber       = ""
        ExpectedTags   = @("v2.5.1", "v2.5", "v2", "latest")
        UnexpectedTags = @()
    },
    @{
        Name           = "Master branch produces 'latest' tag"
        BranchName     = "master"
        CommitSha      = "aabbccdd12345678901234567890abcdef123456"
        Tag            = ""
        PrNumber       = ""
        ExpectedTags   = @("latest")
        UnexpectedTags = @("master-aabbccd")
    },
    @{
        Name           = "Branch name sanitization (uppercase and special chars)"
        BranchName     = "Feature/MY_Branch"
        CommitSha      = "ffee1234567890abcdef1234567890abcdef1234"
        Tag            = ""
        PrNumber       = ""
        ExpectedTags   = @("feature-my-branch-ffee123")
        UnexpectedTags = @("latest")
    }
)

foreach ($tc in $testCases) {
    Write-Result ""
    Write-Result "-" * 70
    Write-Result "TEST: $($tc.Name)"
    Write-Result "-" * 70

    # Create a temporary directory for this test case
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "act-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        # Initialize a git repo in the temp directory
        Push-Location $tempDir
        & git init -b main 2>&1 | Out-Null
        & git config user.email "test@test.com" 2>&1 | Out-Null
        & git config user.name "Test" 2>&1 | Out-Null

        # Copy project files into temp repo
        Copy-Item (Join-Path $SourceDir "docker-image-tag-generator.ps1") $tempDir
        Copy-Item (Join-Path $SourceDir "docker-image-tag-generator.Tests.ps1") $tempDir

        # Create workflow directory and copy workflow
        $wfDir = Join-Path $tempDir ".github" "workflows"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        Copy-Item (Join-Path $SourceDir $WorkflowFile) $wfDir

        # Commit files so checkout works
        & git add -A 2>&1 | Out-Null
        & git commit -m "initial" 2>&1 | Out-Null

        # Build the act command with environment variables to override inputs
        # We use env vars since workflow_dispatch inputs don't work well with act push
        $envArgs = @(
            "-e", "/dev/null"
        )

        # Set the environment variables that the workflow uses
        $envVars = @(
            "--env", "INPUT_BRANCH_NAME=$($tc.BranchName)",
            "--env", "INPUT_COMMIT_SHA=$($tc.CommitSha)",
            "--env", "INPUT_TAG=$($tc.Tag)",
            "--env", "INPUT_PR_NUMBER=$($tc.PrNumber)"
        )

        Write-Result "  Running act push --rm in $tempDir"
        $actOutput = & act push --rm $envArgs $envVars 2>&1 | Out-String
        $actExitCode = $LASTEXITCODE

        Write-Result "  Act exit code: $actExitCode"
        Write-Result ""
        Write-Result "  --- ACT OUTPUT START ---"
        Write-Result $actOutput
        Write-Result "  --- ACT OUTPUT END ---"

        # Assert: act exited with code 0
        Assert-True -Condition ($actExitCode -eq 0) -Message "[$($tc.Name)] act exited with code 0"

        # Assert: Job succeeded
        Assert-True -Condition ($actOutput -match "Job succeeded") -Message "[$($tc.Name)] Job succeeded message present"

        # Assert: Expected tags are present in output
        foreach ($expectedTag in $tc.ExpectedTags) {
            $found = $actOutput -match [regex]::Escape($expectedTag)
            Assert-True -Condition $found -Message "[$($tc.Name)] Output contains expected tag '$expectedTag'"
        }

        # Assert: Unexpected tags are NOT present
        foreach ($unexpectedTag in $tc.UnexpectedTags) {
            # Check specifically in the TAG_LIST line to avoid false positives from other output
            $tagListMatch = [regex]::Match($actOutput, "TAG_LIST=(.+)")
            if ($tagListMatch.Success) {
                $tagListValue = $tagListMatch.Groups[1].Value
                $found = $tagListValue -match [regex]::Escape($unexpectedTag)
                Assert-True -Condition (-not $found) -Message "[$($tc.Name)] TAG_LIST does not contain unexpected tag '$unexpectedTag'"
            }
        }
    }
    catch {
        Write-Result "  ERROR: $($_.Exception.Message)"
        $script:totalTests++
        $script:failedTests += "[$($tc.Name)] Exception: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
        # Clean up temp directory
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    }
}

# ============================================================
# SUMMARY
# ============================================================
Write-Result ""
Write-Result "=" * 70
Write-Result "TEST SUMMARY"
Write-Result "=" * 70
Write-Result "Total: $totalTests | Passed: $passedTests | Failed: $($failedTests.Count)"
Write-Result ""

if ($failedTests.Count -gt 0) {
    Write-Result "Failed tests:"
    foreach ($ft in $failedTests) {
        Write-Result "  - $ft"
    }
    exit 1
}
else {
    Write-Result "All tests passed!"
    exit 0
}
