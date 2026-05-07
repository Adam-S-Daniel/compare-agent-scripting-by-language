# Test harness for semantic version bumper.
# Validates workflow structure, then executes all test cases via a single act push.

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$resultFile = Join-Path $scriptDir 'act-result.txt'

'' | Set-Content $resultFile

function Write-Result {
    param([string]$Text)
    $Text | Add-Content $resultFile
    Write-Host $Text
}

$allPassed = $true

# --- WORKFLOW STRUCTURE TESTS ---
Write-Result "=========================================="
Write-Result "WORKFLOW STRUCTURE TESTS"
Write-Result "=========================================="

$workflowPath = Join-Path $scriptDir '.github/workflows/semantic-version-bumper.yml'

if (Test-Path $workflowPath) { Write-Result "PASS: Workflow file exists" }
else { Write-Result "FAIL: Workflow file not found"; $allPassed = $false }

$yaml = Get-Content $workflowPath -Raw

$structureChecks = @(
    @{ Pattern = 'on:';                  Label = 'Has trigger configuration' },
    @{ Pattern = 'push:';                Label = 'Has push trigger' },
    @{ Pattern = 'pull_request:';        Label = 'Has pull_request trigger' },
    @{ Pattern = 'workflow_dispatch:';   Label = 'Has workflow_dispatch trigger' },
    @{ Pattern = 'jobs:';                Label = 'Has jobs section' },
    @{ Pattern = 'test:';                Label = 'Has test job' },
    @{ Pattern = 'bump-patch:';          Label = 'Has bump-patch job' },
    @{ Pattern = 'bump-minor:';          Label = 'Has bump-minor job' },
    @{ Pattern = 'bump-major:';          Label = 'Has bump-major job' },
    @{ Pattern = 'shell: pwsh';          Label = 'Uses pwsh shell' },
    @{ Pattern = 'actions/checkout@v4';  Label = 'Uses actions/checkout@v4' },
    @{ Pattern = 'needs: test';          Label = 'Bump jobs depend on test job' },
    @{ Pattern = 'Invoke-Pester';        Label = 'Runs Pester tests' }
)

foreach ($check in $structureChecks) {
    if ($yaml -match [regex]::Escape($check.Pattern)) {
        Write-Result "PASS: $($check.Label)"
    } else {
        Write-Result "FAIL: $($check.Label) - pattern '$($check.Pattern)' not found"
        $allPassed = $false
    }
}

# Verify script files exist
foreach ($f in @('Bump-SemanticVersion.ps1', 'Bump-SemanticVersion.Tests.ps1')) {
    if (Test-Path (Join-Path $scriptDir $f)) { Write-Result "PASS: $f exists" }
    else { Write-Result "FAIL: $f not found"; $allPassed = $false }
}

# Verify fixture files exist
foreach ($f in @('patch-commits.txt', 'minor-commits.txt', 'major-commits.txt')) {
    if (Test-Path (Join-Path $scriptDir "fixtures/$f")) { Write-Result "PASS: fixtures/$f exists" }
    else { Write-Result "FAIL: fixtures/$f not found"; $allPassed = $false }
}

# Actionlint validation
$lintOut = actionlint $workflowPath 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) { Write-Result "PASS: actionlint validation passed" }
else { Write-Result "FAIL: actionlint failed: $lintOut"; $allPassed = $false }

Write-Result ""

# --- ACT INTEGRATION TESTS ---
Write-Result "=========================================="
Write-Result "ACT INTEGRATION TESTS"
Write-Result "=========================================="
Write-Result ""

# Commit current state so act picks it up
git add -A 2>$null
git commit -m "test run" --allow-empty 2>$null

# Single act push that runs all jobs (test + 3 bump variants)
Write-Result "Running act push (all jobs)..."
$actOutput = & act push --rm 2>&1 | Out-String
$actExit = $LASTEXITCODE

Write-Result "Act exit code: $actExit"
Write-Result ""
Write-Result "--- ACT OUTPUT START ---"
Write-Result $actOutput
Write-Result "--- ACT OUTPUT END ---"
Write-Result ""

if ($actExit -ne 0) {
    Write-Result "FAIL: act exited with non-zero code $actExit"
    $allPassed = $false
} else {
    Write-Result "PASS: act exited with code 0"
}

# Count job successes
$successes = ([regex]::Matches($actOutput, 'Job succeeded')).Count
Write-Result "Jobs succeeded: $successes"
if ($successes -ge 4) { Write-Result "PASS: All 4 jobs succeeded" }
else { Write-Result "FAIL: Expected 4 job successes, got $successes"; $allPassed = $false }

# --- TEST CASE 1: Patch bump (1.0.0 -> 1.0.1) ---
Write-Result ""
Write-Result "--- Test Case: Patch bump ---"
if ($actOutput -match 'NEW_VERSION=1\.0\.1') { Write-Result "PASS: NEW_VERSION=1.0.1" }
else { Write-Result "FAIL: Expected NEW_VERSION=1.0.1"; $allPassed = $false }

if ($actOutput -match 'OLD_VERSION=1\.0\.0') { Write-Result "PASS: OLD_VERSION=1.0.0" }
else { Write-Result "FAIL: Expected OLD_VERSION=1.0.0"; $allPassed = $false }

if ($actOutput -match 'BUMP_TYPE=patch') { Write-Result "PASS: BUMP_TYPE=patch" }
else { Write-Result "FAIL: Expected BUMP_TYPE=patch"; $allPassed = $false }

# --- TEST CASE 2: Minor bump (1.1.0 -> 1.2.0) ---
Write-Result ""
Write-Result "--- Test Case: Minor bump ---"
if ($actOutput -match 'NEW_VERSION=1\.2\.0') { Write-Result "PASS: NEW_VERSION=1.2.0" }
else { Write-Result "FAIL: Expected NEW_VERSION=1.2.0"; $allPassed = $false }

if ($actOutput -match 'OLD_VERSION=1\.1\.0') { Write-Result "PASS: OLD_VERSION=1.1.0" }
else { Write-Result "FAIL: Expected OLD_VERSION=1.1.0"; $allPassed = $false }

if ($actOutput -match 'BUMP_TYPE=minor') { Write-Result "PASS: BUMP_TYPE=minor" }
else { Write-Result "FAIL: Expected BUMP_TYPE=minor"; $allPassed = $false }

# --- TEST CASE 3: Major bump (2.3.1 -> 3.0.0) ---
Write-Result ""
Write-Result "--- Test Case: Major bump ---"
if ($actOutput -match 'NEW_VERSION=3\.0\.0') { Write-Result "PASS: NEW_VERSION=3.0.0" }
else { Write-Result "FAIL: Expected NEW_VERSION=3.0.0"; $allPassed = $false }

if ($actOutput -match 'OLD_VERSION=2\.3\.1') { Write-Result "PASS: OLD_VERSION=2.3.1" }
else { Write-Result "FAIL: Expected OLD_VERSION=2.3.1"; $allPassed = $false }

if ($actOutput -match 'BUMP_TYPE=major') { Write-Result "PASS: BUMP_TYPE=major" }
else { Write-Result "FAIL: Expected BUMP_TYPE=major"; $allPassed = $false }

# --- CHANGELOG ASSERTIONS ---
Write-Result ""
Write-Result "--- Changelog assertions ---"
if ($actOutput -match '## 1\.0\.1') { Write-Result "PASS: Changelog contains ## 1.0.1" }
else { Write-Result "FAIL: Missing changelog header ## 1.0.1"; $allPassed = $false }

if ($actOutput -match '## 1\.2\.0') { Write-Result "PASS: Changelog contains ## 1.2.0" }
else { Write-Result "FAIL: Missing changelog header ## 1.2.0"; $allPassed = $false }

if ($actOutput -match '## 3\.0\.0') { Write-Result "PASS: Changelog contains ## 3.0.0" }
else { Write-Result "FAIL: Missing changelog header ## 3.0.0"; $allPassed = $false }

if ($actOutput -match 'resolve null reference in parser') { Write-Result "PASS: Patch changelog has commit detail" }
else { Write-Result "FAIL: Missing patch commit detail"; $allPassed = $false }

if ($actOutput -match 'add export functionality') { Write-Result "PASS: Minor changelog has feature detail" }
else { Write-Result "FAIL: Missing minor feature detail"; $allPassed = $false }

if ($actOutput -match 'redesign authentication API') { Write-Result "PASS: Major changelog has breaking change detail" }
else { Write-Result "FAIL: Missing major breaking change detail"; $allPassed = $false }

# --- Pester test count assertion ---
Write-Result ""
Write-Result "--- Pester test assertions ---"
if ($actOutput -match 'Tests Passed: 24') { Write-Result "PASS: All 24 Pester tests passed" }
else { Write-Result "FAIL: Expected 24 Pester tests passed"; $allPassed = $false }

# --- FINAL RESULT ---
Write-Result ""
Write-Result "=========================================="
if ($allPassed) {
    Write-Result "ALL TESTS PASSED"
    Write-Result "=========================================="
    exit 0
} else {
    Write-Result "SOME TESTS FAILED"
    Write-Result "=========================================="
    exit 1
}
