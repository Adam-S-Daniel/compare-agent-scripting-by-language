# Run-Tests.ps1
# Test harness: commits project files, runs the GitHub Actions workflow via
# `act push --rm`, captures all output to act-result.txt, and asserts on
# exact expected values.
#
# Usage:
#   pwsh ./Run-Tests.ps1
#
# Prerequisites: act and Docker must be installed; .actrc must map
# ubuntu-latest to act-ubuntu-pwsh:latest (already present in workspace).

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$actResultFile = Join-Path $PSScriptRoot "act-result.txt"

# Initialise result file
Set-Content -Path $actResultFile -Value "PR Label Assigner - Test Harness Results"
Add-Content -Path $actResultFile -Value "Run date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Content -Path $actResultFile -Value ("=" * 60)
Add-Content -Path $actResultFile -Value ""

$allPassed   = $true
$totalAssert = 0
$passAssert  = 0

function Write-Assert {
    param([bool]$Condition, [string]$Message)
    $script:totalAssert++
    $tag = if ($Condition) { "[PASS]" } else { "[FAIL]" }
    $line = "  $tag $Message"
    Write-Host $line
    Add-Content -Path $script:actResultFile -Value $line
    if ($Condition) {
        $script:passAssert++
    } else {
        $script:allPassed = $false
    }
}

# ---------------------------------------------------------------------------
# Pre-flight 1: actionlint
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Pre-flight: actionlint validation ==="
Add-Content -Path $actResultFile -Value "=== PRE-FLIGHT: actionlint ==="

$workflowFile = Join-Path $PSScriptRoot ".github/workflows/pr-label-assigner.yml"
$alOutput     = & actionlint $workflowFile 2>&1
$alExit       = $LASTEXITCODE

$alOutput | ForEach-Object { Add-Content -Path $actResultFile -Value "  $_" }
Add-Content -Path $actResultFile -Value "actionlint exit code: $alExit"

Write-Assert ($alExit -eq 0) "actionlint exits with code 0"
Add-Content -Path $actResultFile -Value ""

# ---------------------------------------------------------------------------
# Pre-flight 2: git setup - commit all files so act/checkout can find them
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Git setup ==="
Add-Content -Path $actResultFile -Value "=== GIT SETUP ==="

# Set git identity if not configured
$gitName = git config user.name 2>&1
if ([string]::IsNullOrWhiteSpace($gitName) -or $LASTEXITCODE -ne 0) {
    git config user.email "ci@example.com"
    git config user.name  "CI Runner"
}

git add -A 2>&1 | ForEach-Object { Add-Content -Path $actResultFile -Value "  git add: $_" }

# Only commit if there are staged changes
$status = git status --porcelain 2>&1
if ($status) {
    $commitMsg = git commit -m "ci: add pr-label-assigner implementation" 2>&1
    Write-Host "  $commitMsg"
    Add-Content -Path $actResultFile -Value "  $commitMsg"
} else {
    Write-Host "  Nothing to commit - working tree clean"
    Add-Content -Path $actResultFile -Value "  Nothing to commit"
}
Add-Content -Path $actResultFile -Value ""

# ---------------------------------------------------------------------------
# Test case 1: Full workflow via act push
# All Pester tests + all five label-assignment scenarios
# ---------------------------------------------------------------------------

# Expected exact label values
$expectedValues = @{
    "LABELS_RESULT"    = "LABELS_RESULT: api,documentation,source,tests"
    "DOCS_ONLY_RESULT" = "DOCS_ONLY_RESULT: documentation"
    "EMPTY_RESULT"     = "EMPTY_RESULT: 0 labels"
    "TESTS_ONLY_RESULT"= "TESTS_ONLY_RESULT: tests"
    "CICD_RESULT"      = "CICD_RESULT: api,ci/cd,documentation,source,tests"
}

Write-Host ""
Write-Host "=== Test Case 1: Full workflow run via act push ==="
Add-Content -Path $actResultFile -Value "=== TEST CASE 1: Full workflow run via act push ==="
Add-Content -Path $actResultFile -Value "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$actOutput  = & act push --rm --pull=false 2>&1
$actExit    = $LASTEXITCODE

$actOutput | ForEach-Object { Add-Content -Path $actResultFile -Value $_ }
Add-Content -Path $actResultFile -Value ""
Add-Content -Path $actResultFile -Value "act exit code: $actExit"
Add-Content -Path $actResultFile -Value ""

$outputStr = $actOutput -join "`n"

Write-Assert ($actExit -eq 0)                          "act exits with code 0"
Write-Assert ($outputStr -match "Job succeeded")       "output contains 'Job succeeded'"
Write-Assert ($outputStr -match "All Pester tests passed") "output contains 'All Pester tests passed'"

foreach ($kv in $expectedValues.GetEnumerator()) {
    Write-Assert ($outputStr -match [regex]::Escape($kv.Value)) `
        "output contains exact value: $($kv.Value)"
}

Add-Content -Path $actResultFile -Value "=== END TEST CASE 1 ==="
Add-Content -Path $actResultFile -Value ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$failed = $totalAssert - $passAssert
Add-Content -Path $actResultFile -Value "=== SUMMARY ==="
Add-Content -Path $actResultFile -Value "Total assertions : $totalAssert"
Add-Content -Path $actResultFile -Value "Passed           : $passAssert"
Add-Content -Path $actResultFile -Value "Failed           : $failed"
Add-Content -Path $actResultFile -Value "Completed        : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host ""
Write-Host "=== Summary: $passAssert/$totalAssert assertions passed ==="

if ($allPassed) {
    Add-Content -Path $actResultFile -Value "RESULT: ALL TESTS PASSED"
    Write-Host "ALL TESTS PASSED"
    exit 0
} else {
    Add-Content -Path $actResultFile -Value "RESULT: $failed ASSERTION(S) FAILED"
    Write-Warning "$failed assertion(s) failed - see act-result.txt for details"
    exit 1
}
