# Run-ActTests.ps1
# Act test harness for the PR Label Assigner workflow.
#
# This script:
#   1. Sets up a temporary git repo with all project files
#   2. Runs `act push --rm` once to execute the full workflow
#   3. Appends output to act-result.txt
#   4. Asserts exit code 0 and "Job succeeded"
#   5. Asserts EXACT expected label values for each integration test case

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$actResultPath = Join-Path $scriptDir "act-result.txt"
$failures = @()

# ---------------------------------------------------------------------------
# Helper: write a banner and append text to act-result.txt
# ---------------------------------------------------------------------------
function Write-Banner([string]$text) {
    $line = "=" * 70
    $banner = "`n$line`n  $text`n$line`n"
    Write-Host $banner
    Add-Content -Path $actResultPath -Value $banner
}

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        $script:failures += $message
        Write-Host "FAIL: $message" -ForegroundColor Red
    }
    else {
        Write-Host "PASS: $message" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Create a fresh act-result.txt
# ---------------------------------------------------------------------------
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Set-Content -Path $actResultPath -Value "PR Label Assigner - Act Test Results`nGenerated: $timestamp`n"

# ---------------------------------------------------------------------------
# Set up a temporary git repo with the project files
# ---------------------------------------------------------------------------
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "pr-label-assigner-act-$(Get-Random)"
Write-Host "Creating temp repo at: $tmpDir"
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    # Copy all project files (exclude act-result.txt and temp dirs)
    $filesToCopy = @(
        "Invoke-PRLabelAssigner.ps1"
        "PRLabelAssigner.Tests.ps1"
        "label-config.json"
        "Run-ActTests.ps1"
    )

    foreach ($file in $filesToCopy) {
        Copy-Item (Join-Path $scriptDir $file) (Join-Path $tmpDir $file)
    }

    # Copy .github directory structure
    $workflowSrc = Join-Path $scriptDir ".github"
    $workflowDst = Join-Path $tmpDir ".github"
    Copy-Item -Recurse $workflowSrc $workflowDst

    # Copy .actrc so act knows to use the custom image
    $actrcSrc = Join-Path $scriptDir ".actrc"
    if (Test-Path $actrcSrc) {
        Copy-Item $actrcSrc (Join-Path $tmpDir ".actrc")
    }

    # Initialize git repo
    Push-Location $tmpDir
    git init -b main 2>&1 | Out-Null
    git config user.email "test@example.com" 2>&1 | Out-Null
    git config user.name "Test" 2>&1 | Out-Null
    git add -A 2>&1 | Out-Null
    git commit -m "test: add PR label assigner" 2>&1 | Out-Null

    # ---------------------------------------------------------------------------
    # Run act push --rm (single run covers all test cases in the workflow)
    # ---------------------------------------------------------------------------
    Write-Banner "Running: act push --rm"

    $actOutput = & act push --rm --pull=false 2>&1
    $actExitCode = $LASTEXITCODE
    $actOutputStr = $actOutput -join "`n"

    # Append to act-result.txt
    Add-Content -Path $actResultPath -Value $actOutputStr

    Write-Host $actOutputStr

    # ---------------------------------------------------------------------------
    # Assertions
    # ---------------------------------------------------------------------------
    Write-Banner "Assertions"

    # 1. Act exited with code 0
    Assert-True ($actExitCode -eq 0) "act exited with code 0 (got $actExitCode)"

    # 2. Job succeeded
    Assert-True ($actOutputStr -match "Job succeeded") "Output contains 'Job succeeded'"

    # 3. Pester tests passed (no failed count > 0)
    Assert-True ($actOutputStr -notmatch "Tests Passed.*Failed: [1-9]") "Pester reports 0 failures"

    # 4. Integration test case expected outputs (exact values)
    # Test case 1: docs/README.md -> documentation
    Assert-True ($actOutputStr -match [regex]::Escape("TEST_CASE_1_LABELS: documentation")) `
        "Test case 1: docs/README.md -> 'documentation'"

    # Test case 2: src/api/users.js -> api, backend
    Assert-True ($actOutputStr -match [regex]::Escape("TEST_CASE_2_LABELS: api, backend")) `
        "Test case 2: src/api/users.js -> 'api, backend'"

    # Test case 3: src/api/users.test.js -> api, tests, backend
    Assert-True ($actOutputStr -match [regex]::Escape("TEST_CASE_3_LABELS: api, tests, backend")) `
        "Test case 3: src/api/users.test.js -> 'api, tests, backend'"

    # Test case 4: .github/workflows/ci.yml -> ci/cd
    Assert-True ($actOutputStr -match [regex]::Escape("TEST_CASE_4_LABELS: ci/cd")) `
        "Test case 4: .github/workflows/ci.yml -> 'ci/cd'"

    # Test case 5: random-file.txt -> (none)
    Assert-True ($actOutputStr -match [regex]::Escape("TEST_CASE_5_LABELS: (none)")) `
        "Test case 5: random-file.txt -> '(none)'"

    # 5. Integration tests completion marker
    Assert-True ($actOutputStr -match "Integration tests completed successfully") `
        "Integration tests completion marker present"

    # ---------------------------------------------------------------------------
    # Summary
    # ---------------------------------------------------------------------------
    $summaryLines = @()
    $summaryLines += ""
    $summaryLines += "=" * 70
    if ($failures.Count -eq 0) {
        $summaryLines += "ALL ASSERTIONS PASSED"
        Write-Host "`nALL ASSERTIONS PASSED" -ForegroundColor Green
    }
    else {
        $summaryLines += "FAILURES ($($failures.Count)):"
        foreach ($f in $failures) {
            $summaryLines += "  - $f"
            Write-Host "  - $f" -ForegroundColor Red
        }
    }
    $summaryLines += "=" * 70

    Add-Content -Path $actResultPath -Value ($summaryLines -join "`n")

    if ($failures.Count -gt 0) {
        Write-Host "`nact-result.txt written to: $actResultPath" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "`nact-result.txt written to: $actResultPath" -ForegroundColor Green
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    # Clean up temp dir
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}
